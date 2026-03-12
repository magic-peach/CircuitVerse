# frozen_string_literal: true

class CircuitTemplate < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  has_many   :assignments, dependent: :nullify

  validates :name,         presence: true
  validates :circuit_data, presence: true

  scope :public_templates, -> { where(public: true) }
  scope :by_user, ->(user) { where(created_by: user) }
end
