RSpec.describe 'auto-detection' do
  def reset_polyid_auto_detection_state(model)
    model.remove_instance_variable(:@polyid_uuid_attribute) if model.instance_variable_defined?(:@polyid_uuid_attribute)
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
    expect { LegacyUser.find(UNKNOWN_UUID) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'raises when translating on a model without polyid' do
    LegacyUser.create!(name: 'Legacy')

    expect { LegacyUser.id_for(UNKNOWN_UUID) }.to raise_error(/not configured with polyid/)
    expect { LegacyUser.uuid_for(1) }.to raise_error(/not configured with polyid/)
    expect { LegacyUser.ids_for([UNKNOWN_UUID]) }.to raise_error(/not configured with polyid/)
    expect { LegacyUser.uuids_for([1]) }.to raise_error(/not configured with polyid/)
  end

  it 'can disable auto-detection globally' do
    PolyId.auto_detect = false
    user = User.create!(name: 'User', uuid: UNKNOWN_UUID)

    expect(User.polyid?).to be(false)
    expect { User.find(user.uuid) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
