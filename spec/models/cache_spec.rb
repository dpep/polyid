RSpec.describe PolyId::Cache do
  let(:cache) { PolyId.cache }
  let(:model_name) { User.name }

  before do
    PolyId.cache = ActiveSupport::Cache::MemoryStore.new
  end

  after do
    PolyId.cache.clear
  end

  describe '.fetch_ids' do
    it 'does not invoke the miss block when all uuids are cached' do
      user = create(:user)

      User.id_for(user.uuid)

      expect {
        described_class.fetch_ids(model_name, uuids: [user.uuid]) do
          raise "unexpected cache miss"
        end
      }.not_to raise_error
    end

    it 'invokes the miss block only for uncached uuids and merges the results' do
      cached_user = create(:user)
      missed_user = create(:user)
      cache.clear

      User.id_for(cached_user.uuid)

      yielded = nil
      resolved = described_class.fetch_ids(model_name, uuids: [cached_user.uuid, missed_user.uuid]) do |missing_uuids|
        yielded = missing_uuids
        { missed_user.uuid => missed_user.id }
      end

      expect(yielded).to eq([missed_user.uuid])
      expect(resolved).to eq(
        cached_user.uuid => cached_user.id,
        missed_user.uuid => missed_user.id,
      )
    end
  end

  describe '.fetch_uuids' do
    it 'does not invoke the miss block when all ids are cached' do
      user = create(:user)

      User.uuid_for(user.id)

      expect {
        described_class.fetch_uuids(model_name, ids: [user.id]) do
          raise "unexpected cache miss"
        end
      }.not_to raise_error
    end

    it 'invokes the miss block only for uncached ids and merges the results' do
      cached_user = create(:user)
      missed_user = create(:user)
      cache.clear

      User.uuid_for(cached_user.id)

      yielded = nil
      resolved = described_class.fetch_uuids(model_name, ids: [cached_user.id, missed_user.id]) do |missing_ids|
        yielded = missing_ids
        { missed_user.id => missed_user.uuid }
      end

      expect(yielded).to eq([missed_user.id])
      expect(resolved).to eq(
        cached_user.id => cached_user.uuid,
        missed_user.id => missed_user.uuid,
      )
    end
  end

  describe '.find' do
    it 'uses bulk cache reads for mixed lookups' do
      first = create(:user)
      second = create(:user)
      User.id_for(first.uuid)

      allow(cache).to receive(:read_multi).and_call_original

      User.find(first.uuid, second.uuid)

      expect(cache).to have_received(:read_multi).at_least(:once)
    end
  end

  describe 'query cache warming' do
    it 'warms the translation cache when a record is loaded by query' do
      user = create(:user)
      cache.clear

      loaded = User.where(name: user.name).first

      expect(loaded).to eq(user)
      expect(User.id_for(user.uuid)).to eq(user.id)
      expect(User.uuid_for(user.id)).to eq(user.uuid)
    end

    it 'writes both id and uuid entries when a record is loaded by query' do
      user = create(:user)
      cache.clear

      User.where(id: user.id).first

      expect(described_class.read_multi(model_name, ids: [user.id], uuids: [user.uuid])).to eq(
        ids: { user.id => user.uuid },
        uuids: { user.uuid => user.id },
      )
    end
  end

  describe 'translation cache' do
    it 'uses the cache for repeat uuid lookups' do
      user = create(:user)

      expect(User.id_for(user.uuid)).to eq(user.id)

      allow(User).to receive(:find_by).and_raise("expected cache hit")

      expect(User.id_for(user.uuid)).to eq(user.id)
      expect(User.uuid_for(user.id)).to eq(user.uuid)
    end

    it 'writes both directions with a bulk cache write' do
      user = create(:user)
      cache.clear

      allow(cache).to receive(:write_multi).and_call_original

      User.id_for(user.uuid)

      expect(cache).to have_received(:write_multi).at_least(:once)
      expect(User.uuid_for(user.id)).to eq(user.uuid)
    end

    it 'uses bulk cache reads for ids_for and uuids_for' do
      first = create(:user)
      second = create(:user)
      User.id_for(first.uuid)
      User.uuid_for(second.id)

      allow(cache).to receive(:read_multi).and_call_original

      expect(User.ids_for([first.uuid, second.uuid])).to eq([first.id, second.id])
      expect(User.uuids_for([first.id, second.id])).to eq([first.uuid, second.uuid])
      expect(cache).to have_received(:read_multi).at_least(:twice)
    end

    it 'uses the cache for repeated batch lookups' do
      first = create(:user)
      second = create(:user)

      expect(User.ids_for([first.uuid, second.uuid])).to eq([first.id, second.id])
      expect(User.uuids_for([first.id, second.id])).to eq([first.uuid, second.uuid])

      allow(User).to receive(:where).and_raise("expected cache hit")

      expect(User.ids_for([first.uuid, second.uuid])).to eq([first.id, second.id])
      expect(User.uuids_for([first.id, second.id])).to eq([first.uuid, second.uuid])
    end

    it 'refreshes cached mappings when the uuid changes' do
      user = create(:user)
      old_uuid = user.uuid

      expect(User.id_for(old_uuid)).to eq(user.id)
      expect(User.uuid_for(user.id)).to eq(old_uuid)

      user.update!(uuid: SecureRandom.uuid)

      expect(User.id_for(old_uuid)).to be_nil
      expect(User.id_for(user.uuid)).to eq(user.id)
      expect(User.uuid_for(user.id)).to eq(user.uuid)
    end

    it 'evicts cached mappings when the record is destroyed' do
      user = create(:user)

      expect(User.id_for(user.uuid)).to eq(user.id)
      expect(User.uuid_for(user.id)).to eq(user.uuid)

      expect(cache).not_to be_empty

      user.destroy!

      expect(User.id_for(user.uuid)).to be_nil
      expect(User.uuid_for(user.id)).to be_nil

      expect(cache).to be_empty
    end
  end
end
