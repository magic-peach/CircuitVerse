# frozen_string_literal: true

class AssignmentSubmission < ApplicationRecord
  belongs_to :assignment
  belongs_to :project
  belongs_to :user
  belongs_to :subgroup, optional: true

  enum :status, {
    draft:     0,
    submitted: 1,
    graded:    2
  }, prefix: true

  validates :project_id, uniqueness: { scope: :assignment_id }
  validate  :subgroup_required_for_group_submission

  after_commit :notify_on_submission, on: :create
  after_commit :notify_on_grade, on: :update

  def verification_score
    score || 0
  end

  def graded?
    status == "graded"
  end

  private

  def subgroup_required_for_group_submission
    if assignment&.submission_type == "group" && subgroup_id.nil?
      errors.add(:subgroup, "required for group assignments")
    end
  end

  def notify_on_submission
    return unless status_submitted?
    return unless previous_changes.include?("status")

    assignment.notify_mentor_of_submitted(self)
  end

  def notify_on_grade
    return unless graded?
    return unless previous_changes.include?("status") || previous_changes.include?("score")

    assignment.notify_members_of_grade(self)
  end
end
