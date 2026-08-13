RSpec.describe "single table inheritance" do
  let(:dog) { Dog.create! }

  before { PolyId.cache = ActiveSupport::Cache::MemoryStore.new }

  it "translates through the base class and the subclass alike" do
    expect(Dog.id_for(dog.uuid)).to eq(dog.id)
    expect(Animal.id_for(dog.uuid)).to eq(dog.id)
    expect(Animal.uuid_for(dog.id)).to eq(dog.uuid)
  end

  it "shares cached mappings across the hierarchy" do
    Dog.id_for(dog.uuid)

    # a subclass lookup must warm the base class too, not a parallel namespace
    expect(PolyId::Cache.read_multi(Animal.name, uuids: [dog.uuid])[:uuids]).to eq(dog.uuid => dog.id)
  end

  it "evicts across the hierarchy" do
    Animal.id_for(dog.uuid)
    dog.destroy!

    expect(PolyId::Cache.read_multi(Animal.name, ids: [dog.id], uuids: [dog.uuid])).to eq(
      ids: {},
      uuids: {},
    )
  end

  it "finds by uuid from either class" do
    expect(Animal.find(dog.uuid)).to eq(dog)
    expect(Dog.find(dog.uuid)).to eq(dog)
  end
end
