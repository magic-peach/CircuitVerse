# frozen_string_literal: true

module Lti
  module Claims
    MESSAGE_TYPE  = "https://purl.imsglobal.org/spec/lti/claim/message_type"
    VERSION       = "https://purl.imsglobal.org/spec/lti/claim/version"
    DEPLOYMENT_ID = "https://purl.imsglobal.org/spec/lti/claim/deployment_id"
    TARGET_LINK   = "https://purl.imsglobal.org/spec/lti/claim/target_link_uri"
    RESOURCE_LINK = "https://purl.imsglobal.org/spec/lti/claim/resource_link"
    ROLES         = "https://purl.imsglobal.org/spec/lti/claim/roles"
    CONTEXT       = "https://purl.imsglobal.org/spec/lti/claim/context"
    CUSTOM        = "https://purl.imsglobal.org/spec/lti/claim/custom"
    TOOL_PLATFORM = "https://purl.imsglobal.org/spec/lti/claim/tool_platform"

    EXPECTED_MESSAGE_TYPE = "LtiResourceLinkRequest"
    EXPECTED_VERSION      = "1.3.0"
  end
end
