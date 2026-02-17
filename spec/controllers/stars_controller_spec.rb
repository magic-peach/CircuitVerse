# frozen_string_literal: true

require "rails_helper"

describe StarsController, type: :request do
  before do
    @user = FactoryBot.create(:user)
    @project = FactoryBot.create(:project, author: FactoryBot.create(:user))
    sign_in @user
  end

  describe "#create" do
    it "creates a star" do
      expect do
        post stars_path, params: { star: { project_id: @project.id } }
      end.to change(Star, :count).by(1)
    end

    it "does not allow creating a star for another user" do
      another_user = FactoryBot.create(:user)

      post stars_path, params: { star: { project_id: @project.id, user_id: another_user.id } }

      expect(Star.order(:created_at).last.user_id).to eq(@user.id)
    end
  end

  describe "#destroy" do
    before do
      @star = FactoryBot.create(:star, project: @project, user: @user)
    end

    it "destroys a star" do
      expect do
        delete star_path(@star)
      end.to change(Star, :count).by(-1)
    end

    it "does not destroy another user's star" do
      other_user_star = FactoryBot.create(:star, project: @project, user: FactoryBot.create(:user))

      expect do
        delete star_path(other_user_star)
      end.not_to change(Star, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
