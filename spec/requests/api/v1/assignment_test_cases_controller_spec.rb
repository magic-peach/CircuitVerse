# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::AssignmentTestCasesController", type: :request do
  let(:mentor) { create(:user) }
  let(:student) { create(:user) }
  let(:group) { create(:group, primary_mentor: mentor) }
  let(:assignment) { create(:assignment, group: group) }
  let(:test_case) { create(:assignment_test_case, assignment: assignment) }

  before do
    group.group_members.create!(user: mentor)
    sign_in mentor
  end

  describe "GET #index" do
    it "returns list of test cases" do
      test_case
      create(:assignment_test_case, assignment: assignment, position: 1)

      get api_v1_assignment_test_cases_path(assignment_id: assignment.id)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.length).to eq(2)
    end

    it "returns test cases ordered by position" do
      tc1 = create(:assignment_test_case, assignment: assignment, position: 2)
      tc2 = create(:assignment_test_case, assignment: assignment, position: 1)

      get api_v1_assignment_test_cases_path(assignment_id: assignment.id)
      json = JSON.parse(response.body)
      expect(json.first["id"]).to eq(tc2.id)
      expect(json.second["id"]).to eq(tc1.id)
    end
  end

  describe "GET #show" do
    it "returns test case details" do
      get api_v1_assignment_test_case_path(id: test_case.id)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(test_case.id)
      expect(json["description"]).to eq(test_case.description)
      expect(json["input_pins"]).to eq(test_case.input_pins)
      expect(json["expected_output"]).to eq(test_case.expected_output)
      expect(json["position"]).to eq(test_case.position)
    end
  end

  describe "POST #create" do
    context "when user is the group mentor" do
      it "creates a new test case" do
        expect {
          post api_v1_assignment_test_cases_path,
               params: {
                 assignment_test_case: {
                   assignment_id: assignment.id,
                   description: "Test case 1",
                   input_pins: { "A" => 0, "B" => 1 },
                   expected_output: { "C" => 1 },
                   position: 1
                 }
               }
        }.to change(AssignmentTestCase, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["description"]).to eq("Test case 1")
      end

      it "returns errors for invalid test case" do
        post api_v1_assignment_test_cases_path,
             params: { assignment_test_case: { description: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when user is a regular group member" do
      before do
        group.group_members.create!(user: student)
        sign_in student
      end

      it "returns forbidden" do
        post api_v1_assignment_test_cases_path,
             params: {
               assignment_test_case: {
                 assignment_id: assignment.id,
                 description: "Test case 1",
                 input_pins: {},
                 expected_output: {}
               }
             }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH #update" do
    context "when user is the group mentor" do
      it "updates the test case" do
        patch api_v1_assignment_test_case_path(id: test_case.id),
              params: { assignment_test_case: { description: "Updated test case" } }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["description"]).to eq("Updated test case")
        test_case.reload
        expect(test_case.description).to eq("Updated test case")
      end

      it "returns errors for invalid update" do
        patch api_v1_assignment_test_case_path(id: test_case.id),
              params: { assignment_test_case: { description: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE #destroy" do
    context "when user is the group mentor" do
      it "deletes the test case" do
        test_case
        expect {
          delete api_v1_assignment_test_case_path(id: test_case.id)
        }.to change(AssignmentTestCase, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
