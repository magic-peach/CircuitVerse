# frozen_string_literal: true

require "rails_helper"

describe CircuitTemplatesController, type: :request do
  let(:owner)  { create(:user) }
  let(:other)  { create(:user) }
  let!(:public_template)  { create(:circuit_template, created_by: owner, public: true) }
  let!(:private_template) { create(:circuit_template, created_by: owner, public: false) }

  describe "GET index" do
    it "responds with 200" do
      sign_in owner
      get circuit_templates_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET show" do
    it "responds with 200 for public template" do
      sign_in other
      get circuit_template_path(public_template)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET new" do
    it "requires authentication" do
      get new_circuit_template_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "POST create" do
    context "with valid params" do
      it "creates template and redirects" do
        sign_in owner
        expect do
          post circuit_templates_path, params: {
            circuit_template: {
              name:         "AND Gate",
              description:  "Basic AND gate circuit",
              public:       false,
              circuit_data: '{"components": []}'
            }
          }
        end.to change(CircuitTemplate, :count).by(1)
        expect(response).to redirect_to(circuit_template_path(CircuitTemplate.last))
      end
    end

    context "with invalid params" do
      it "re-renders new" do
        sign_in owner
        post circuit_templates_path, params: {
          circuit_template: { name: "", circuit_data: '{}' }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE destroy" do
    it "removes template if owner" do
      sign_in owner
      expect do
        delete circuit_template_path(public_template)
      end.to change(CircuitTemplate, :count).by(-1)
      expect(response).to redirect_to(circuit_templates_path)
    end

    it "is forbidden if not owner" do
      sign_in other
      delete circuit_template_path(public_template)
      expect(response).to redirect_to(circuit_templates_path)
    end
  end
end
