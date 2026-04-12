RSpec.describe User do
  describe 'database' do
    it 'creates a user' do
      user = create(:user, name: 'John Doe')
      expect(user).to be_persisted
      expect(user.id).to be_present
      expect(user.uuid).to be_present
      expect(user.name).to eq('John Doe')
    end

    it 'retrieves a user' do
      create(:user, name: 'Jane Doe')
      user = User.find_by(name: 'Jane Doe')
      expect(user).not_to be_nil
      expect(user.name).to eq('Jane Doe')
    end

    it 'updates a user' do
      user = create(:user, name: 'Bob Smith')
      user.update(name: 'Bob Smith Jr.')
      expect(user.reload.name).to eq('Bob Smith Jr.')
    end

    it 'does not allow the uuid to change' do
      user = create(:user)
      original_uuid = user.uuid

      expect {
        user.update!(uuid: SecureRandom.uuid)
      }.to raise_error(ActiveRecord::RecordInvalid, /Uuid is immutable/)

      expect(user.reload.uuid).to eq(original_uuid)
    end

    it 'deletes a user' do
      user = create(:user, name: 'Alice Jones')
      user.destroy
      expect(User.find_by(id: user.id)).to be_nil
    end
  end

  describe '.find' do
    subject(:found_user) { User.find(lookup) }

    context 'when looking up by integer id' do
      let(:user) { create(:user) }
      let(:lookup) { user.id }

      it { is_expected.to eq(user) }
    end

    context 'when looking up by uuid' do
      let(:user) { create(:user) }
      let(:lookup) { user.uuid }

      it { is_expected.to eq(user) }
    end

    it 'finds multiple records by mixed ids and uuids' do
      first = create(:user)
      second = create(:user)

      expect(User.find(first.id, second.uuid)).to contain_exactly(first, second)
      expect(User.find([first.uuid, second.id])).to contain_exactly(first, second)
    end

    it 'raises when a uuid does not resolve to a record' do
      expect {
        User.find(SecureRandom.uuid)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'translation helpers' do
    let(:user) { create(:user) }

    describe '.id_for' do
      subject(:id_for) { User.id_for(lookup) }

      context 'when looking up by uuid' do
        let(:lookup) { user.uuid }

        it { is_expected.to eq(user.id) }
      end

      context 'when looking up by id' do
        let(:lookup) { user.id }

        it { is_expected.to eq(user.id) }
      end
    end

    describe '.uuid_for' do
      subject(:uuid_for) { User.uuid_for(lookup) }

      context 'when looking up by id' do
        let(:lookup) { user.id }

        it { is_expected.to eq(user.uuid) }
      end

      context 'when looking up by uuid' do
        let(:lookup) { user.uuid }

        it { is_expected.to eq(user.uuid) }
      end
    end

    it 'translates multiple ids and uuids in order' do
      first = create(:user)
      second = create(:user)
      missing_uuid = SecureRandom.uuid

      expect(User.ids_for([first.uuid, second.id, missing_uuid, nil])).to eq([first.id, second.id, nil, nil])
      expect(User.uuids_for([first.id, second.uuid, 999_999, nil])).to eq([first.uuid, second.uuid, nil, nil])
    end

    it 'does not query for identity translations' do
      user = create(:user)

      allow(User).to receive(:find_by).and_raise("unexpected query")
      allow(User).to receive(:where).and_raise("unexpected query")

      expect(User.id_for(user.id)).to eq(user.id)
      expect(User.uuid_for(user.uuid)).to eq(user.uuid)
      expect(User.ids_for([user.id, nil])).to eq([user.id, nil])
      expect(User.uuids_for([user.uuid, nil])).to eq([user.uuid, nil])
    end
  end
end
