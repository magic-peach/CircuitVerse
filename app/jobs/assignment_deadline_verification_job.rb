# frozen_string_literal: true

class AssignmentDeadlineVerificationJob < ApplicationJob
  queue_as :verification

  def perform(assignment_id)
    assignment = Assignment.find(assignment_id)
    assignment.assignment_submissions
              .where(status: :draft)
              .find_each do |submission|
      CircuitVerificationJob.perform_later(submission.id)
    end
  end
end
