class AddLtiDeploymentToGroups < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :groups, :lti_deployment,
                  null: true,
                  index: { algorithm: :concurrently }
  end
end
