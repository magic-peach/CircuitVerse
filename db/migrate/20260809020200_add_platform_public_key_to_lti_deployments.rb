# frozen_string_literal: true

class AddPlatformPublicKeyToLtiDeployments < ActiveRecord::Migration[8.1]
  def change
    add_column :lti_deployments, :platform_public_key, :text
  end
end
