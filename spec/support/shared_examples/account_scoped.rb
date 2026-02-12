# frozen_string_literal: true

# Shared examples to verify multi-tenant scoping.
# Usage:
#   it_behaves_like "account scoped", :project
RSpec.shared_examples "account scoped" do |factory_name|
  it "scopes records to the current account" do
    account1 = create(:account)
    account2 = create(:account)

    Current.account = account1
    record1 = create(factory_name, account: account1)
    record2 = create(factory_name, account: account2)

    expect(described_class.current).to include(record1)
    expect(described_class.current).not_to include(record2)
  end

  it "does not leak data between accounts" do
    account1 = create(:account)
    account2 = create(:account)

    create(factory_name, account: account1)
    create(factory_name, account: account2)

    Current.account = account1
    expect(described_class.current.count).to eq(1)

    Current.account = account2
    expect(described_class.current.count).to eq(1)
  end
end
