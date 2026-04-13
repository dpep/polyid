RSpec.describe 'auto-detection' do
  around do |example|
    previous_auto_detect = PolyId.auto_detect_models
    previous_uuid_attribute = PolyId.default_uuid_attribute

    PolyId.auto_detect_models = true
    PolyId.default_uuid_attribute = :uuid

    example.run
  ensure
    PolyId.auto_detect_models = previous_auto_detect
    PolyId.default_uuid_attribute = previous_uuid_attribute
  end

  it 'automatically enables polyid behavior for models with id and uuid columns' do
    user = create(:auto_user)

    expect(AutoUser.polyid?).to be(true)
    expect(AutoUser.find(user.uuid)).to eq(user)
    expect(AutoUser.id_for(user.uuid)).to eq(user.id)
    expect(AutoUser.uuid_for(user.id)).to eq(user.uuid)
  end

  it 'does not auto-enable models missing a uuid column' do
    user = LegacyUser.create!(name: 'Legacy')

    expect(LegacyUser.polyid?).to be(false)
    expect(LegacyUser.find(user.id)).to eq(user)
    expect { LegacyUser.find(SecureRandom.uuid) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'can disable auto-detection globally' do
    PolyId.auto_detect_models = false
    user = create(:auto_user)

    expect(AutoUser.polyid?).to be(false)
    expect { AutoUser.find(user.uuid) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
