# frozen_string_literal: true

require "rails_helper"

RSpec.describe Group, type: :model do
  let(:mentor) { create(:user) }
  let(:parent) { create(:group, primary_mentor: mentor) }

  describe "hierarchy methods" do
    it "root? returns true for top-level group" do
      expect(parent.root?).to be true
    end

    it "depth returns 0 for root group" do
      expect(parent.depth).to eq 0
    end

    it "ancestors returns empty for root group" do
      expect(parent.ancestors).to be_empty
    end

    it "root? returns false for child group" do
      child = create(:group, primary_mentor: mentor, parent_group: parent)
      expect(child.root?).to be false
    end

    it "depth returns 1 for child group" do
      child = create(:group, primary_mentor: mentor, parent_group: parent)
      expect(child.depth).to eq 1
    end

    it "ancestors returns parent for child group" do
      child = create(:group, primary_mentor: mentor, parent_group: parent)
      expect(child.ancestors).to eq [parent]
    end
  end

  describe "max depth validation" do
    it "rejects groups nested beyond depth 3" do
      child      = create(:group, primary_mentor: mentor, parent_group: parent)
      grandchild = create(:group, primary_mentor: mentor, parent_group: child)
      great      = build(:group,  primary_mentor: mentor, parent_group: grandchild)
      expect(great).not_to be_valid
    end
  end
end
