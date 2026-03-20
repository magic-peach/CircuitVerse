class AddTestableToAssignmentTestCases < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :assignment_test_cases, :testable_type, :string
    add_column :assignment_test_cases, :testable_id, :bigint
    add_index :assignment_test_cases, [:testable_type, :testable_id], algorithm: :concurrently
  end
end
