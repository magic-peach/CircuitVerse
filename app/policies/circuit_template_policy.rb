# frozen_string_literal: true

class CircuitTemplatePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    record.public? || record.created_by_id == user.id || user.admin?
  end

  def create?
    user.present?
  end

  def update?
    record.created_by_id == user.id || user.admin?
  end

  def destroy?
    record.created_by_id == user.id || user.admin?
  end
end
