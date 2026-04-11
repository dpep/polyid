RSpec.describe PolyId::Cache do
  let(:cache) { PolyId.cache }

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
  end

  describe 'translation cache' do
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
