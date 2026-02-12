# frozen_string_literal: true

require "rails_helper"

RSpec.describe Membership do
  describe "validations" do
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_inclusion_of(:role).in_array(Membership::ROLES) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(Membership::STATUSES) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:invited_by).class_name("User").optional }
  end

  describe "role helpers" do
    it "identifies owner role" do
      membership = build(:membership, :owner)
      expect(membership.owner?).to be true
      expect(membership.admin?).to be true
      expect(membership.can_manage_billing?).to be true
    end

    it "identifies admin role" do
      membership = build(:membership, :admin)
      expect(membership.owner?).to be false
      expect(membership.admin?).to be true
      expect(membership.can_invite_members?).to be true
    end

    it "identifies member role" do
      membership = build(:membership, role: "member")
      expect(membership.owner?).to be false
      expect(membership.admin?).to be false
    end
  end
end
