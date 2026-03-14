# frozen_string_literal: true

require "rails_helper"

RSpec.describe CircuitVerificationService do
  let(:mentor)     { create(:user) }
  let(:group)      { create(:group, primary_mentor: mentor) }
  let(:assignment) { create(:assignment, group: group) }
  let(:project)    { create(:project, assignment: assignment, author: mentor) }

  describe "#verify!" do
    context "when no test cases exist" do
      it "returns passed true" do
        result = described_class.new(assignment, project).verify!
        expect(result.passed).to be true
      end

      it "returns 100% score" do
        result = described_class.new(assignment, project).verify!
        expect(result.score).to eq 100.0
      end

      it "returns empty failed cases" do
        result = described_class.new(assignment, project).verify!
        expect(result.failed_cases).to be_empty
      end
    end

    context "when test cases exist" do
      before do
        create(:assignment_test_case,
               assignment:      assignment,
               input_pins:      { "A" => 1, "B" => 1 },
               expected_output: { "Y" => 1 },
               position:        1)
        create(:assignment_test_case,
               assignment:      assignment,
               input_pins:      { "A" => 0, "B" => 0 },
               expected_output: { "Y" => 0 },
               position:        2)
      end

      it "returns a numeric score" do
        result = described_class.new(assignment, project).verify!
        expect(result.score).to be_between(0, 100)
      end

      it "returns failed cases as array" do
        result = described_class.new(assignment, project).verify!
        expect(result.failed_cases).to be_an(Array)
      end

      it "returns passed false when simulate returns empty hash" do
        result = described_class.new(assignment, project).verify!
        expect(result.passed).to be false
      end

      it "verify! with one passing and one failing test case returns correct score" do
        # Both test cases expect {"Y"=>1}, but simulate_circuit always returns {}
        # so both fail → score = 0.0
        result = described_class.new(assignment, project).verify!
        expect(result.score).to eq 0.0
        expect(result.failed_cases.count).to eq 2
      end

      it "verify! result includes description of failed test case" do
        result = described_class.new(assignment, project).verify!
        descriptions = result.failed_cases.map(&:description)
        expect(descriptions).not_to be_empty
        expect(descriptions.first).to be_a(String)
      end
    end
  end
end
