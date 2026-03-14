# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssignmentSubmission, type: :model do
  let(:mentor)     { create(:user) }
  let(:student)    { create(:user) }
  let(:group)      { create(:group, primary_mentor: mentor) }
  let(:assignment) { create(:assignment, group: group) }
  let(:project)    { create(:project, author: student) }

  describe "validations" do
    it "requires assignment" do
      sub = build(:assignment_submission, assignment: nil, project: project, user: student)
      expect(sub).not_to be_valid
    end

    it "requires user" do
      sub = build(:assignment_submission, assignment: assignment, project: project, user: nil)
      expect(sub).not_to be_valid
    end
  end

  describe "status" do
    it "status defaults to draft" do
      sub = AssignmentSubmission.new(assignment: assignment, project: project, user: student)
      expect(sub.status).to eq "draft"
    end

    it "can transition to submitted" do
      sub = create(:assignment_submission, assignment: assignment, project: project, user: student)
      sub.update!(status: :submitted)
      expect(sub.status).to eq "submitted"
    end

    it "can transition to graded" do
      sub = create(:assignment_submission, assignment: assignment, project: project, user: student)
      sub.update!(status: :graded)
      expect(sub.status).to eq "graded"
    end
  end

  describe "score" do
    it "score is a decimal" do
      sub = create(:assignment_submission, assignment: assignment, project: project, user: student,
                   score: 87.5)
      expect(sub.reload.score).to eq 87.5
    end
  end
end
