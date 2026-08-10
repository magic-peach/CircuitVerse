# frozen_string_literal: true

module Lti
  class DeepLinkingResponse
    MESSAGE_TYPE = "LtiDeepLinkingResponse"
    VERSION_CLAIM = "https://purl.imsglobal.org/spec/lti/claim/version"
    DEPLOYMENT_ID_CLAIM = "https://purl.imsglobal.org/spec/lti/claim/deployment_id"
    CONTENT_ITEMS_CLAIM = "https://purl.imsglobal.org/spec/lti-dl/claim/content_items"
    DATA_CLAIM = "https://purl.imsglobal.org/spec/lti-dl/claim/data"
    TTL = 5.minutes

    def initialize(deployment:, settings:, content_items:)
      @deployment = deployment
      @settings = settings
      @content_items = content_items
    end

    def jwt
      token = JSON::JWT.new(claims)
      token.kid = KeyManager.public_jwk[:kid]
      token.sign(KeyManager.private_key, :RS256).to_s
    end

    private

      def claims
        now = Time.current.to_i
        { iss: @deployment.client_id, aud: @deployment.issuer, iat: now, exp: now + TTL.to_i,
          nonce: SecureRandom.uuid, jti: SecureRandom.uuid,
          DeepLinkingSettings::MESSAGE_TYPE_CLAIM => MESSAGE_TYPE,
          VERSION_CLAIM => "1.3.0",
          DEPLOYMENT_ID_CLAIM => @deployment.deployment_id,
          CONTENT_ITEMS_CLAIM => @content_items,
          DATA_CLAIM => @settings.data }.compact
      end
  end
end
