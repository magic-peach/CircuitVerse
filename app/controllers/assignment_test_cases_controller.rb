# frozen_string_literal: true

class AssignmentTestCasesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_assignment

  def index
    @test_cases = @assignment.assignment_test_cases
  end

  def create
    @test_case = @assignment.assignment_test_cases.build(test_case_params)
    if @test_case.save
      redirect_back fallback_location: root_path,
                    notice: "Test case added."
    else
      redirect_back fallback_location: root_path,
                    alert: @test_case.errors.full_messages.join(", ")
    end
  end

  def destroy
    @test_case = @assignment.assignment_test_cases.find(params[:id])
    @test_case.destroy
    redirect_back fallback_location: root_path, notice: "Test case removed."
  end

  private

    def set_assignment
      @assignment = Assignment.find(params[:assignment_id])
    end

    def test_case_params
      params.require(:assignment_test_case)
            .permit(:description, :position,
                    input_pins: {}, expected_output: {})
    end
end
