# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssignmentTestCase, type: :model do
  let(:mentor)     { create(:user) }
  let(:group)      { create(:group, primary_mentor: mentor) }
  let(:assignment) { create(:assignment, group: group) }

  describe "validations" do
    it "requires description" do
      tc = build(:assignment_test_case, assignment: assignment, description: "")
      expect(tc).not_to be_valid
    end

    it "requires input_pins" do
      tc = build(:assignment_test_case, assignment: assignment, input_pins: nil)
      expect(tc).not_to be_valid
    end

    it "requires expected_output" do
      tc = build(:assignment_test_case, assignment: assignment, expected_output: nil)
      expect(tc).not_to be_valid
    end
  end

  describe "default scope" do
    it "ordered by position scope works" do
      tc2 = create(:assignment_test_case, assignment: assignment, position: 2)
      tc1 = create(:assignment_test_case, assignment: assignment, position: 1)
      expect(assignment.assignment_test_cases.first).to eq tc1
      expect(assignment.assignment_test_cases.last).to  eq tc2
    end
  end

  describe "#pass?" do
    let(:tc) do
      create(:assignment_test_case,
             assignment:      assignment,
             expected_output: { "Y" => 1 })
    end

    it "returns true when actual matches expected" do
      expect(tc.pass?({ "Y" => 1 })).to be true
    end

    it "returns false when actual differs" do
      expect(tc.pass?({ "Y" => 0 })).to be false
    end
  end
end
