# frozen_string_literal: true

class Api::V1::AssignmentTestCasesController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_test_case, only: %i[show update destroy]
  before_action :check_access, only: %i[update destroy]

  def index
    scope = AssignmentTestCase.all
    scope = scope.where(assignment_id: params[:assignment_id]) if params[:assignment_id].present?
    @test_cases = scope.order(:position)
    render json: @test_cases.map { |tc| test_case_json(tc) }
  end

  def show
    authorize @test_case
    render json: test_case_json(@test_case)
  end

  def create
    assignment_id = params[:assignment_test_case][:assignment_id]
    testable_type = params[:assignment_test_case][:testable_type]
    testable_id = params[:assignment_test_case][:testable_id]
    
    assignment = Assignment.find(assignment_id) if assignment_id.present?
    
    tc_params = test_case_params.dup
    tc_params[:input_pins] = parse_pin_string(tc_params[:input_pins]) if tc_params[:input_pins].is_a?(String)
    tc_params[:expected_output] = parse_pin_string(tc_params[:expected_output]) if tc_params[:expected_output].is_a?(String)
    
    if assignment_id.present?
      @test_case = assignment&.assignment_test_cases&.build(tc_params)
    elsif testable_type == 'CircuitTemplate' && testable_id.present?
      @test_case = AssignmentTestCase.new(tc_params.merge(
        testable_type: testable_type,
        testable_id: testable_id
      ))
    else
      @test_case = AssignmentTestCase.new(tc_params)
    end
    
    authorize @test_case

    if @test_case.save
      render json: test_case_json(@test_case), status: :created
    else
      render json: { errors: @test_case.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize @test_case
    tc_params = test_case_params.dup
    tc_params[:input_pins] = parse_pin_string(tc_params[:input_pins]) if tc_params[:input_pins].is_a?(String)
    tc_params[:expected_output] = parse_pin_string(tc_params[:expected_output]) if tc_params[:expected_output].is_a?(String)
    
    if @test_case.update(tc_params)
      render json: test_case_json(@test_case), status: :ok
    else
      render json: { errors: @test_case.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @test_case
    @test_case.destroy!
    head :no_content
  end

  private

  def parse_pin_string(str)
    return {} if str.blank?
    
    result = {}
    pairs = str.split(/[,\s]+/)
    pairs.each do |pair|
      parts = pair.split('=').map(&:strip).reject(&:blank?)
      if parts.length == 2
        key, value = parts
        result[key] = value_to_typed(value)
      end
    end
    result
  end

  def value_to_typed(value)
    return true if value.downcase == 'true'
    return false if value.downcase == 'false'
    return value.to_i if value.match?(/^-?\d+$/)
    value
  end

  def set_test_case
    @test_case = AssignmentTestCase.find(params[:id])
  end

  def check_access
    authorize @test_case
  end

  def test_case_params
    params.require(:assignment_test_case).permit(:description, :position, :assignment_id,
                                                :testable_type, :testable_id,
                                                :input_pins, :expected_output)
  end

  def test_case_json(test_case)
    {
      id:             test_case.id,
      assignment_id:  test_case.assignment_id,
      description:    test_case.description,
      input_pins:     test_case.input_pins,
      expected_output: test_case.expected_output,
      position:       test_case.position,
      created_at:     test_case.created_at,
      updated_at:     test_case.updated_at
    }
  end
end
