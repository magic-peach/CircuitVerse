# frozen_string_literal: true

require "rails_helper"

describe LtiController, type: :request do
  let(:private_key)    { OpenSSL::PKey::RSA.generate(2048) }
  let(:primary_mentor) { FactoryBot.create(:user) }
  let(:group)          { FactoryBot.create(:group, primary_mentor: primary_mentor) }
  let!(:deployment) do
    FactoryBot.create(:lti_deployment, platform_public_key: private_key.public_key.to_pem, group: group)
  end
  let(:member)         { FactoryBot.create(:user) }
  let!(:assignment)    { FactoryBot.create(:assignment, group: group) }

  before do
    Flipper.enable(:lms_integration)
    Flipper.enable(:lti_advantage)
    FactoryBot.create(:group_member, user: member, group: group)
  end

  after do
    Flipper.disable(:lms_integration)
    Flipper.disable(:lti_advantage)
  end

  def id_token(overrides = {})
    now = Time.current.to_i
    payload = {
      "iss" => deployment.issuer,
      "aud" => deployment.client_id,
      LtiController::DEPLOYMENT_ID_CLAIM => deployment.deployment_id,
      Lti::Claims::MESSAGE_TYPE => "LtiResourceLinkRequest",
      Lti::Claims::VERSION => "1.3.0",
      Lti::Claims::TARGET_LINK => "http://www.example.com/lti/launch",
      Lti::Claims::ROLES => ["http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"],
      Lti::Claims::RESOURCE_LINK => { "id" => "resource-link-1" },
      Lti::Claims::CONTEXT => { "id" => "ctx-1", "title" => "Sample Course" },
      Lti::Claims::TOOL_PLATFORM => { "product_family_code" => "canvas" },
      Lti::Claims::CUSTOM => { "assignment_id" => assignment.id.to_s },
      "sub" => SecureRandom.uuid,
      "nonce" => "test-nonce",
      "iat" => now,
      "exp" => now + 3600,
      "email" => member.email,
      "name" => "Test Student"
    }.merge(overrides)
    JWT.encode(payload, private_key, "RS256")
  end

  def instructor_token(overrides = {})
    id_token({
      Lti::Claims::ROLES => ["http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"],
      "email" => primary_mentor.email
    }.merge(overrides))
  end

  def complete_oidc_login
    post lti_login_path, params: {
      iss: deployment.issuer,
      client_id: deployment.client_id,
      login_hint: "hint_abc",
      target_link_uri: "http://www.example.com/lti/launch"
    }
    redirect = Rack::Utils.parse_query(URI(response.location).query)
    { state: redirect["state"], nonce: redirect["nonce"] }
  end

  def launch(overrides = {})
    login = complete_oidc_login
    token = overrides.delete(:token) || id_token("nonce" => login[:nonce])
    post lti_launch_path, params: { id_token: token, state: login[:state] }.merge(overrides)
  end

  describe "feature flag" do
    it "returns 404 for the config endpoint when lms_integration is disabled" do
      Flipper.disable(:lms_integration)
      get lti_config_path
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "when the lti_advantage feature flag is disabled" do
    before { Flipper.disable(:lti_advantage) }

    it "returns 404 for the tool configuration" do
      get lti_config_path
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for the JWKS endpoint" do
      get lti_jwks_path
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for OIDC login initiation" do
      post lti_login_path, params: {
        iss: deployment.issuer, client_id: deployment.client_id,
        login_hint: "hint_abc", target_link_uri: "http://www.example.com/lti/launch"
      }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a 1.3 launch with a validly signed state" do
      verifier = Rails.application.message_verifier(LtiController::LTI_STATE_PURPOSE)
      state = verifier.generate({ "nonce" => "test-nonce" },
                                purpose: LtiController::LTI_STATE_PURPOSE, expires_in: 5.minutes)
      post lti_launch_path, params: { id_token: id_token("nonce" => "test-nonce"), state: state }
      expect(response).to have_http_status(:not_found)
    end

    it "still allows the LTI 1.1 launch path" do
      post lti_launch_path
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /lti/jwks" do
    before do
      allow(Lti::KeyManager).to receive(:jwk).and_return(
        { kty: "RSA", use: "sig", alg: "RS256", kid: "test-kid" }
      )
    end

    it "returns the tool public JWK set" do
      get lti_jwks_path
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["keys"]).to be_an(Array)
      expect(body["keys"].first["kty"]).to eq("RSA")
    end
  end

  describe "GET /lti/config" do
    it "returns the tool configuration JSON" do
      get lti_config_path
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["title"]).to eq("CircuitVerse")
      expect(body).to have_key("oidc_initiation_url")
      expect(body).to have_key("target_link_uri")
    end
  end

  describe "POST /lti/login (OIDC initiation)" do
    let(:login_params) do
      {
        iss: deployment.issuer,
        client_id: deployment.client_id,
        login_hint: "hint_abc",
        target_link_uri: "http://www.example.com/lti/launch"
      }
    end

    context "with a registered deployment" do
      it "redirects to the platform OIDC authorization endpoint" do
        post lti_login_path, params: login_params
        expect(response).to redirect_to(/#{Regexp.escape(deployment.auth_login_url)}/)
      end

      it "supports GET-based OIDC login initiation" do
        get lti_login_path, params: login_params
        expect(response).to redirect_to(/#{Regexp.escape(deployment.auth_login_url)}/)
      end

      it "requests a form_post id_token without an interactive prompt" do
        post lti_login_path, params: login_params
        redirect_params = Rack::Utils.parse_query(URI(response.location).query)
        expect(redirect_params["response_mode"]).to eq("form_post")
        expect(redirect_params["prompt"]).to eq("none")
      end

      it "returns a signed state and nonce in the redirect" do
        post lti_login_path, params: login_params
        redirect = Rack::Utils.parse_query(URI(response.location).query)
        expect(redirect["state"]).to be_present
        expect(redirect["nonce"]).to be_present
        verifier = Rails.application.message_verifier(LtiController::LTI_STATE_PURPOSE)
        data = verifier.verified(redirect["state"], purpose: LtiController::LTI_STATE_PURPOSE)
        expect(data["nonce"]).to eq(redirect["nonce"])
      end

      it "initiates login without an explicit client_id (single-registration issuer)" do
        post lti_login_path, params: login_params.except(:client_id)
        expect(response).to redirect_to(/#{Regexp.escape(deployment.auth_login_url)}/)
      end
    end

    context "with an unregistered deployment" do
      it "returns 404" do
        post lti_login_path, params: { iss: "https://unknown.example.com", client_id: "bad-id" }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /lti/launch with id_token (LTI 1.3)" do
    before do
      stub_request(:get, deployment.jwks_url).to_return(status: 404, body: "")
    end

    context "when the launching user is the group's primary mentor (Instructor)" do
      it "signs them in and redirects to the group assignment page" do
        login = complete_oidc_login
        post lti_launch_path,
             params: { id_token: instructor_token("nonce" => login[:nonce]),
                       state: login[:state] }
        expect(response).to redirect_to(group_assignment_path(group, assignment))
      end

      it "marks the session as LTI" do
        login = complete_oidc_login
        post lti_launch_path,
             params: { id_token: instructor_token("nonce" => login[:nonce]),
                       state: login[:state] }
        expect(session[:is_lti]).to be true
      end

      it "treats the group's primary mentor as teacher regardless of the role claim" do
        login = complete_oidc_login
        token = id_token(
          Lti::Claims::ROLES => ["http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"],
          "email" => primary_mentor.email,
          "nonce" => login[:nonce]
        )
        post lti_launch_path, params: { id_token: token, state: login[:state] }
        expect(response).to redirect_to(group_assignment_path(group, assignment))
      end
    end

    context "when the launching user is a group member (Learner)" do
      it "renders open_incv with a 200" do
        launch
        expect(response).to have_http_status(:ok)
      end

      it "provisions the student's assignment project keyed on the LTI sub" do
        expect { launch }.to change(Project, :count).by(1)
        project = Project.last
        expect(project.assignment_id).to eq(assignment.id)
        expect(project.lis_result_sourced_id).to be_present
      end

      it "backfills lis_result_sourced_id on a pre-existing student project" do
        existing = FactoryBot.create(:project, author: member, assignment: assignment,
                                               lis_result_sourced_id: nil)
        login = complete_oidc_login
        post lti_launch_path,
             params: { id_token: id_token("sub" => "lms-sub-42", "nonce" => login[:nonce]),
                       state: login[:state] }
        expect(existing.reload.lis_result_sourced_id).to eq("lms-sub-42")
      end
    end

    context "when the launch targets an assignment outside the deployment's group" do
      it "returns 401 and does not resolve the foreign assignment" do
        other_group = FactoryBot.create(:group, primary_mentor: FactoryBot.create(:user))
        other_assignment = FactoryBot.create(:assignment, group: other_group)
        login = complete_oidc_login
        token = id_token(Lti::Claims::CUSTOM => { "assignment_id" => other_assignment.id.to_s },
                         "nonce" => login[:nonce])
        post lti_launch_path, params: { id_token: token, state: login[:state] }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the launching user exists but is not in the group" do
      it "returns 401 and does not sign them in" do
        not_member = FactoryBot.create(:user)
        login = complete_oidc_login
        post lti_launch_path,
             params: { id_token: id_token("email" => not_member.email, "nonce" => login[:nonce]),
                       state: login[:state] }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when no CircuitVerse account matches the email claim" do
      it "returns 400" do
        login = complete_oidc_login
        post lti_launch_path,
             params: { id_token: id_token("email" => "ghost@example.com", "nonce" => login[:nonce]),
                       state: login[:state] }
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when the launch does not reference a CircuitVerse assignment" do
      it "returns 401" do
        login = complete_oidc_login
        post lti_launch_path,
             params: { id_token: id_token(Lti::Claims::CUSTOM => {}, "nonce" => login[:nonce]),
                       state: login[:state] }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "without a prior OIDC login (no session state)" do
      it "rejects a validly signed token with 401" do
        post lti_launch_path, params: { id_token: id_token }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a forged state not signed by the tool" do
      it "returns 401" do
        post lti_launch_path, params: { id_token: id_token, state: "forged-unsigned-state" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a state that has expired" do
      it "returns 401" do
        verifier = Rails.application.message_verifier(LtiController::LTI_STATE_PURPOSE)
        expired_state = verifier.generate(
          { "nonce" => "test-nonce" },
          purpose: LtiController::LTI_STATE_PURPOSE,
          expires_at: 1.minute.ago
        )
        post lti_launch_path, params: { id_token: id_token("nonce" => "test-nonce"), state: expired_state }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when a state is replayed" do
      it "rejects the second launch" do
        allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
        login = complete_oidc_login
        token = id_token("nonce" => login[:nonce])
        post lti_launch_path, params: { id_token: token, state: login[:state] }
        expect(response).to have_http_status(:ok)
        post lti_launch_path, params: { id_token: token, state: login[:state] }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a deployment_id that matches no registered deployment" do
      it "returns 404" do
        login = complete_oidc_login
        token = id_token(LtiController::DEPLOYMENT_ID_CLAIM => "unregistered-deployment",
                         "nonce" => login[:nonce])
        post lti_launch_path, params: { id_token: token, state: login[:state] }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an unknown issuer in the token" do
      it "returns 404" do
        login = complete_oidc_login
        token = JWT.encode(
          { "iss" => "https://unknown.edu", "aud" => "unknown-client", "sub" => "u1",
            LtiController::DEPLOYMENT_ID_CLAIM => "deploy-unknown",
            "iat" => Time.current.to_i, "exp" => 1.hour.from_now.to_i },
          private_key, "RS256"
        )
        post lti_launch_path, params: { id_token: token, state: login[:state] }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a malformed token" do
      it "returns 401" do
        login = complete_oidc_login
        post lti_launch_path, params: { id_token: "not.a.jwt", state: login[:state] }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with an expired token" do
      it "returns 401" do
        login = complete_oidc_login
        expired = id_token("exp" => 1.hour.ago.to_i, "nonce" => login[:nonce])
        post lti_launch_path, params: { id_token: expired, state: login[:state] }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a token missing the LTI message_type claim" do
      it "returns 401 rather than 500" do
        login = complete_oidc_login
        token = id_token(Lti::Claims::MESSAGE_TYPE => nil, "nonce" => login[:nonce])
        post lti_launch_path, params: { id_token: token, state: login[:state] }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a token missing the roles claim" do
      it "returns 401" do
        login = complete_oidc_login
        token = id_token(Lti::Claims::ROLES => nil, "nonce" => login[:nonce])
        post lti_launch_path, params: { id_token: token, state: login[:state] }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /lti/launch without id_token (no LTI 1.1 assignment found)" do
    before { stub_request(:get, deployment.jwks_url).to_return(status: 404, body: "") }

    it "returns 401 when no matching assignment exists" do
      post lti_launch_path
      expect(response).to have_http_status(:unauthorized)
    end

    it "clears stale LTI 1.1 outcome context on the next LTI 1.3 launch" do
      assignment.update!(lti_consumer_key: "consumer-key", lti_shared_secret: "shared-secret",
                         grading_scale: :percent)
      post lti_launch_path,
           params: { oauth_consumer_key: "consumer-key", oauth_signature: "invalid",
                     lis_outcome_service_url: "https://lms.example.test/outcomes" }
      expect(session[:lis_outcome_service_url]).to be_present
      expect(session[:lti_11_assignment_id]).to eq(assignment.id)

      launch

      expect(session[:lis_outcome_service_url]).to be_nil
      expect(session[:oauth_consumer_key]).to be_nil
      expect(session[:lti_11_assignment_id]).to be_nil
    end
  end
end
