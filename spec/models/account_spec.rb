# frozen_string_literal: true

require "rails_helper"

RSpec.describe Account do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:slug) }

    it "generates slug from name on create" do
      account = build(:account, name: "My Company", slug: nil)
      account.valid?
      expect(account.slug).to eq("my-company")
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:owner).class_name("User") }
    it { is_expected.to have_many(:memberships).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:memberships) }
  end

  describe "#add_member" do
    let(:account) { create(:account) }
    let(:user) { create(:user) }

    it "creates an active membership" do
      membership = account.add_member(user, role: "admin")
      expect(membership).to be_persisted
      expect(membership.role).to eq("admin")
      expect(membership.status).to eq("active")
    end

    it "does not duplicate memberships" do
      account.add_member(user)
      expect { account.add_member(user) }.not_to change(Membership, :count)
    end
  end

  describe "#suspend!" do
    let(:account) { create(:account) }

    it "marks account as suspended" do
      account.suspend!(reason: "Non-payment")
      expect(account.suspended?).to be true
      expect(account.suspension_reason).to eq("Non-payment")
    end
  end
end
