RSpec.describe "a uuid that escapes translation" do
  let(:account) { create(:account) }

  describe "on a path polyid doesn't translate" do
    it "raises on create" do
      expect {
        User.create!(account_id: account.uuid)
      }.to raise_error(PolyId::UntranslatedUuidError, /users\.account_id/)
    end

    it "raises on create_with" do
      expect { User.create_with(account_id: account.uuid).create! }.to raise_error(PolyId::UntranslatedUuidError)
    end

    it "raises on update_all" do
      create(:user)

      expect { User.update_all(account_id: account.uuid) }.to raise_error(PolyId::UntranslatedUuidError)
    end

    it "raises on insert_all" do
      expect {
        User.insert_all([{ uuid: SecureRandom.uuid, account_id: account.uuid }])
      }.to raise_error(PolyId::UntranslatedUuidError)
    end

    it "raises on an arel predicate against the primary key" do
      expect { User.where(User.arel_table[:id].eq(UNRESOLVED_UUID)).to_a }.to raise_error(PolyId::UntranslatedUuidError)
    end
  end

  describe "on an integer key" do
    it "still accepts a numeric string" do
      user = create(:user, account:)

      expect(User.where(account_id: account.id.to_s)).to eq([user])
    end

    it "matches nothing for a non-numeric string, not rows without a foreign key" do
      create(:user, account: nil)

      expect(User.where(account_id: "abc")).to be_empty
    end
  end

  it "leaves a polymorphic foreign key alone" do
    widget = create(:widget, owner_type: "User", owner_id: 123)

    # integer-cast, as ActiveRecord does
    expect(Widget.where(owner_id: UNRESOLVED_UUID)).to eq([widget])
  end

  it "leaves a model without polyid alone" do
    expect(LegacyUser.create!(id: UNRESOLVED_UUID).id).to eq(123)
  end

  it "keeps records marshalable in the 6.1 format, which dumps attribute types" do
    original = ActiveRecord.marshalling_format_version
    ActiveRecord.marshalling_format_version = 6.1
    user = create(:user, account:).reload

    expect(Marshal.load(Marshal.dump(user)).account_id).to eq(account.id)
  ensure
    ActiveRecord.marshalling_format_version = original
  end
end
