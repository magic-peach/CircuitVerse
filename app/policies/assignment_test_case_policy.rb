# frozen_string_literal: true

class AssignmentTestCasePolicy < ApplicationPolicy
  attr_reader :user, :test_case

  def initialize(user, test_case)
    @user = user
    @test_case = test_case
    
    if test_case.assignment.present?
      @assignment = test_case.assignment
      @group = @assignment.group
      @admin_access = (@group.primary_mentor_id == user.id) || user.admin?
      @mentor_access = @admin_access || @group.group_members.exists?(user_id: user.id, mentor: true)
      @member_access = @group.group_members.exists?(user_id: user.id)
    elsif test_case.testable_type == 'CircuitTemplate' && test_case.testable_id.present?
      template = CircuitTemplate.find_by(id: test_case.testable_id)
      @admin_access = (template&.created_by_id == user.id) || user.admin?
      @mentor_access = @admin_access
      @member_access = @admin_access
    else
      @admin_access = user.admin?
      @mentor_access = user.admin?
      @member_access = false
    end
  end

  def show?
    @member_access
  end

  def create?
    @mentor_access
  end

  def update?
    @mentor_access
  end

  def destroy?
    @mentor_access
  end
end
