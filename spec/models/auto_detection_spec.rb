RSpec.describe "auto-detection" do
  it "automatically enables polyid behavior for models with id and uuid columns" do
    user = create(:user)

    expect(User.polyid?).to be(true)
    expect(User.find(user.uuid)).to eq(user)
    expect(User.id_for(user.uuid)).to eq(user.id)
    expect(User.uuid_for(user.id)).to eq(user.uuid)
  end

  it "does not auto-enable models missing a uuid column" do
    user = LegacyUser.create!(name: "Legacy")

    expect(LegacyUser.polyid?).to be(false)
    expect(LegacyUser.find(user.id)).to eq(user)
    expect { LegacyUser.find(UNKNOWN_UUID) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "raises when translating on a model without polyid" do
    LegacyUser.create!(name: "Legacy")

    expect { LegacyUser.id_for(UNKNOWN_UUID) }.to raise_error(/not configured with polyid/)
    expect { LegacyUser.uuid_for(1) }.to raise_error(/not configured with polyid/)
    expect { LegacyUser.ids_for([UNKNOWN_UUID]) }.to raise_error(/not configured with polyid/)
    expect { LegacyUser.uuids_for([1]) }.to raise_error(/not configured with polyid/)
  end

  it "can disable auto-detection globally" do
    PolyId.auto_detect = false
    user = User.create!(name: "User", uuid: UNKNOWN_UUID)

    expect(User.polyid?).to be(false)
    expect { User.find(user.uuid) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "does not auto-enable a model whose database is unavailable" do
    model = stub_const("Unreachable", Class.new(ActiveRecord::Base) { self.table_name = "users" })
    allow(model).to receive(:table_exists?).and_raise(ActiveRecord::StatementInvalid)

    expect(model.polyid?).to be false
  end

  it "detects again once the database recovers" do
    model = stub_const("Flaky", Class.new(ActiveRecord::Base) { self.table_name = "users" })
    allow(model).to receive(:table_exists?).and_raise(ActiveRecord::StatementInvalid)
    model.polyid?

    allow(model).to receive(:table_exists?).and_call_original

    expect(model.polyid?).to be true
  end
end
