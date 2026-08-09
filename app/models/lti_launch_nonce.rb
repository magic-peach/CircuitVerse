# frozen_string_literal: true

class LtiLaunchNonce < ApplicationRecord
  validates :nonce, :expires_at, presence: true

  # The unique index is what makes this atomic; a replay loses the insert race.
  def self.claim(nonce, expires_at:)
    where(expires_at: ...Time.current).delete_all
    create!(nonce: nonce, expires_at: expires_at)
    true
  rescue ActiveRecord::RecordNotUnique
    false
  end
end
