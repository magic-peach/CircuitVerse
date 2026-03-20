# frozen_string_literal: true

class AssignmentSubmittedNotification < Noticed::Base
  deliver_by :database, association: :noticed_notifications

  def message
    assignment = params[:assignment]
    t("users.notifications.assignment_submitted_notification", assignment_name: assignment.name)
  end

  def icon
    "fa fa-paper-plane"
  end

  def url
    group_assignment_path(assignment.group, assignment)
  end
end
