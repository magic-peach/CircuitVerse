class MakeAssignmentIdNullableInAssignmentTestCases < ActiveRecord::Migration[8.0]
  def change
    change_column_null :assignment_test_cases, :assignment_id, true
  end
end
