# frozen_string_literal: true

class AssignmentMailer < ApplicationMailer
  def new_assignment_email(user, assignment)
    return if user.opted_out?

    @assignment = assignment
    @user = user
    @group = @assignment.group
    @primary_mentor = @group&.primary_mentor
    @assignment_url = @group.present? ? group_assignment_url(@group, @assignment) : nil
    mail(to: [@user.email],
         subject: "New Assignment in #{@group&.name || 'Unknown Group'}")
  end

  def update_assignment_email(user, assignment)
    return if user.opted_out?

    @assignment = assignment
    @user = user
    @group = @assignment.group
    @primary_mentor = @group&.primary_mentor
    @assignment_url = @group.present? ? group_assignment_url(@group, @assignment) : nil
    mail(to: [@user.email],
         subject: "Assignment Updated in #{@group&.name || 'Unknown Group'}")
  end
end
