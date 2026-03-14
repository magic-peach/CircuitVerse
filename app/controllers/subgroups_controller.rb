# frozen_string_literal: true

class SubgroupsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group

  def index
    @subgroups = @group.subgroups.includes(subgroup_members: :user)
  end

  def show
    @subgroup    = @group.subgroups.includes(subgroup_members: :user).find(params[:id])
    @assignments = @group.assignments.includes(:assignment_submissions)
  end

  def create
    @subgroup = @group.subgroups.build(subgroup_params)
    if @subgroup.save
      redirect_to group_path(@group), notice: "Team created successfully."
    else
      redirect_to group_path(@group), alert: @subgroup.errors.full_messages.join(", ")
    end
  end

  def destroy
    @subgroup = @group.subgroups.find(params[:id])
    @subgroup.destroy
    redirect_to group_path(@group), notice: "Team removed."
  end

  private

    def set_group
      @group = Group.find(params[:group_id])
    end

    def subgroup_params
      params.require(:subgroup).permit(:name, :max_size)
    end
end
