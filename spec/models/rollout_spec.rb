RSpec.describe "polyid rollout" do
  describe User do
    describe "uuid assignment" do
      subject(:user) { create(:user, uuid: initial_uuid) }

      context "when the uuid is omitted" do
        let(:initial_uuid) { nil }

        it "assigns a uuid on create" do
          expect(user.uuid).to be_a_uuid
        end
      end

      context "when a uuid is provided" do
        let(:initial_uuid) { SecureRandom.uuid }

        it "preserves the provided value" do
          expect(user.uuid).to eq(initial_uuid)
        end
      end

      it "uses the configured global generator by default" do
        PolyId.uuid_generator = -> { "00000000-0000-7000-8000-000000000002" }

        expect(create(:user, uuid: nil).uuid).to eq("00000000-0000-7000-8000-000000000002")
      end
    end
  end

  describe "backfilling a row that predates polyid" do
    # update_columns skips the callbacks, the same way the rake task does
    subject(:account) { create(:account).tap { |a| a.update_columns(uuid: nil) }.reload }

    it "starts without a uuid" do
      expect(account.uuid).to be_nil
    end

    it "accepts a uuid" do
      uuid = SecureRandom.uuid
      account.update!(uuid: uuid)

      expect(account.reload.uuid).to eq(uuid)
    end

    it "rejects an invalid uuid" do
      expect {
        account.update!(uuid: 'garbage')
      }.to raise_error(ActiveRecord::RecordInvalid, /invalid/)
    end

    it "can still be saved while awaiting one" do
      account.update!(name: 'renamed')

      expect(account.reload.uuid).to be_nil
    end

    it "is immutable once backfilled" do
      account.update!(uuid: SecureRandom.uuid)

      expect {
        account.update!(uuid: SecureRandom.uuid)
      }.to raise_error(ActiveRecord::RecordInvalid, /immutable/)
    end
  end

  describe Widget do
    subject(:widget) { create(:widget) }

    it "supports a custom uuid attribute" do
      expect(widget.public_id).to eq("00000000-0000-7000-8000-000000000001")
    end

    it "allows a model-specific generator override" do
      expect(widget.public_id).to eq("00000000-0000-7000-8000-000000000001")
    end

    it "prefers the model-specific generator over the global generator" do
      PolyId.uuid_generator = -> { "00000000-0000-7000-8000-000000000002" }

      expect(widget.public_id).to eq("00000000-0000-7000-8000-000000000001")
    end
  end
end
