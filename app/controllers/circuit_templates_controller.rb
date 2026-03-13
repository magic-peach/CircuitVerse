# frozen_string_literal: true

class CircuitTemplatesController < ApplicationController
  before_action :authenticate_user!

  def index
    @templates = CircuitTemplate.public_templates
                                .order(created_at: :desc)
  end

  def show
    @template = CircuitTemplate.find(params[:id])
  end

  def create
    @template = CircuitTemplate.new(template_params)
    @template.created_by = current_user
    if @template.save
      redirect_to circuit_template_path(@template),
                  notice: "Circuit template created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @template = CircuitTemplate.find(params[:id])
    @template.destroy
    redirect_to circuit_templates_path, notice: "Template deleted."
  end

  private

    def template_params
      params.require(:circuit_template).permit(:name, :description, :public)
    end
end
