# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Groups#sync_roster", type: :request do
  let(:mentor)     { FactoryBot.create(:user) }
  let(:group)      { FactoryBot.create(:group, primary_mentor: mentor) }
  let(:deployment) { FactoryBot.create(:lti_deployment) }
  let!(:link) do
    FactoryBot.create(:lti_resource_link, lti_deployment: deployment, context_id: group.id.to_s)
  end

  def member(id, roles: [Lti::Membership::LEARNER])
    { "user_id" => id, "status" => "Active", "roles" => roles,
      "name" => "Student #{id}", "email" => "#{id}@example.com" }
  end

  def stub_roster(members)
    allow(Lti::AccessToken).to receive(:fetch).and_return("tok-1")
    allow(Lti::Membership).to receive(:fetch).and_return(members)
  end

  before { Flipper.enable(:lti_advantage) }

  after { Flipper.disable(:lti_advantage) }

  it "adds the course roster to the group" do
    stub_roster([member("sub-1"), member("sub-2")])
    sign_in mentor

    expect { post sync_roster_group_path(group) }.to change(GroupMember, :count).by(2)
    expect(flash[:notice]).to include("2 added, 0 removed")
  end

  it "removes members who have left the course" do
    stub_roster([])
    gone = FactoryBot.create(:user, provider: "lti", uid: "#{deployment.id}:sub-1")
    GroupMember.create!(group: group, user: gone, lti_synced: true)
    sign_in mentor

    expect { post sync_roster_group_path(group) }.to change(GroupMember, :count).by(-1)
    expect(flash[:notice]).to include("0 added, 1 removed")
  end

  it "ignores staff on the roster" do
    stub_roster([member("sub-1", roles: [Lti::Membership::INSTRUCTOR])])
    sign_in mentor

    expect { post sync_roster_group_path(group) }.not_to change(GroupMember, :count)
  end

  it "records when the roster was last synced" do
    stub_roster([])
    sign_in mentor
    post sync_roster_group_path(group)

    expect(group.reload.lti_last_synced_at).to be_present
  end

  it "refuses a member of the group who is not its mentor" do
    stub_roster([])
    member_user = FactoryBot.create(:user)
    GroupMember.create!(group: group, user: member_user)
    sign_in member_user

    post sync_roster_group_path(group)
    expect(response).to have_http_status(:forbidden)
  end

  it "refuses anyone unrelated to the group" do
    stub_roster([])
    sign_in FactoryBot.create(:user)

    post sync_roster_group_path(group)
    expect(response).to have_http_status(:forbidden)
  end

  it "refuses when the flag is disabled" do
    Flipper.disable(:lti_advantage)
    stub_roster([])
    sign_in mentor

    post sync_roster_group_path(group)
    expect(response).to have_http_status(:forbidden)
  end

  it "says so when the group is not linked to a course" do
    link.destroy
    sign_in mentor
    post sync_roster_group_path(group)

    expect(flash[:alert]).to match(/not linked/i)
  end

  it "reports a platform failure instead of erroring" do
    allow(Lti::AccessToken).to receive(:fetch).and_return("tok-1")
    allow(Lti::Membership).to receive(:fetch).and_raise(Lti::Membership::Error, "403")
    sign_in mentor

    post sync_roster_group_path(group)
    expect(flash[:alert]).to include("403")
  end
end
