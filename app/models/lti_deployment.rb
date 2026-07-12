# frozen_string_literal: true

class LtiDeployment < ApplicationRecord
  belongs_to :group, optional: true

  validates :platform_id,
            :deployment_id,
            :client_id,
            :issuer,
            :jwks_url,
            :access_token_url,
            :auth_login_url, presence: true

  validates :deployment_id, uniqueness: { scope: :platform_id }

  before_validation :sync_platform_id_and_issuer
  validate :platform_id_matches_issuer

  private

    def sync_platform_id_and_issuer
      self.platform_id ||= issuer
      self.issuer ||= platform_id
    end

    def platform_id_matches_issuer
      return if platform_id.blank? || issuer.blank?
      return if platform_id == issuer

      errors.add(:issuer, "must match platform_id")
    end
end
