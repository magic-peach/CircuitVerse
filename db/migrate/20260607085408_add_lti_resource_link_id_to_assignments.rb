class AddLtiResourceLinkIdToAssignments < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :assignments, :lti_resource_link_id, :string, null: true
    add_index  :assignments, :lti_resource_link_id, algorithm: :concurrently
  end
end
