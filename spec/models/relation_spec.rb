RSpec.describe 'relation lookups' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  describe '#find' do
    it 'finds by uuid through a relation' do
      expect(User.where(name: user.name).find(user.uuid)).to eq(user)
    end

    it 'finds by uuid through an association' do
      expect(account.users.find(user.uuid)).to eq(user)
    end

    it 'finds by uuid through a loaded association' do
      account.users.load

      expect(account.users.find(user.uuid)).to eq(user)
    end

    it 'accepts ids, uuids, and a mix of both' do
      other = create(:user, account: account)

      expect(account.users.find(user.id, other.uuid)).to eq([ user, other ])
      expect(account.users.find([ user.uuid, other.id ])).to eq([ user, other ])
    end

    it 'still enforces the scope' do
      stranger = create(:user)

      expect {
        account.users.find(stranger.uuid)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises when the uuid does not exist' do
      expect {
        User.all.find(SecureRandom.uuid)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'still yields to the block form' do
      user
      other = create(:user, name: 'needle')

      expect(User.all.find { |u| u.name == 'needle' }).to eq(other)
    end
  end

  describe '#where' do
    it 'looks up the primary key by uuid' do
      expect(User.where(id: user.uuid)).to eq([ user ])
    end

    it 'looks up the primary key by uuid through an association' do
      expect(account.users.where(id: user.uuid)).to eq([ user ])
    end

    it 'accepts a mix of ids and uuids' do
      other = create(:user)

      expect(User.where(id: [ user.uuid, other.id ])).to match_array([ user, other ])
    end

    it 'accepts string keys' do
      expect(User.where('id' => user.uuid)).to eq([ user ])
    end

    it 'returns nothing when the uuid does not exist' do
      expect(User.where(id: SecureRandom.uuid)).to be_empty
    end

    it 'supports find_by' do
      expect(User.find_by(id: user.uuid)).to eq(user)
    end

    it 'supports where.not' do
      other = create(:user)

      expect(User.where.not(id: user.uuid)).to eq([ other ])
    end

    it 'supports rewhere' do
      other = create(:user)

      expect(User.where(id: other.id).rewhere(id: user.uuid)).to eq([ user ])
    end

    it 'leaves other conditions alone' do
      expect(User.where(uuid: user.uuid)).to eq([ user ])
      expect(User.where('name = ?', user.name)).to eq([ user ])
      expect(User.where(id: user.id)).to eq([ user ])
      expect(User.where(id: user.id..)).to eq([ user ])
      expect(User.where(name: nil)).to be_empty
    end
  end

  describe 'nested conditions' do
    it 'translates conditions on an associated model' do
      user

      expect(Account.joins(:users).where(users: { id: user.uuid })).to eq([ account ])
    end

    it 'resolves the association by table name' do
      expect(User.joins(:account).where(accounts: { id: account.uuid })).to eq([ user ])
    end

    it 'translates even when the parent model is not polyid' do
      legacy = LegacyUser.create!(name: 'legacy')
      user.update!(legacy_user: legacy)

      expect(LegacyUser.joins(:users).where(users: { id: user.uuid })).to eq([ legacy ])
    end

    it 'leaves unresolvable and non-uuid conditions alone' do
      expect(Account.joins(:users).where(users: { name: user.name })).to eq([ account ])
      expect(Account.joins(:users).where(users: { id: user.id })).to eq([ account ])
    end
  end

  context 'with a binary uuid column' do
    it 'finds by uuid through a relation' do
      account

      expect(Account.all.find(account.uuid)).to eq(account)
      expect(Account.where(id: account.uuid)).to eq([ account ])
    end
  end

  context 'without polyid' do
    it 'leaves lookups untouched' do
      legacy = LegacyUser.create!(name: 'legacy')

      expect(LegacyUser.all.find(legacy.id)).to eq(legacy)
      expect(LegacyUser.where(id: legacy.id)).to eq([ legacy ])
      expect(LegacyUser.where(id: SecureRandom.uuid)).to be_empty
    end
  end
end
