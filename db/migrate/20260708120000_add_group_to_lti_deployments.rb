# frozen_string_literal: true

class AddGroupToLtiDeployments < ActiveRecord::Migration[8.1]
  def change
    add_reference :lti_deployments, :group, null: true,
                  foreign_key: { on_delete: :nullify }
  end
end
