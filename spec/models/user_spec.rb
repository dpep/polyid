require 'spec_helper'

RSpec.describe PolyId::User do
  describe 'database' do
    it 'creates a user' do
      user = PolyId::User.create(name: 'John Doe', email: 'john@example.com')
      expect(user).to be_persisted
      expect(user.name).to eq('John Doe')
      expect(user.email).to eq('john@example.com')
    end

    it 'retrieves a user' do
      PolyId::User.create(name: 'Jane Doe', email: 'jane@example.com')
      user = PolyId::User.find_by(name: 'Jane Doe')
      expect(user).not_to be_nil
      expect(user.email).to eq('jane@example.com')
    end

    it 'updates a user' do
      user = PolyId::User.create(name: 'Bob Smith', email: 'bob@example.com')
      user.update(email: 'bob.smith@example.com')
      expect(user.reload.email).to eq('bob.smith@example.com')
    end

    it 'deletes a user' do
      user = PolyId::User.create(name: 'Alice Jones', email: 'alice@example.com')
      user.destroy
      expect(PolyId::User.find_by(id: user.id)).to be_nil
    end
  end
end
