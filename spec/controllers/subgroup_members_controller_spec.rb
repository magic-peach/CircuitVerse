# frozen_string_literal: true

require "rails_helper"

describe SubgroupMembersController, type: :request do
  let(:mentor)  { create(:user) }
  let(:other)   { create(:user) }
  let(:student) { create(:user) }
  let(:group)   { create(:group, primary_mentor: mentor) }
  let!(:other_group)  { create(:group, primary_mentor: mentor) }
  let!(:subgroup)     { create(:subgroup, group: group, name: "Alpha") }
  let!(:other_subgroup) { create(:subgroup, group: other_group, name: "Beta") }

  before do
    # student must be a group member to be added as subgroup member
    GroupMember.create!(group: group, user: student)
  end

  describe "POST create" do
    it "adds a member to the subgroup" do
      sign_in mentor
      expect do
        post group_subgroup_subgroup_members_path(group, subgroup),
             params: { user_id: student.id }
      end.to change(SubgroupMember, :count).by(1)
    end

    it "returns 404 when subgroup_id belongs to a different group" do
      sign_in mentor
      post group_subgroup_subgroup_members_path(group, other_subgroup),
           params: { user_id: student.id }
      expect(response).to have_http_status(:not_found)
    end

    it "redirects non-mentors" do
      sign_in other
      post group_subgroup_subgroup_members_path(group, subgroup),
           params: { user_id: student.id }
      expect(response).to redirect_to(group_path(group))
    end
  end

  describe "DELETE destroy" do
    let!(:membership) { SubgroupMember.create!(subgroup: subgroup, user: student) }

    it "removes the member" do
      sign_in mentor
      expect do
        delete group_subgroup_subgroup_member_path(group, subgroup, membership)
      end.to change(SubgroupMember, :count).by(-1)
    end

    it "returns 404 when subgroup_id belongs to a different group" do
      sign_in mentor
      delete group_subgroup_subgroup_member_path(group, other_subgroup, membership)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH promote" do
    let!(:membership) { SubgroupMember.create!(subgroup: subgroup, user: student, role: :member) }

    it "promotes the member to lead" do
      sign_in mentor
      patch promote_group_subgroup_subgroup_member_path(group, subgroup, membership)
      expect(membership.reload.role).to eq("lead")
    end

    it "is idempotent when already lead" do
      membership.update!(role: :lead)
      sign_in mentor
      patch promote_group_subgroup_subgroup_member_path(group, subgroup, membership)
      expect(membership.reload.role).to eq("lead")
    end

    it "redirects non-mentor" do
      sign_in other
      patch promote_group_subgroup_subgroup_member_path(group, subgroup, membership)
      expect(response).to redirect_to(group_path(group))
    end
  end
end
