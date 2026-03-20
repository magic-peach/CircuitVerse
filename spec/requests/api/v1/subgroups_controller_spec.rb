# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::SubgroupsController", type: :request do
  let(:user) { create(:user) }
  let(:mentor) { create(:user) }
  let(:group) { create(:group, primary_mentor: mentor) }
  let(:subgroup) { create(:subgroup, group: group) }
  let(:subgroup_member) { create(:subgroup_member, subgroup: subgroup, user: create(:user)) }

  before do
    group.group_members.create!(user: mentor)
    sign_in user
  end

  describe "GET #index" do
    context "when filtering by group" do
      before { group.group_members.create!(user: user) }

      it "returns list of subgroups" do
        subgroup
        get api_v1_subgroups_path(group_id: group.id)
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
        expect(json.first["id"]).to eq(subgroup.id)
        expect(json.first["name"]).to eq(subgroup.name)
      end
    end
  end

  describe "GET #show" do
    context "when user has access" do
      before { group.group_members.create!(user: user) }

      it "returns subgroup details" do
        get api_v1_subgroup_path(id: subgroup.id)
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["id"]).to eq(subgroup.id)
        expect(json["name"]).to eq(subgroup.name)
        expect(json["max_size"]).to eq(subgroup.max_size)
        expect(json["full?"]).to be false
      end
    end
  end

  describe "POST #create" do
    context "when user is the primary mentor" do
      before { sign_in mentor }

      it "creates a new subgroup" do
        post api_v1_subgroups_path,
             params: { subgroup: { name: "Team A", max_size: 5, group_id: group.id } }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["name"]).to eq("Team A")
        expect(json["max_size"]).to eq(5)
      end

      it "returns errors for invalid subgroup" do
        post api_v1_subgroups_path,
             params: { subgroup: { name: "", group_id: group.id } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when user is not the primary mentor" do
      before { group.group_members.create!(user: user) }

      it "returns forbidden" do
        post api_v1_subgroups_path,
             params: { subgroup: { name: "Team B", group_id: group.id } }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE #destroy" do
    context "when user is the primary mentor" do
      before { sign_in mentor }

      it "deletes the subgroup" do
        subgroup
        expect {
          delete api_v1_subgroup_path(id: subgroup.id)
        }.to change(Subgroup, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when user is not the primary mentor" do
      before { group.group_members.create!(user: user) }

      it "returns forbidden" do
        subgroup
        delete api_v1_subgroup_path(id: subgroup.id)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
