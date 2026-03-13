# frozen_string_literal: true

class PracticeSessionImporter
  def initialize(project, assignment)
    @project    = project
    @assignment = assignment
  end

  def import!
    raise ArgumentError, "Assignment is closed"    if @assignment.status == "closed"
    raise ArgumentError, "Already submitted"       if existing_submission.present?

    submission = AssignmentSubmission.create!(
      assignment:   @assignment,
      project:      @project,
      user:         @project.author,
      status:       :draft,
      submitted_at: Time.zone.now
    )

    CircuitVerificationJob.perform_later(submission.id)
    submission
  end

  private

  def existing_submission
    AssignmentSubmission.find_by(
      assignment: @assignment,
      user:       @project.author
    )
  end
end
