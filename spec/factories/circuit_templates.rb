# frozen_string_literal: true

FactoryBot.define do
  factory :circuit_template do
    name         { Faker::Lorem.word }
    description  { Faker::Lorem.sentence }
    circuit_data { { components: [], inputs: [], outputs: [] } }
    public       { false }
    association :created_by, factory: :user
  end
end
