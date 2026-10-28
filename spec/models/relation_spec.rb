RSpec.describe "relation lookups" do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  describe "#find" do
    it "finds by uuid through a relation" do
      expect(User.where(name: user.name).find(user.uuid)).to eq(user)
    end

    it "finds by uuid through an association" do
      expect(account.users.find(user.uuid)).to eq(user)
    end

    it "finds by uuid through a loaded association" do
      account.users.load

      expect(account.users.find(user.uuid)).to eq(user)
    end

    it "accepts ids, uuids, and a mix of both" do
      other = create(:user, account:)

      expect(account.users.find(user.id, other.uuid)).to eq([user, other])
      expect(account.users.find([user.uuid, other.id])).to eq([user, other])
    end

    it "still enforces the scope" do
      stranger = create(:user)

      expect {
        account.users.find(stranger.uuid)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises when the uuid does not exist" do
      expect {
        User.all.find(UNKNOWN_UUID)
      }.to raise_error(ActiveRecord::RecordNotFound, /=#{Regexp.escape(UNKNOWN_UUID)}/)
    end

    it "resolves uuids outside the default scope" do
      stub_const("ScopedUser", Class.new(User) { default_scope { where.not(name: "hidden") } })
      hidden = ScopedUser.create!(name: "hidden")

      expect(ScopedUser.unscoped.find(hidden.uuid)).to eq(hidden)
    end

    it "still yields to the block form" do
      user
      other = create(:user, name: "needle")

      expect(User.all.find { |u| u.name == "needle" }).to eq(other)
    end
  end

  describe "#where" do
    it "looks up the primary key by uuid" do
      expect(User.where(id: user.uuid)).to eq([user])
    end

    it "looks up the primary key by uuid through an association" do
      expect(account.users.where(id: user.uuid)).to eq([user])
    end

    it "accepts a mix of ids and uuids" do
      other = create(:user)

      expect(User.where(id: [user.uuid, other.id])).to match_array([user, other])
    end

    it "accepts string keys" do
      expect(User.where("id" => user.uuid)).to eq([user])
    end

    it "returns nothing when the uuid does not exist" do
      expect(User.where(id: UNKNOWN_UUID)).to be_empty
    end

    it "accepts table-qualified keys" do
      expect(User.where("users.id" => user.uuid)).to eq([user])
      expect(User.joins(:account).where("accounts.id" => account.uuid)).to eq([user])
    end

    it "translates foreign keys and belongs_to associations" do
      # v7 uuids start "01", which an untranslated integer cast reads as id 1
      account = create(:account, id: 42)
      user = create(:user, account:)

      expect(User.where(account_id: account.uuid)).to eq([user])
      expect(User.where(account: account.uuid)).to eq([user])
    end

    context "with a uuid that resolves to nothing" do
      # integer-casts to 190, so a fall-through would match these
      let(:unknown) { "0190abcd-0000-7000-8000-000000000001" }
      let!(:account) { create(:account, id: 190) }
      let!(:user) { create(:user, id: 190, account:) }

      it "matches nothing rather than an integer-cast id" do
        expect(User.where(id: unknown)).to be_empty
        expect(User.find_by(id: unknown)).to be_nil
        expect(User.where("users.id" => unknown)).to be_empty
        expect(User.where(account_id: unknown)).to be_empty
        expect(User.exists?(unknown)).to be false
      end

      it "deletes nothing" do
        expect { User.delete(unknown) }.not_to change(User, :count)
      end

      it "does not match rows with no foreign key" do
        create(:user, account: nil)

        expect(User.where(account_id: [unknown])).to be_empty
      end
    end

    it "accepts a set" do
      expect(User.where(id: Set[user.uuid])).to eq([user])
    end

    it "ignores surrounding whitespace" do
      expect(User.where(id: " #{user.uuid}\n")).to eq([user])
    end

    it "supports find_by" do
      expect(User.find_by(id: user.uuid)).to eq(user)
    end

    it "supports where.not" do
      other = create(:user)

      expect(User.where.not(id: user.uuid)).to eq([other])
    end

    it "supports rewhere" do
      other = create(:user)

      expect(User.where(id: other.id).rewhere(id: user.uuid)).to eq([user])
    end

    it "leaves other conditions alone" do
      expect(User.where(uuid: user.uuid)).to eq([user])
      expect(User.where("name = ?", user.name)).to eq([user])
      expect(User.where(id: user.id)).to eq([user])
      expect(User.where(id: user.id..)).to eq([user])
      expect(User.where(name: nil)).to be_empty
    end
  end

  describe "nested conditions" do
    it "translates conditions on an associated model" do
      user

      expect(Account.joins(:users).where(users: { id: user.uuid })).to eq([account])
    end

    it "resolves the association by table name" do
      expect(User.joins(:account).where(accounts: { id: account.uuid })).to eq([user])
    end

    it "translates even when the parent model is not polyid" do
      legacy = LegacyUser.create!(name: "legacy")
      user.update!(legacy_user: legacy)

      expect(LegacyUser.joins(:users).where(users: { id: user.uuid })).to eq([legacy])
    end

    it "resolves the model own table" do
      expect(User.joins(:account).where(users: { id: user.uuid })).to eq([user])
    end

    it "leaves polymorphic associations alone" do
      conditions = { owner: { id: SecureRandom.uuid } }

      expect(Widget.polyid_translate_conditions(conditions)).to eq(conditions)
    end

    it "leaves unresolvable and non-uuid conditions alone" do
      expect(Account.joins(:users).where(users: { name: user.name })).to eq([account])
      expect(Account.joins(:users).where(users: { id: user.id })).to eq([account])
    end
  end

  context "with a binary uuid column" do
    it "finds by uuid through a relation" do
      account

      expect(Account.all.find(account.uuid)).to eq(account)
      expect(Account.where(id: account.uuid)).to eq([account])
    end
  end

  context "without polyid" do
    it "leaves lookups untouched" do
      legacy = LegacyUser.create!(name: "legacy")

      expect(LegacyUser.all.find(legacy.id)).to eq(legacy)
      expect(LegacyUser.where(id: legacy.id)).to eq([legacy])
      expect(LegacyUser.where(id: UNKNOWN_UUID)).to be_empty
    end
  end
end
