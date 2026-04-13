RSpec.describe 'auto-detection' do
  def reset_polyid_auto_detection_state(model)
    model.remove_instance_variable(:@polyid_resolved_uuid_attribute) if model.instance_variable_defined?(:@polyid_resolved_uuid_attribute)
  end

  around do |example|
    previous_auto_detect = PolyId.auto_detect?
    previous_uuid_attribute = PolyId.default_uuid_attribute

    PolyId.auto_detect = true
    PolyId.default_uuid_attribute = :uuid
    reset_polyid_auto_detection_state(User)
    reset_polyid_auto_detection_state(LegacyUser)

    example.run
  ensure
    PolyId.auto_detect = previous_auto_detect
    PolyId.default_uuid_attribute = previous_uuid_attribute
    reset_polyid_auto_detection_state(User)
    reset_polyid_auto_detection_state(LegacyUser)
  end

  it 'automatically enables polyid behavior for models with id and uuid columns' do
    user = create(:user)

    expect(User.polyid?).to be(true)
    expect(User.find(user.uuid)).to eq(user)
    expect(User.id_for(user.uuid)).to eq(user.id)
    expect(User.uuid_for(user.id)).to eq(user.uuid)
  end

  it 'does not auto-enable models missing a uuid column' do
    user = LegacyUser.create!(name: 'Legacy')

    expect(LegacyUser.polyid?).to be(false)
    expect(LegacyUser.find(user.id)).to eq(user)
    expect { LegacyUser.find(SecureRandom.uuid) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'can disable auto-detection globally' do
    PolyId.auto_detect = false
    user = User.create!(name: 'User', uuid: SecureRandom.uuid)

    expect(User.polyid?).to be(false)
    expect { User.find(user.uuid) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
