# frozen_string_literal: true

require "rails_helper"

RSpec.describe CircuitTemplate, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    it "requires a name" do
      template = build(:circuit_template, created_by: user, name: "")
      expect(template).not_to be_valid
    end

    it "requires created_by" do
      template = build(:circuit_template, created_by: nil)
      expect(template).not_to be_valid
    end
  end

  describe "scopes" do
    it "public_templates returns only public ones" do
      public_t  = create(:circuit_template, created_by: user, public: true)
      private_t = create(:circuit_template, created_by: user, public: false)
      expect(CircuitTemplate.public_templates).to include(public_t)
      expect(CircuitTemplate.public_templates).not_to include(private_t)
    end

    it "by_user scope returns only user's templates" do
      other = create(:user)
      mine  = create(:circuit_template, created_by: user)
      theirs = create(:circuit_template, created_by: other)
      expect(CircuitTemplate.by_user(user)).to include(mine)
      expect(CircuitTemplate.by_user(user)).not_to include(theirs)
    end
  end

  describe "associations" do
    it "can have many assignments" do
      template = create(:circuit_template, created_by: user)
      group    = create(:group, primary_mentor: user)
      a1 = create(:assignment, group: group, circuit_template: template)
      a2 = create(:assignment, group: group, circuit_template: template)
      expect(template.assignments).to include(a1, a2)
    end
  end
end
