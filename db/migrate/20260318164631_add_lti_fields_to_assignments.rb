class AddLtiFieldsToAssignments < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :users, :lti_user_id, :string
    add_index :users, :lti_user_id, algorithm: :concurrently

    add_column :assignments, :lis_outcome_service_url, :string
  end
end
