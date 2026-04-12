RSpec.describe Account do
  describe "binary uuid columns" do
    subject(:account) { create(:account) }

    let(:raw_account_uuid) do
      described_class.connection.select_value(described_class.where(id: account.id).select(:uuid).to_sql)
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
  end
end
