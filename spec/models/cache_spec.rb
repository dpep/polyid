RSpec.describe PolyId::Cache do
  let(:cache) { PolyId.cache }
  let(:model_name) { User.name }

  before do
    PolyId.cache = ActiveSupport::Cache::MemoryStore.new
  end

  after do
    PolyId.cache.clear
  end

  describe 'expiry' do
    subject(:cached) { described_class.read_multi(model_name, ids: [user.id], uuids: [user.uuid]) }

    let(:user) { create(:user) }

    before { described_class.write(model_name, id: user.id, uuid: user.uuid) }

    it 'caches both directions' do
      expect(cached[:ids]).to eq(user.id => user.uuid)
      expect(cached[:uuids]).to eq(user.uuid => user.id)
    end

    it 'keeps entries within the ttl' do
      travel_to(PolyId.cache_ttl.from_now - 1.day) do
        expect(cached[:ids]).to be_present
        expect(cached[:uuids]).to be_present
      end
    end

    it 'expires entries after the ttl' do
      travel_to(PolyId.cache_ttl.from_now + 1.minute) do
        expect(cached[:ids]).to be_empty
        expect(cached[:uuids]).to be_empty
      end
    end

    it 'can be disabled' do
      PolyId.cache_ttl = nil
      described_class.write(model_name, id: user.id, uuid: user.uuid)

      travel_to(10.years.from_now) do
        expect(cached[:ids]).to be_present
      end
    end
  end

  describe 'read-through' do
    let(:uuid) { SecureRandom.uuid }

    it 'caches what the miss block resolves, in both directions' do
      described_class.fetch_ids(model_name, uuids: [uuid]) { { uuid => 42 } }

      cached = described_class.read_multi(model_name, ids: [42], uuids: [uuid])
      expect(cached[:uuids]).to eq(uuid => 42)
      expect(cached[:ids]).to eq(42 => uuid)
    end

    it 'caches uuid lookups too' do
      described_class.fetch_uuids(model_name, ids: [42]) { { 42 => uuid } }

      cached = described_class.read_multi(model_name, ids: [42], uuids: [uuid])
      expect(cached[:ids]).to eq(42 => uuid)
      expect(cached[:uuids]).to eq(uuid => 42)
    end

    it 'writes every resolved mapping in one call' do
      mappings = 5.times.to_h { |i| [SecureRandom.uuid, i] }

      expect(cache).to receive(:write_multi).once.and_call_original

      described_class.fetch_ids(model_name, uuids: mappings.keys) { mappings }
    end
  end

  describe '.fetch_ids' do
    it 'does not invoke the miss block when all uuids are cached' do
      user = create(:user)

      User.id_for(user.uuid)

      expect { |block|
        described_class.fetch_ids(model_name, uuids: [user.uuid], &block)
      }.not_to yield_control
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

      expect { |block|
        described_class.fetch_uuids(model_name, ids: [user.id], &block)
      }.not_to yield_control
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

  describe 'record loads' do
    it 'does not write to the cache' do
      user = create(:user)
      cache.clear

      User.where(id: user.id).to_a

      expect(described_class.read_multi(model_name, ids: [user.id], uuids: [user.uuid])).to eq(
        ids: {},
        uuids: {},
      )
    end

    it 'still translates, via the read-through' do
      user = create(:user)
      cache.clear

      User.where(id: user.id).to_a

      expect(User.id_for(user.uuid)).to eq(user.id)
      expect(User.uuid_for(user.id)).to eq(user.uuid)
    end
  end

  describe 'save cache warming' do
    it 'writes both id and uuid entries when a record is saved' do
      user = create(:user)
      cache.clear

      user.update!(name: "Updated Name")

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

    it 'keeps cached mappings stable when a uuid update is rejected' do
      user = create(:user)
      original_uuid = user.uuid

      expect(User.id_for(original_uuid)).to eq(user.id)
      expect(User.uuid_for(user.id)).to eq(original_uuid)

      expect {
        user.update!(uuid: SecureRandom.uuid)
      }.to raise_error(ActiveRecord::RecordInvalid, /Uuid is immutable/)

      expect(User.id_for(original_uuid)).to eq(user.id)
      expect(User.uuid_for(user.id)).to eq(original_uuid)
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
