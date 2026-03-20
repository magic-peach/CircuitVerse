# frozen_string_literal: true

class Lti::GradePassbackJob < ApplicationJob
  queue_as :default

  def perform(submission_id)
    submission = AssignmentSubmission.includes(:assignment, :project, :user).find_by(id: submission_id)
    return unless submission

    Lti::GradePassbackService.send_score(submission)
  rescue StandardError => e
    Rails.logger.error("LTI grade passback failed for submission #{submission_id}: #{e.message}")
    raise e
  end
end
