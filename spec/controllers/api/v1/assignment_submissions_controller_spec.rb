# frozen_string_literal: true

require "rails_helper"

describe Api::V1::AssignmentSubmissionsController, type: :request do
  let(:mentor)  { create(:user) }
  let(:student) { create(:user) }
  let(:group)   { create(:group, primary_mentor: mentor) }
  let(:assignment) { create(:assignment, group: group) }
  let(:project)    { create(:project, author: student, assignment: assignment) }
  let!(:submission) do
    AssignmentSubmission.create!(
      assignment: assignment,
      user:       student,
      project:    project,
      status:     :submitted
    )
  end

  describe "GET /api/v1/assignment_submissions" do
    it "returns 200 with list of submissions" do
      token = get_auth_token(mentor)
      get api_v1_assignment_submissions_path,
          headers: { Authorization: "Token #{token}" }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["submissions"]).to be_an(Array)
    end

    it "filters by assignment_id" do
      token = get_auth_token(mentor)
      get api_v1_assignment_submissions_path,
          params: { assignment_id: assignment.id },
          headers: { Authorization: "Token #{token}" }
      body = JSON.parse(response.body)
      expect(body["submissions"].map { |s| s["assignment_id"] }).to all(eq(assignment.id))
    end

    it "filters by status" do
      token = get_auth_token(mentor)
      get api_v1_assignment_submissions_path,
          params: { status: "submitted" },
          headers: { Authorization: "Token #{token}" }
      body = JSON.parse(response.body)
      expect(body["submissions"].map { |s| s["status"] }).to all(eq("submitted"))
    end

    it "requires authentication" do
      get api_v1_assignment_submissions_path
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/assignment_submissions/:id" do
    it "returns submission details" do
      token = get_auth_token(mentor)
      get api_v1_assignment_submission_path(submission),
          headers: { Authorization: "Token #{token}" }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(submission.id)
      expect(body["user"]).to be_present
    end
  end

  describe "PATCH /api/v1/assignment_submissions/:id" do
    it "allows mentor to update status to graded" do
      token = get_auth_token(mentor)
      patch api_v1_assignment_submission_path(submission),
            params: { assignment_submission: { status: "graded", score: 88.5 } },
            headers: { Authorization: "Token #{token}" }
      expect(response).to have_http_status(:ok)
      expect(submission.reload.status).to eq("graded")
      expect(submission.reload.score).to be_within(0.01).of(88.5)
    end

    it "returns 403 for non-mentor" do
      token = get_auth_token(student)
      patch api_v1_assignment_submission_path(submission),
            params: { assignment_submission: { status: "graded" } },
            headers: { Authorization: "Token #{token}" }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
