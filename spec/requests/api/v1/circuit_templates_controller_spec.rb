# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::CircuitTemplatesController", type: :request do
  let(:user) { create(:user) }
  let(:template) { create(:circuit_template, created_by: user, public: true) }

  before { sign_in user }

  describe "GET #index" do
    it "returns list of public templates" do
      template
      get api_v1_circuit_templates_path
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["templates"]).to be_an(Array)
      expect(json["templates"].first["id"]).to eq(template.id)
    end

    it "supports pagination" do
      create_list(:circuit_template, 25, created_by: user, public: true)
      get api_v1_circuit_templates_path, params: { per_page: 10 }
      json = JSON.parse(response.body)
      expect(json["templates"].length).to eq(10)
      expect(json["meta"]["total_pages"]).to eq(3)
    end

    it "filters by public templates only" do
      public_template = create(:circuit_template, created_by: user, public: true)
      private_template = create(:circuit_template, created_by: user, public: false)

      get api_v1_circuit_templates_path, params: { public: true }
      json = JSON.parse(response.body)
      ids = json["templates"].map { |t| t["id"] }
      expect(ids).to include(public_template.id)
      expect(ids).not_to include(private_template.id)
    end

    it "filters by user's templates" do
      my_template = create(:circuit_template, created_by: user, public: false)
      other_user = create(:user)
      other_template = create(:circuit_template, created_by: other_user, public: false)

      get api_v1_circuit_templates_path, params: { my_templates: true }
      json = JSON.parse(response.body)
      ids = json["templates"].map { |t| t["id"] }
      expect(ids).to include(my_template.id)
      expect(ids).not_to include(other_template.id)
    end

    it "supports search" do
      matching_template = create(:circuit_template, created_by: user, name: "Binary Adder", public: true)
      non_matching_template = create(:circuit_template, created_by: user, name: "Multiplier", public: true)

      get api_v1_circuit_templates_path, params: { search: "adder" }
      json = JSON.parse(response.body)
      ids = json["templates"].map { |t| t["id"] }
      expect(ids).to include(matching_template.id)
      expect(ids).not_to include(non_matching_template.id)
    end
  end

  describe "GET #show" do
    it "returns template details" do
      get api_v1_circuit_template_path(id: template.id)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(template.id)
      expect(json["name"]).to eq(template.name)
      expect(json["description"]).to eq(template.description)
      expect(json["public"]).to be true
      expect(json["created_by"]["id"]).to eq(user.id)
    end

    it "includes circuit data in detailed view" do
      get api_v1_circuit_template_path(id: template.id)
      json = JSON.parse(response.body)
      expect(json["circuit_data"]).to eq(template.circuit_data)
    end
  end

  describe "POST #create" do
    it "creates a new circuit template" do
      expect {
        post api_v1_circuit_templates_path,
             params: {
               circuit_template: {
                 name: "Test Template",
                 description: "A test circuit",
                 circuit_data: { gates: [], wires: [] },
                 public: false
               }
             }
      }.to change(CircuitTemplate, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("Test Template")
      expect(json["created_by"]["id"]).to eq(user.id)
    end

    it "returns errors for invalid template" do
      post api_v1_circuit_templates_path,
           params: { circuit_template: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH #update" do
    it "updates the template" do
      patch api_v1_circuit_template_path(id: template.id),
            params: { circuit_template: { name: "Updated Name" } }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("Updated Name")
      template.reload
      expect(template.name).to eq("Updated Name")
    end

    it "returns errors for invalid update" do
      patch api_v1_circuit_template_path(id: template.id),
            params: { circuit_template: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE #destroy" do
    it "deletes the template" do
      template
      expect {
        delete api_v1_circuit_template_path(id: template.id)
      }.to change(CircuitTemplate, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
