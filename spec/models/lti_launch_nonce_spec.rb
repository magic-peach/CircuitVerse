# frozen_string_literal: true

require "rails_helper"

describe LtiLaunchNonce do
  include ActiveSupport::Testing::TimeHelpers

  let(:expires_at) { 5.minutes.from_now }

  describe ".claim" do
    it "accepts a nonce the first time" do
      expect(described_class.claim("nonce-1", expires_at: expires_at)).to be(true)
    end

    it "refuses the same nonce a second time" do
      described_class.claim("nonce-1", expires_at: expires_at)
      expect(described_class.claim("nonce-1", expires_at: expires_at)).to be(false)
    end

    it "purges records past their expiry" do
      described_class.claim("old", expires_at: expires_at)

      travel_to 10.minutes.from_now do
        described_class.claim("new", expires_at: 5.minutes.from_now)
      end

      expect(described_class.pluck(:nonce)).to contain_exactly("new")
    end
  end
end
