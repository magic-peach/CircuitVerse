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

    context "when storing the grading context in the session" do
      let(:outcome_url) { "https://lms.example.test/outcomes" }

      it "records the outcome context and the matched assignment after a verified launch" do
        lti_request(oauth_consumer_key_fromlms, oauth_shared_secret_fromlms, member.email,
                    "lis_outcome_service_url" => outcome_url)
        expect(session[:lis_outcome_service_url]).to eq(outcome_url)
        expect(session[:lti_11_assignment_id]).to eq(assignment.id)
      end

      it "does not store an outcome context when the launch signature is invalid" do
        post lti_launch_path, params: { oauth_consumer_key: oauth_consumer_key_fromlms,
                                        oauth_signature: "invalid",
                                        lis_outcome_service_url: outcome_url }
        expect(response.code).to eq("401")
        expect(session[:lis_outcome_service_url]).to be_nil
        expect(session[:lti_11_assignment_id]).to be_nil
      end

      it "does not store an outcome context when no assignment matches the consumer key" do
        post lti_launch_path, params: { oauth_consumer_key: "unknown-key",
                                        oauth_signature: "invalid",
                                        lis_outcome_service_url: outcome_url }
        expect(session[:lis_outcome_service_url]).to be_nil
        expect(session[:lti_11_assignment_id]).to be_nil
      end

      it "clears a stale outcome context on the next launch" do
        lti_request(oauth_consumer_key_fromlms, oauth_shared_secret_fromlms, member.email,
                    "lis_outcome_service_url" => outcome_url)
        expect(session[:lti_11_assignment_id]).to eq(assignment.id)

        post lti_launch_path, params: { oauth_consumer_key: "unknown-key",
                                        oauth_signature: "invalid" }
        expect(session[:lis_outcome_service_url]).to be_nil
        expect(session[:lti_11_assignment_id]).to be_nil
      end
    end

    def launch_uri
      # required for generation of LTI parameters
      launch_url = "http://#{host}:#{port}/lti/launch"
      URI(launch_url)
    end

    def parameters(member_email, extra_params = {})
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
      }.merge(extra_params)
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

    def lti_request(consumer_key, shared_secret, email, extra_params = {})
      data = consumer_data(consumer_key, shared_secret, parameters(email, extra_params))
      post lti_launch_path, params: data, headers: {
        "Content-Type": "application/x-www-form-urlencoded"
      }
    end

    private

      attr_reader :oauth_consumer_key_fromlms, :oauth_shared_secret_fromlms,
                  :lti_launch_path, :host, :port, :member, :not_member, :primary_mentor,
                  :group, :assignment, :group
  end

  describe "LTI 1.3 OIDC login initiation" do
    include ActiveSupport::Testing::TimeHelpers

    let(:deployment) { FactoryBot.create(:lti_deployment) }
    let(:login_params) do
      {
        iss: deployment.issuer,
        client_id: deployment.client_id,
        login_hint: "lms-user-42",
        lti_message_hint: "message-hint-abc",
        target_link_uri: "http://www.example.com/lti/launch"
      }
    end

    context "when the lti_advantage flag is disabled" do
      it "returns not found" do
        get "/lti/login", params: login_params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the lti_advantage flag is enabled" do
      before { Flipper.enable(:lti_advantage) }

      after { Flipper.disable(:lti_advantage) }

      it "redirects to the platform's authorization endpoint with the OIDC parameters" do
        get "/lti/login", params: login_params

        expect(response).to have_http_status(:found)
        redirect = URI(response.location)
        expect(redirect.to_s).to start_with(deployment.auth_login_url)
        expect(redirect_params(redirect)).to include(
          "scope" => "openid",
          "response_type" => "id_token",
          "response_mode" => "form_post",
          "prompt" => "none",
          "client_id" => deployment.client_id,
          "redirect_uri" => "#{request.base_url}/lti/launch",
          "login_hint" => "lms-user-42",
          "lti_message_hint" => "message-hint-abc"
        )
      end

      it "signs a state carrying the nonce and the resolved deployment" do
        get "/lti/login", params: login_params

        query = redirect_params(URI(response.location))
        expect(verified_state(query["state"]))
          .to eq("nonce" => query["nonce"], "deployment_id" => deployment.id)
      end

      it "issues a fresh nonce and state for every initiation" do
        get "/lti/login", params: login_params
        first = redirect_params(URI(response.location))
        get "/lti/login", params: login_params
        second = redirect_params(URI(response.location))

        expect(second["nonce"]).not_to eq(first["nonce"])
        expect(second["state"]).not_to eq(first["state"])
      end

      it "expires the state after five minutes" do
        get "/lti/login", params: login_params
        state = redirect_params(URI(response.location))["state"]

        travel_to 6.minutes.from_now do
          expect(verified_state(state)).to be_nil
        end
      end

      it "accepts the cross-site POST the platform sends without a CSRF token" do
        with_forgery_protection { post "/lti/login", params: login_params }
        expect(response).to have_http_status(:found)
      end

      it "resolves the deployment without a client_id when the platform omits it" do
        get "/lti/login", params: login_params.except(:client_id)

        expect(response).to have_http_status(:found)
        expect(verified_state(redirect_params(URI(response.location))["state"]))
          .to include("deployment_id" => deployment.id)
      end

      it "picks the registration matching the client_id when a platform has several" do
        other = FactoryBot.create(:lti_deployment, issuer: deployment.issuer)

        get "/lti/login", params: login_params.merge(client_id: other.client_id)

        expect(verified_state(redirect_params(URI(response.location))["state"]))
          .to include("deployment_id" => other.id)
      end

      it "refuses an ambiguous match rather than guessing a registration" do
        FactoryBot.create(:lti_deployment, issuer: deployment.issuer)

        get "/lti/login", params: login_params.except(:client_id)

        expect(response).to have_http_status(:not_found)
      end

      it "refuses when only lti_deployment_id could disambiguate and it is absent" do
        FactoryBot.create(:lti_deployment,
                          issuer: deployment.issuer, client_id: deployment.client_id)

        get "/lti/login", params: login_params

        expect(response).to have_http_status(:not_found)
      end

      it "keeps query parameters already registered on the authorization endpoint" do
        deployment.update!(auth_login_url: "https://lms.example.com/auth?tenant=acme")

        get "/lti/login", params: login_params

        expect(redirect_params(URI(response.location)))
          .to include("tenant" => "acme", "scope" => "openid")
      end

      it "omits lti_message_hint when the platform does not send one" do
        get "/lti/login", params: login_params.except(:lti_message_hint)

        expect(redirect_params(URI(response.location))).not_to have_key("lti_message_hint")
      end

      it "refuses a registration whose authorization endpoint is not http(s)" do
        deployment.update!(auth_login_url: "javascript:alert(1)")

        get "/lti/login", params: login_params

        expect(response).to have_http_status(:not_found)
      end

      it "narrows to the registration matching lti_deployment_id" do
        other = FactoryBot.create(:lti_deployment,
                                  issuer: deployment.issuer, client_id: deployment.client_id)

        get "/lti/login", params: login_params.merge(lti_deployment_id: other.deployment_id)

        expect(verified_state(redirect_params(URI(response.location))["state"]))
          .to include("deployment_id" => other.id)
      end

      it "returns not found for an unregistered issuer" do
        get "/lti/login", params: login_params.merge(iss: "https://attacker.example.com")
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found when the client_id does not belong to the issuer" do
        get "/lti/login", params: login_params.merge(client_id: "not-our-client")
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found when iss is missing" do
        get "/lti/login", params: login_params.except(:iss)
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found when login_hint is missing" do
        get "/lti/login", params: login_params.except(:login_hint)
        expect(response).to have_http_status(:not_found)
      end
    end

    def redirect_params(uri)
      URI.decode_www_form(uri.query).to_h
    end

    def verified_state(state)
      Rails.application
           .message_verifier(LtiController::LTI_STATE_PURPOSE)
           .verified(state.to_s, purpose: LtiController::LTI_STATE_PURPOSE)
    end

    # The test environment disables forgery protection; turn it on so the
    # token-less POST is actually exercised.
    def with_forgery_protection
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
  end

  describe "LTI 1.3 launch" do
    include ActiveSupport::Testing::TimeHelpers

    let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
    let(:jwk) { JWT::JWK.new(rsa_key) }
    let(:deployment) { FactoryBot.create(:lti_deployment) }
    let(:nonce) { "nonce-1" }

    before do
      Flipper.enable(:lti_advantage)
      response_double = instance_double(Faraday::Response, success?: true,
                                                           headers: { "content-type" => "application/json" },
                                                           body: { keys: [jwk.export] }.to_json)
      allow(Faraday).to receive(:get).and_return(response_double)
    end

    after { Flipper.disable(:lti_advantage) }

    def claims(overrides = {})
      {
        "sub" => "lms-user-1", "iss" => deployment.issuer, "aud" => deployment.client_id,
        "nonce" => nonce, "email" => "student@example.com", "name" => "A Student",
        "exp" => 5.minutes.from_now.to_i,
        LtiController::DEPLOYMENT_ID_CLAIM => deployment.deployment_id
      }.merge(overrides)
    end

    def id_token(payload = claims, key: rsa_key, alg: "RS256")
      JWT.encode(payload, key, alg, { kid: jwk.kid })
    end

    def signed_state(data = { "nonce" => nonce, "deployment_id" => deployment.id })
      Rails.application.message_verifier(LtiController::LTI_STATE_PURPOSE)
           .generate(data, purpose: LtiController::LTI_STATE_PURPOSE,
                           expires_in: LtiController::LTI_STATE_TTL)
    end

    def post_launch(token: id_token, state: signed_state)
      post "/lti/launch", params: { id_token: token, state: state }
    end

    context "with a valid launch" do
      it "signs in the user and lands them in CircuitVerse" do
        post_launch
        expect(response).to redirect_to(root_path)
      end

      it "keys the account on the deployment-scoped sub, not the email" do
        post_launch
        expect(User.last).to have_attributes(provider: "lti", uid: "#{deployment.id}:lms-user-1")
      end

      it "reuses the account on a second launch" do
        post_launch
        expect { post_launch(state: signed_state("nonce" => "nonce-2", "deployment_id" => deployment.id)) }
          .not_to change(User, :count)
      end

      it "does not match an existing account by email claim alone" do
        existing = FactoryBot.create(:user, email: "student@example.com")
        post_launch
        expect(response).to have_http_status(:conflict)
        expect(existing.reload.provider).to be_nil
      end
    end

    context "with a bad state" do
      it "rejects a missing state" do
        post_launch(state: nil)
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects a tampered state" do
        post_launch(state: "#{signed_state}x")
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects a state signed for another purpose" do
        forged = Rails.application.message_verifier("other.purpose")
                      .generate({ "nonce" => nonce, "deployment_id" => deployment.id },
                                purpose: "other.purpose")
        post_launch(state: forged)
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects an expired state" do
        state = signed_state
        travel_to 6.minutes.from_now do
          post_launch(token: id_token(claims("exp" => 5.minutes.from_now.to_i)), state: state)
        end
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a bad token" do
      it "rejects a token signed by another key" do
        post_launch(token: id_token(claims, key: OpenSSL::PKey::RSA.generate(2048)))
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects an unsigned token" do
        post_launch(token: JWT.encode(claims, nil, "none"))
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects a mismatched nonce" do
        post_launch(token: id_token(claims("nonce" => "someone-elses")))
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects a token issued for another deployment of the same platform" do
        post_launch(token: id_token(claims(LtiController::DEPLOYMENT_ID_CLAIM => "other-deployment")))
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects a token whose state names a different deployment" do
        other = FactoryBot.create(:lti_deployment)
        post_launch(state: signed_state("nonce" => nonce, "deployment_id" => other.id))
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a replayed launch" do
      it "refuses the second use of a nonce" do
        post_launch
        post_launch
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the platform releases no email" do
      it "refuses rather than provisioning an account without one" do
        expect { post_launch(token: id_token(claims.except("email"))) }
          .not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when the flag is disabled" do
      it "returns not found" do
        Flipper.disable(:lti_advantage)
        post_launch
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
