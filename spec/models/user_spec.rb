RSpec.describe User do
  describe 'database' do
    it 'creates a user' do
      user = User.create(name: 'John Doe')
      expect(user).to be_persisted
      expect(user.id).to be_present
      expect(user.name).to eq('John Doe')
    end

    it 'retrieves a user' do
      User.create(name: 'Jane Doe')
      user = User.find_by(name: 'Jane Doe')
      expect(user).not_to be_nil
      expect(user.name).to eq('Jane Doe')
    end

    it 'updates a user' do
      user = User.create(name: 'Bob Smith')
      user.update(name: 'Bob Smith Jr.')
      expect(user.reload.name).to eq('Bob Smith Jr.')
    end

    it 'deletes a user' do
      user = User.create(name: 'Alice Jones')
      user.destroy
      expect(User.find_by(id: user.id)).to be_nil
    end
  end
end
