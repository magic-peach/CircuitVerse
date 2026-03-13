# frozen_string_literal: true

FactoryBot.define do
  factory :assignment_test_case do
    description     { Faker::Lorem.sentence }
    input_pins      { { "A" => 1, "B" => 1 } }
    expected_output { { "Y" => 1 } }
    position        { 1 }
    association :assignment
  end
end
