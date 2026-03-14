# frozen_string_literal: true

class SubgroupMembersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group_and_subgroup
  before_action :require_mentor!

  def create
    @member = @subgroup.subgroup_members.build(
      user_id: params[:user_id],
      role:    params[:role] || :member
    )
    if @member.save
      redirect_back fallback_location: group_subgroup_path(@group, @subgroup),
                    notice: "Member added to subgroup."
    else
      redirect_back fallback_location: group_subgroup_path(@group, @subgroup),
                    alert: @member.errors.full_messages.join(", ")
    end
  end

  def destroy
    @member = @subgroup.subgroup_members.find(params[:id])
    @member.destroy
    redirect_to group_subgroup_path(@group, @subgroup), notice: "Member removed."
  end

  def promote
    @member = @subgroup.subgroup_members.find(params[:id])
    unless @member.role_lead?
      @member.update!(role: :lead)
    end
    redirect_to group_subgroup_path(@group, @subgroup), notice: "#{@member.user.name} is now team lead."
  end

  private

    def set_group_and_subgroup
      @group    = Group.find(params[:group_id])
      @subgroup = @group.subgroups.find(params[:subgroup_id])
    end

    def require_mentor!
      unless current_user.id == @group.primary_mentor_id || current_user.admin?
        redirect_to group_path(@group), alert: "Not authorized."
      end
    end
end
