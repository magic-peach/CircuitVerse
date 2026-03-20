# frozen_string_literal: true

class CircuitTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_template, only: %i[show edit update destroy]
  before_action :authorize_owner!, only: %i[edit update destroy]

  def index
    @templates = case params[:scope]
                 when "mine"
                   CircuitTemplate.by_user(current_user).includes(:created_by, :assignments => :assignment_test_cases).order(created_at: :desc)
                 when "public"
                   CircuitTemplate.public_templates.includes(:created_by, :assignments => :assignment_test_cases).order(created_at: :desc)
                 else
                   CircuitTemplate.includes(:created_by, :assignments => :assignment_test_cases).order(created_at: :desc)
                 end
  end

  def show
    @template = CircuitTemplate.includes(:created_by).find(params[:id])
    @assignments_using = Assignment.where(circuit_template_id: @template.id).includes(:group)
    @test_case = AssignmentTestCase.new
  end

  def new
    @template = CircuitTemplate.new
  end

  def create
    @template = CircuitTemplate.new(template_params)
    @template.created_by = current_user

    respond_to do |format|
      if @template.save
        if params[:circuit_template][:test_cases].present?
          create_test_cases(@template, params[:circuit_template][:test_cases])
        end
        format.html { redirect_to circuit_template_path(@template), notice: "Circuit template created." }
        format.json { render :show, status: :created, location: @template }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @template.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    respond_to do |format|
      if @template.update(template_params)
        format.html { redirect_to circuit_template_path(@template), notice: "Circuit template updated." }
        format.json { render :show, status: :ok, location: @template }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @template.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @template.destroy

    respond_to do |format|
      format.html { redirect_to circuit_templates_path, notice: "Template deleted." }
      format.json { head :no_content }
    end
  end

  private

  def create_test_cases(template, test_cases_json)
    return if test_cases_json.blank?

    begin
      test_cases_data = JSON.parse(test_cases_json)

      if test_cases_data.is_a?(Array)
        test_cases_data.each do |tc_data|
          template.assignment_test_cases.create!(
            description: tc_data["description"],
            input_pins: tc_data["input_pins"] || {},
            expected_output: tc_data["expected_output"] || {},
            position: tc_data["position"] || 1,
            testable: template
          )
        end
      end
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse test cases JSON: #{e.message}")
    end
  end

  private

    def set_template
      @template = CircuitTemplate.find(params[:id])
    end

    def authorize_owner!
      unless @template.created_by_id == current_user.id || current_user.admin?
        redirect_to circuit_templates_path, alert: "You are not authorized to perform this action."
      end
    end

    def template_params
      params.require(:circuit_template).permit(:name, :description, :public, :circuit_data)
    end
end
