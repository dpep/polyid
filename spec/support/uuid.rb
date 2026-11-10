# ActiveRecord integer-casts a string id with `to_i`, so this becomes 123.  a
# miss only proves the uuid was translated when a decoy row sits at that id
UNRESOLVED_UUID = "123e4567-e89b-42d3-a456-426614174000".freeze

RSpec.shared_context "with a decoy row" do
  let!(:decoy) { create(:user, id: 123, account: create(:account, id: 123)) }
end
