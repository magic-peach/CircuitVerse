# frozen_string_literal: true

module Lti
  class CanvasOutcomesService
    def initialize(deployment, assignment)
      @deployment = deployment
      @assignment = assignment
    end

    def report_outcomes(submission, verification_result)
      return unless @deployment.present?
      return unless @assignment.canvas_assignment_id.present?

      access_token = obtain_canvas_access_token
      return unless access_token

      outcomes = build_outcome_results(submission, verification_result)
      post_to_canvas(access_token, outcomes)
    end

    private

    def build_outcome_results(submission, result)
      outcome_results = []

      result.failed_cases.each do |tc|
        outcome_results << {
          student_id: submission.user.lti_user_id,
          score: 0,
          possible: 1,
          mastery: false,
          submitted_at: submission.submitted_at
        }
      end

      (result.failed_cases.count...@assignment.assignment_test_cases.count).each do
        outcome_results << {
          student_id: submission.user.lti_user_id,
          score: 1,
          possible: 1,
          mastery: true,
          submitted_at: submission.submitted_at
        }
      end

      { outcome_results: outcome_results }
    end

    def post_to_canvas(access_token, outcomes)
      canvas_url = @assignment.canvas_assignment_id
      response = Faraday.post(canvas_url) do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
        req.headers["Content-Type"] = "application/json"
        req.body = outcomes.to_json
      end

      Rails.logger.info "Canvas Outcomes Response: #{response.status} - #{response.body}"

      raise "Canvas outcomes submission failed" unless response.success?
    end

    def obtain_canvas_access_token
      # In LTI 1.3, Canvas API token can be obtained from deployment claims
      # For now, we'll use the LTI token exchange
      assertion = JWT.encode(
        {
          iss: @deployment.client_id,
          sub: @deployment.client_id,
          aud: @deployment.access_token_url,
          iat: Time.current.to_i,
          exp: 5.minutes.from_now.to_i,
          jti: SecureRandom.uuid
        },
        Lti::KeyManager.private_key,
        "RS256"
      )

      response = Faraday.post(@deployment.access_token_url,
        grant_type:            "client_credentials",
        client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
        client_assertion:      assertion,
        scope:                 "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem"
      )

      JSON.parse(response.body)["access_token"]
    rescue StandardError => e
      Rails.logger.error "Failed to obtain Canvas access token: #{e.message}"
      nil
    end
  end
end
