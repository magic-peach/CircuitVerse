# frozen_string_literal: true

class Api::V1::SubgroupsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_subgroup, only: %i[show update destroy]
  before_action :check_access, only: %i[update destroy]

  def index
    group_id = params[:group_id]
    scope = Subgroup.includes(subgroup_members: :user)
    scope = scope.where(group_id: group_id) if group_id.present?
    @subgroups = scope
    render json: @subgroups.map { |sg| subgroup_json(sg, detailed: true) }
  end

  def show
    authorize @subgroup
    render json: subgroup_json(@subgroup, detailed: true)
  end

  def create
    group = Group.find(params[:subgroup][:group_id])
    @subgroup = group.subgroups.build(subgroup_params)
    authorize @subgroup

    if @subgroup.save
      render json: subgroup_json(@subgroup, detailed: true), status: :created
    else
      render json: { errors: @subgroup.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @subgroup
    if @subgroup.update(subgroup_params)
      render json: subgroup_json(@subgroup, detailed: true), status: :ok
    else
      render json: { errors: @subgroup.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @subgroup
    @subgroup.destroy!
    head :no_content
  end

  private

  def set_subgroup
    @subgroup = Subgroup.includes(subgroup_members: :user).find(params[:id])
  end

  def subgroup_params
    params.require(:subgroup).permit(:name, :max_size, :group_id)
  end

  def check_access
    authorize @subgroup
  end

  def subgroup_json(subgroup, detailed: false)
    data = {
      id:        subgroup.id,
      name:      subgroup.name,
      group_id:  subgroup.group_id,
      max_size:  subgroup.max_size,
      full?:     subgroup.full?,
      created_at: subgroup.created_at,
      updated_at: subgroup.updated_at
    }
    if detailed
      data[:members] = subgroup.subgroup_members.map do |sm|
        {
          id:   sm.id,
          user: {
            id:    sm.user.id,
            name:  sm.user.name,
            email: sm.user.email
          },
          role: sm.role,
          created_at: sm.created_at
        }
      end
    end
    data
  end
end
