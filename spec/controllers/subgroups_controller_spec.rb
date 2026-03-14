# frozen_string_literal: true

require "rails_helper"

describe SubgroupsController, type: :request do
  let(:mentor)   { create(:user) }
  let(:group)    { create(:group, primary_mentor: mentor) }
  let!(:subgroup) { create(:subgroup, group: group, name: "Alpha Team") }

  describe "GET show" do
    it "responds with 200" do
      sign_in mentor
      get group_subgroup_path(group, subgroup)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST create" do
    it "adds subgroup to group" do
      sign_in mentor
      expect do
        post group_subgroups_path(group), params: {
          subgroup: { name: "Beta Team", max_size: 4 }
        }
      end.to change(Subgroup, :count).by(1)
      expect(response).to redirect_to(group_path(group))
    end
  end

  describe "DELETE destroy" do
    it "removes subgroup" do
      sign_in mentor
      expect do
        delete group_subgroup_path(group, subgroup)
      end.to change(Subgroup, :count).by(-1)
      expect(response).to redirect_to(group_path(group))
    end
  end
end
