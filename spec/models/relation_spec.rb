RSpec.describe "relation lookups" do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }

  describe "collection ids" do
    it "skips blanks, as ActiveRecord does" do
      account.user_ids = ["", user.uuid]

      expect(account.reload.users).to eq([user])
    end
  end

  describe "#find" do
    it "finds by uuid through an association" do
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

    context "with a uuid that resolves to nothing" do
      include_context "with a decoy row"

      { account_id: "Account", account: "Account", id: "User", "users.id" => "User" }.each do |key, model|
        it "names the missing #{model} given #{key.inspect}" do
          expect {
            User.find_or_create_by!(key => UNRESOLVED_UUID)
          }.to raise_error(ActiveRecord::RecordNotFound) { |error|
            expect([error.message, error.model, error.primary_key, error.id]).to eq(
              ["Couldn't find #{model} with 'id'=#{UNRESOLVED_UUID}", model, "id", UNRESOLVED_UUID],
            )
          }
        end
      end

      it "does not match rows with no foreign key" do
        create(:user, account: nil)

        expect(User.where(account_id: [UNRESOLVED_UUID])).to be_empty
      end
    end

    it "leaves a foreign key onto the uuid alone" do
      org = Org.create!
      member = Member.create!(org:)

      expect(Member.where(org_uuid: org.uuid)).to eq([member])
      expect(Member.where(org: org.uuid)).to eq([member])
    end

    context "when the association is named differently from its table" do
      let!(:decoy) { create(:user, id: 123) }
      # integer-casts to 123, so an untranslated value would match the decoy
      let!(:maker) { create(:user, id: 777, uuid: "123e4567-e89b-42d3-a456-426614174000") }
      let!(:gadget) { Gadget.create!(thing_id: maker.id) }

      before { Gadget.create!(thing_id: decoy.id) }

      it "translates a nested condition" do
        expect(Gadget.joins(:maker).where(users: { id: maker.uuid })).to eq([gadget])
      end

      it "translates a table-qualified key" do
        expect(Gadget.joins(:maker).where("users.id" => maker.uuid)).to eq([gadget])
      end

      it "translates a foreign key shared with an association that doesn't load" do
        expect(Gadget.where(thing_id: maker.uuid)).to eq([gadget])
      end

      it "leaves a table it can't place alone" do
        expect(Gadget.where("others.id" => maker.uuid).to_sql).to include("others")
      end
    end

    it "does not resolve associations for values that aren't uuids" do
      expect(Gadget.where(thing_id: 3)).to be_empty
    end

    it "accepts permitted params" do
      params = permitted_params("id" => user.uuid)

      expect(User.where(params)).to eq([user])
      expect(User.find_by(params)).to eq(user)
    end

    it "creates through an association given its uuid" do
      account = create(:account, id: 50)

      expect(User.find_or_create_by!(account: account.uuid, name: "a").account).to eq(account)
      expect(User.find_or_initialize_by(account: account.uuid, name: "b").account).to eq(account)
    end

    it "still creates through an association given a record" do
      account = create(:account, id: 50)

      expect(User.find_or_create_by!(account:).account).to eq(account)
    end

    it "creates with translated foreign keys from permitted params" do
      account = create(:account, id: 50)

      expect(User.find_or_create_by!(permitted_params("account_id" => account.uuid)).account).to eq(account)
    end

    it "creates with translated foreign keys" do
      account = create(:account, id: 50)

      expect(User.find_or_create_by!(account_id: account.uuid).account).to eq(account)
      expect(User.create_or_find_by!(account_id: account.uuid, uuid: SecureRandom.uuid).account).to eq(account)
      expect(User.find_or_initialize_by(account_id: account.uuid).account).to eq(account)
    end

    it "accepts a set" do
      expect(User.where(id: Set[user.uuid])).to eq([user])
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
      legacy = LegacyUser.create!(id: 123, name: "legacy")

      expect(LegacyUser.all.find(legacy.id)).to eq(legacy)
      expect(LegacyUser.where(id: legacy.id)).to eq([legacy])
      # integer-cast, as ActiveRecord does
      expect(LegacyUser.where(id: UNRESOLVED_UUID)).to eq([legacy])
    end
  end
end
