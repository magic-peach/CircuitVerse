# frozen_string_literal: true

class CircuitTemplate < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  has_many   :assignments, dependent: :nullify
  has_many   :assignment_test_cases, through: :assignments
  has_many   :direct_test_cases, -> { where(testable_type: 'CircuitTemplate') }, 
             class_name: "AssignmentTestCase", foreign_key: "testable_id"

  validates :name,         presence: true
  validates :circuit_data, presence: true

  scope :public_templates, -> { where(public: true) }
  scope :by_user, ->(user) { where(created_by: user) }

  def all_test_cases
    AssignmentTestCase.where("(testable_type = 'CircuitTemplate' AND testable_id = ?) OR (testable_type = 'Assignment' AND assignment_id IN (?))", 
                           id, assignments.pluck(:id))
      .order(:position)
  end
end
