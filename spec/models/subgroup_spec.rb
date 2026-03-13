# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subgroup, type: :model do
  let(:mentor) { create(:user) }
  let(:group)  { create(:group, primary_mentor: mentor) }

  describe "validations" do
    it "requires a name" do
      subgroup = build(:subgroup, group: group, name: "")
      expect(subgroup).not_to be_valid
    end

    it "enforces unique name within group" do
      create(:subgroup, group: group, name: "Team A")
      dupe = build(:subgroup, group: group, name: "Team A")
      expect(dupe).not_to be_valid
    end

    it "allows same name in different groups" do
      group2 = create(:group, primary_mentor: mentor)
      create(:subgroup, group: group,  name: "Team A")
      other  = build(:subgroup,  group: group2, name: "Team A")
      expect(other).to be_valid
    end
  end

  describe "#full?" do
    it "returns false when no max_size set" do
      subgroup = create(:subgroup, group: group, max_size: nil)
      expect(subgroup.full?).to be false
    end

    it "returns false when under max_size" do
      subgroup = create(:subgroup, group: group, max_size: 4)
      expect(subgroup.full?).to be false
    end
  end
end
