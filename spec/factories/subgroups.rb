# frozen_string_literal: true

FactoryBot.define do
  factory :subgroup do
    name     { Faker::Lorem.word }
    max_size { 4 }
    association :group
  end
end
