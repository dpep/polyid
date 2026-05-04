RSpec.describe Membership do
  describe '.find' do
    it 'finds a record by its optional third id attribute' do
      membership = create(:membership)

      expect(described_class.find(membership.external_id)).to eq(membership)
    end

    it 'supports mixed id, uuid, and third id lookups' do
      first = create(:membership)
      second = create(:membership)
      third = create(:membership)

      expect(described_class.find(first.id, second.uuid, third.external_id)).to contain_exactly(first, second, third)
    end
  end

  describe '.ids_for' do
    it 'resolves third id values into primary keys while preserving order' do
      first = create(:membership)
      second = create(:membership)

      expect(described_class.ids_for([first.external_id, second.uuid, second.id, 'missing', nil]))
        .to eq([first.id, second.id, second.id, 'missing', nil])
    end
  end
end
