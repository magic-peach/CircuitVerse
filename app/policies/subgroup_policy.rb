# frozen_string_literal: true

class SubgroupPolicy < ApplicationPolicy
  attr_reader :user, :subgroup

  def initialize(user, subgroup)
    @user = user
    @subgroup = subgroup
    @group = subgroup.group
    @admin_access = (@group.primary_mentor_id == user.id) || user.admin?
  end

  def show?
    @admin_access || @group.group_members.exists?(user_id: user.id)
  end

  def create?
    @admin_access
  end

  def update?
    @admin_access
  end

  def destroy?
    @admin_access
  end
end
