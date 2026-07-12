# frozen_string_literal: true

module Lti
  class JwtValidator
    REQUIRED_JWT_CLAIMS = %w[sub iss aud nonce].freeze

    class << self
      def validate!(token, deployment:, nonce:)
        platform_key = fetch_platform_key(deployment, token)
        payload, _header = decode_token(token, platform_key, deployment)

        verify_nonce!(payload, nonce)
        verify_authorized_party!(payload, deployment)
        verify_required_claims!(payload)
        verify_lti_message!(payload)

        payload
      end

      private

        def decode_token(token, platform_key, deployment)
          JWT.decode(
            token,
            platform_key,
            true,
            algorithms: ["RS256"],
            iss: deployment.issuer,
            aud: deployment.client_id,
            verify_iss: true,
            verify_aud: true
          )
        end

        def verify_nonce!(payload, nonce)
          raise SecurityError, "Missing nonce" if nonce.blank?
          raise SecurityError, "Nonce mismatch" if payload["nonce"] != nonce
        end

        def verify_authorized_party!(payload, deployment)
          aud = payload["aud"]
          return unless aud.is_a?(Array) && aud.size > 1

          raise SecurityError, "Missing azp for multi-audience token" if payload["azp"].blank?
          raise SecurityError, "azp does not match client_id" if payload["azp"] != deployment.client_id
        end

        def verify_required_claims!(payload)
          missing = REQUIRED_JWT_CLAIMS.reject { |claim| payload.key?(claim) }
          raise JWT::DecodeError, "Missing required claims: #{missing.join(', ')}" if missing.any?
        end

        def verify_lti_message!(payload)
          verify_message_type_and_version!(payload)
          verify_launch_claims!(payload)
        end

        def verify_message_type_and_version!(payload)
          raise JWT::DecodeError, "Unsupported LTI message_type" \
            if payload[Claims::MESSAGE_TYPE] != Claims::EXPECTED_MESSAGE_TYPE
          raise JWT::DecodeError, "Unsupported LTI version" \
            if payload[Claims::VERSION] != Claims::EXPECTED_VERSION
        end

        def verify_launch_claims!(payload)
          raise JWT::DecodeError, "Missing deployment_id claim" if payload[Claims::DEPLOYMENT_ID].blank?
          raise JWT::DecodeError, "Missing target_link_uri claim" if payload[Claims::TARGET_LINK].blank?
          raise JWT::DecodeError, "Missing or invalid roles claim" unless payload[Claims::ROLES].is_a?(Array)

          resource_link = payload[Claims::RESOURCE_LINK]
          return if resource_link.is_a?(Hash) && resource_link["id"].present?

          raise JWT::DecodeError, "Missing resource_link id claim"
        end

        def fetch_platform_key(deployment, token)
          _payload, header = JWT.decode(token, nil, false)
          kid = header["kid"]

          key_from_jwks(deployment, kid) ||
            key_from_storage(deployment) ||
            raise(SecurityError, "Could not obtain platform public key")
        end

        def key_from_jwks(deployment, kid)
          response = Faraday.get(deployment.jwks_url)
          return nil unless response.success? && response.headers["content-type"]&.include?("json")

          jwks = JSON.parse(response.body)
          key_data = jwks["keys"].find { |k| k["kid"] == kid }
          key_data && JWT::JWK.import(key_data).public_key
        rescue StandardError
          nil
        end

        def key_from_storage(deployment)
          return nil if deployment.platform_public_key.blank?

          OpenSSL::PKey::RSA.new(deployment.platform_public_key)
        end
    end
  end
end
