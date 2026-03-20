# frozen_string_literal: true

class AssignmentGradedNotification < Noticed::Base
  deliver_by :database, association: :noticed_notifications

  def message
    assignment = params[:assignment]
    submission = params[:submission]
    t("users.notifications.assignment_graded_notification", assignment_name: assignment.name, score: submission.score || "N/A")
  end

  def icon
    "fa fa-check-circle"
  end

  def url
    group_assignment_path(assignment.group, assignment)
  end
end
