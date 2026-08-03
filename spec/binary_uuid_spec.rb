RSpec.describe Account do
  describe "binary uuid columns" do
    subject(:account) { create(:account) }

    let(:raw_account_uuid) do
      described_class.connection.select_value(described_class.where(id: account.id).select(:uuid).to_sql)
    end

    it "auto-detects polyid and applies the binary uuid type" do
      expect(described_class.polyid?).to be true
      expect(described_class.type_for_attribute("uuid")).to be_a(PolyId::BinaryUuidType)
    end

    it "assigns a uuid string while storing binary bytes" do
      expect(account.uuid).to be_a_uuid
      expect(raw_account_uuid).to be_a String
      expect(raw_account_uuid.bytesize).to eq 16
    end

    context "when a uuid is provided" do
      subject(:account) { create(:account, uuid:) }

      let(:uuid) { SecureRandom.uuid }

      it "preserves the logical uuid value" do
        expect(account.uuid).to eq uuid
        expect(raw_account_uuid.bytesize).to eq 16
      end
    end

    it "finds a binary-backed row by uuid string" do
      expect(described_class.find(account.uuid)).to eq account
    end

    it "serializes scalar hash where clauses automatically" do
      expect(described_class.where(uuid: account.uuid).first).to eq account
    end

    it "serializes array hash where clauses automatically" do
      expect(described_class.where(uuid: [account.uuid]).first).to eq account
    end

    it "translates ids and uuids through the binary-backed column" do
      expect(described_class.id_for(account.uuid)).to eq account.id
      expect(described_class.uuid_for(account.id)).to eq account.uuid
    end

    describe "invalid input" do
      it "misses rather than raising, matching a string uuid column" do
        account

        expect(described_class.find_by(uuid: "not-a-uuid")).to be_nil
        expect(User.find_by(uuid: "not-a-uuid")).to be_nil
      end

      it "is rejected on create rather than silently replaced" do
        expect {
          described_class.create!(uuid: 'garbage')
        }.to raise_error(ActiveRecord::RecordInvalid, /Uuid is invalid/)
      end

      it "does not match rows still awaiting a uuid" do
        described_class.connection.execute(
          "INSERT INTO accounts (name, uuid) VALUES ('legacy', NULL)"
        )

        expect(described_class.find_by(uuid: "not-a-uuid")).to be_nil
        expect(described_class.find_by(uuid: nil)&.name).to eq('legacy')
      end
    end

    # the binary type has to be registered before the schema resolves column
    # types, so a class whose very first use is a query still gets it
    context "when the first touch is a query" do
      let(:cold_model) do
        Class.new(ActiveRecord::Base) do
          self.table_name = 'accounts'

          def self.name = 'ColdAccount'
        end
      end

      it "applies the binary uuid type" do
        account

        expect(cold_model.where(uuid: account.uuid).first&.id).to eq account.id
      end

      it "translates a uuid" do
        account

        expect(cold_model.id_for(account.uuid)).to eq account.id
      end
    end
  end
end
