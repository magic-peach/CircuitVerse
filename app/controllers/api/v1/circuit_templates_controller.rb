# frozen_string_literal: true

class Api::V1::CircuitTemplatesController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_circuit_template, only: %i[show update destroy]
  before_action :check_access, only: %i[update destroy]

  def index
    scope = CircuitTemplate.all

    scope = scope.where(public: true) if params[:public].present?
    scope = scope.where(created_by: current_user) if params[:my_templates].present?

    if params[:search].present?
      search_term = "%#{params[:search]}%"
      scope = scope.where("name ILIKE ? OR description ILIKE ?", search_term, search_term)
    end

    @templates = scope.order(created_at: :desc).page(params[:page]).per(params[:per_page] || 20)
    render json: {
      templates: @templates.map { |ct| circuit_template_json(ct) },
      meta: pagination_meta(@templates)
    }
  end

  def show
    authorize @circuit_template, :show?
    render json: circuit_template_json(@circuit_template, detailed: true)
  end

  def create
    @circuit_template = current_user.circuit_templates.new(circuit_template_params)

    if @circuit_template.save
      render json: circuit_template_json(@circuit_template, detailed: true), status: :created
    else
      render json: { errors: @circuit_template.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @circuit_template

    if @circuit_template.update(circuit_template_params)
      render json: circuit_template_json(@circuit_template, detailed: true), status: :ok
    else
      render json: { errors: @circuit_template.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @circuit_template
    @circuit_template.destroy!
    head :no_content
  end

  private

  def set_circuit_template
    @circuit_template = CircuitTemplate.find(params[:id])
  end

  def check_access
    authorize @circuit_template
  end

  def circuit_template_params
    params.require(:circuit_template).permit(:name, :description, :circuit_data, :public)
  end

  def circuit_template_json(template, detailed: false)
    data = {
      id:           template.id,
      name:         template.name,
      description:  template.description,
      created_by: {
        id:   template.created_by.id,
        name: template.created_by.name
      },
      public:       template.public,
      created_at:   template.created_at,
      updated_at:   template.updated_at
    }
    data[:circuit_data] = template.circuit_data if detailed
    data
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages:  collection.total_pages,
      total_count: collection.total_count,
      per_page:    collection.limit_value
    }
  end
end
