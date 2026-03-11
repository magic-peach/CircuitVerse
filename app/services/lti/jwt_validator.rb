# frozen_string_literal: true

module Lti
  class JwtValidator
    REQUIRED_CLAIMS = %w[sub iss aud nonce].freeze

    def self.validate!(token, deployment:, nonce:)
      platform_key = fetch_platform_key(deployment.jwks_url, token)

      payload, _header = JWT.decode(
        token,
        platform_key,
        true,
        algorithms:  ["RS256"],
        iss:         deployment.issuer,
        aud:         deployment.client_id,
        verify_iss:  true,
        verify_aud:  true
      )

      raise SecurityError, "Nonce mismatch" unless payload["nonce"] == nonce
      raise ArgumentError, "Missing required claims" \
        unless REQUIRED_CLAIMS.all? { |c| payload.key?(c) }

      payload
    end

    private

    def self.fetch_platform_key(jwks_url, token)
      _payload, header = JWT.decode(token, nil, false)
      kid = header["kid"]

      response = Faraday.get(jwks_url)
      jwks     = JSON.parse(response.body)

      key_data = jwks["keys"].find { |k| k["kid"] == kid }
      raise SecurityError, "Key not found in JWKS" unless key_data

      JWT::JWK.import(key_data).public_key
    end
  end
end
