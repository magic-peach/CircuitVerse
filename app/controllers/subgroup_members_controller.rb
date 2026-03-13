# frozen_string_literal: true

class SubgroupMembersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_subgroup

  def create
    @member = @subgroup.subgroup_members.build(
      user_id: params[:user_id],
      role:    params[:role] || :member
    )
    if @member.save
      redirect_back fallback_location: root_path,
                    notice: "Member added to subgroup."
    else
      redirect_back fallback_location: root_path,
                    alert: @member.errors.full_messages.join(", ")
    end
  end

  def destroy
    @member = @subgroup.subgroup_members.find(params[:id])
    @member.destroy
    redirect_back fallback_location: root_path, notice: "Member removed."
  end

  private

    def set_subgroup
      @subgroup = Subgroup.find(params[:subgroup_id])
    end
end
