RSpec.describe "polyid rollout" do
  describe User do
    describe "uuid assignment" do
      subject(:user) { create(:user, uuid: initial_uuid) }

      context "when the uuid is omitted" do
        let(:initial_uuid) { nil }

        it "assigns a uuid on create" do
          expect(user.uuid).to be_present
          expect(PolyId.is_uuid?(user.uuid)).to be true
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
