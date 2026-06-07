# frozen_string_literal: true

require "rails_helper"

describe LtiController, type: :request do
  before do
    Flipper.enable(:lms_integration)
    @oauth_consumer_key_fromlms = "some_keys"
    @oauth_shared_secret_fromlms = "some_secrets"
    @lti_launch_path = "/lti/launch"
    get "/"
    @host = request.host
    @port = request.port
  end

  after do
    Flipper.disable(:lms_integration)
  end

  describe "CircuitVerse as LTI Provider" do
    before do
      # creation of assignment and required users
      @primary_mentor = FactoryBot.create(:user)
      @group = FactoryBot.create(:group, primary_mentor: primary_mentor)
      @member = FactoryBot.create(:user)
      @not_member = FactoryBot.create(:user)
      FactoryBot.create(:group_member, user: member, group: group)
      @assignment = FactoryBot.create(:assignment,
                                      group: group,
                                      grading_scale: 2,
                                      lti_consumer_key: oauth_consumer_key_fromlms,
                                      lti_shared_secret: oauth_shared_secret_fromlms)
    end

    context "when lti parameters are valid" do
      it "returns unauthorized (401) if student is not in the group" do
        lti_request(oauth_consumer_key_fromlms, oauth_shared_secret_fromlms, not_member.email)
        expect(response.code).to eq("401")
      end

      it "returns success (200) if student is in the group" do
        lti_request(oauth_consumer_key_fromlms, oauth_shared_secret_fromlms, member.email)
        expect(response.code).to eq("200")
      end

      it "redirect (302) to assignment page if user is primary mentor" do
        lti_request(oauth_consumer_key_fromlms, oauth_shared_secret_fromlms, primary_mentor.email)
        expect(response.code).to eq("302")
      end
    end

    context "when lti parameters are invalid" do
      it "returns unauthorized (401) if no parameters present" do
        # post to launch url without any parameters
        post lti_launch_path
        expect(response.code).to eq("401")
      end

      it "returns unauthorized (401) if parameters contains invalid assignment credentials" do
        lti_request("some_random", "some_random_secret", member.email)
        expect(response.code).to eq("401")
      end
    end

    def launch_uri
      # required for generation of LTI parameters
      launch_url = "http://#{host}:#{port}/lti/launch"
      URI(launch_url)
    end

    def parameters(member_email)
      {
        "launch_url" => launch_uri.to_s,
        "user_id" => SecureRandom.hex(4),
        "launch_presentation_return_url" => launch_uri.to_s,
        "lti_version" => "LTI-1p0",
        "lti_message_type" => "basic-lti-launch-request",
        "resource_link_id" => "88391-e1919-bb3456",
        "lis_person_contact_email_primary" => member_email,
        "tool_consumer_info_product_family_code" => "moodle",
        "context_title" => "sample Course",
        "lis_result_sourcedid" => SecureRandom.hex(10)
      }
    end

    def consumer_data(oauth_consumer_key_fromlms, oauth_shared_secret_fromlms, parameters)
      consumer = IMS::LTI::ToolConsumer.new(
        oauth_consumer_key_fromlms,
        oauth_shared_secret_fromlms,
        parameters
      )
      allow(consumer).to receive(:to_params).and_return(parameters)
      consumer.generate_launch_data
    end

    def lti_request(consumer_key, shared_secret, email)
      data = consumer_data(consumer_key, shared_secret, parameters(email))
      post lti_launch_path, params: data, headers: {
        "Content-Type": "application/x-www-form-urlencoded"
      }
    end

    private

      attr_reader :oauth_consumer_key_fromlms, :oauth_shared_secret_fromlms,
                  :lti_launch_path, :host, :port, :member, :not_member, :primary_mentor,
                  :group, :assignment, :group
  end

  describe "LTI 1.3 Resource Link Launch" do
    let(:rsa_key)    { OpenSSL::PKey::RSA.generate(2048) }
    let(:deployment) { create(:lti_deployment) }
    let(:mentor)     { create(:user) }
    let(:student)    { create(:user) }
    let(:group)      { create(:group, primary_mentor: mentor, lti_deployment: deployment) }

    before do
      allow(Lti::KeyManager).to receive(:private_key).and_return(rsa_key)
      allow(Lti::KeyManager).to receive(:public_key).and_return(rsa_key.public_key)
      allow(Lti::KeyManager).to receive(:jwk).and_return(
        JWT::JWK.new(rsa_key.public_key).export.merge(use: "sig", alg: "RS256", kid: "test-kid")
      )

      stub_request(:get, deployment.jwks_url).to_return(
        status:  200,
        headers: { "Content-Type" => "application/json" },
        body:    { keys: [JWT::JWK.new(rsa_key.public_key).export.merge(kid: "test-kid")] }.to_json
      )

      group
    end

    def build_id_token(overrides = {})
      payload = {
        "iss"   => deployment.issuer,
        "aud"   => deployment.client_id,
        "sub"   => "lti-sub-#{student.id}",
        "iat"   => Time.current.to_i,
        "exp"   => 5.minutes.from_now.to_i,
        "nonce" => "test-nonce",
        "email" => student.email,
        "name"  => student.name,
        "https://purl.imsglobal.org/spec/lti/claim/message_type"  => "LtiResourceLinkRequest",
        "https://purl.imsglobal.org/spec/lti/claim/version"       => "1.3.0",
        "https://purl.imsglobal.org/spec/lti/claim/deployment_id" => deployment.deployment_id,
        "https://purl.imsglobal.org/spec/lti/claim/resource_link" => {
          "id" => "resource-link-1", "title" => "Test Assignment"
        },
        "https://purl.imsglobal.org/spec/lti/claim/roles" => []
      }.merge(overrides)
      JWT.encode(payload, rsa_key, "RS256", kid: "test-kid")
    end

    def lti13_launch(token, state: nil)
      session = { lti_nonce: "test-nonce", lti_state: state }
      post lti_launch_path,
           params:  { id_token: token, state: state },
           headers: { "Content-Type" => "application/x-www-form-urlencoded" },
           env:     { "rack.session" => session }
    end

    context "when state mismatch" do
      it "returns 401" do
        # OIDC login sets session[:lti_state]
        post lti_login_path,
             params: { iss: deployment.issuer, client_id: deployment.client_id,
                       login_hint: "hint", lti_message_hint: "" }

        token = build_id_token
        post lti_launch_path, params: { id_token: token, state: "definitely-wrong" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when no group is linked to the deployment" do
      it "returns 422" do
        group.update!(lti_deployment: nil)
        token = build_id_token
        post lti_launch_path, params: { id_token: token }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "student launch" do
      it "creates a project and renders open_incv (200)" do
        token = build_id_token
        post lti_launch_path, params: { id_token: token }
        expect(response).to have_http_status(:ok)
        expect(Project.where(author: student).count).to eq(1)
      end

      it "reuses existing project on re-launch — no duplicate created" do
        token = build_id_token
        post lti_launch_path, params: { id_token: token }
        post lti_launch_path, params: { id_token: token }
        expect(Project.where(author: student).count).to eq(1)
      end
    end

    context "instructor launch" do
      it "redirects to assignment page (302)" do
        token = build_id_token(
          "email" => mentor.email,
          "name"  => mentor.name,
          "sub"   => "instructor-sub",
          "https://purl.imsglobal.org/spec/lti/claim/roles" => [
            "http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"
          ]
        )
        post lti_launch_path, params: { id_token: token }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/groups/")
      end
    end

    context "when deployment is unknown" do
      it "returns 404" do
        bad_token = JWT.encode(
          { "iss" => "unknown", "aud" => "unknown", "sub" => "x",
            "iat" => Time.current.to_i, "exp" => 5.minutes.from_now.to_i },
          rsa_key, "RS256", kid: "test-kid"
        )
        post lti_launch_path, params: { id_token: bad_token }
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
