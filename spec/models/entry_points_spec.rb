RSpec.describe "uuid entry points" do
  include_context "with a decoy row"

  # the decoy's account, so an association that integer-casts can reach the decoy
  let(:account) { decoy.account }
  let!(:user) { create(:user, account:) }

  def removed_user
    before = User.all.to_a
    yield
    (before - User.all.to_a).first
  end

  # each looks its target up by uuid: nil or RecordNotFound is a miss
  {
    "where" => [:user, ->(uuid) { User.where(id: uuid).first }],
    "where.not" => [:user, ->(uuid) { (User.all.to_a - User.where.not(id: uuid).to_a).first }],
    "find_by" => [:user, ->(uuid) { User.find_by(id: uuid) }],
    "find" => [:user, ->(uuid) { User.find(uuid) }],
    "Relation#find" => [:user, ->(uuid) { User.all.find(uuid) }],
    "find on a loaded inverse_of association" => [:user, ->(uuid) { account.users.load.find(uuid) }],
    "exists?" => [:user, ->(uuid) { user if User.exists?(uuid) }],
    "delete" => [:user, ->(uuid) { removed_user { User.delete(uuid) } }],
    "destroy_by" => [:user, ->(uuid) { removed_user { User.destroy_by(id: uuid) } }],
    "user_ids=" => [:user, ->(uuid) { account.tap { |a| a.user_ids = [uuid] }.reload.users.sole }],
    "find_or_create_by!" => [:user, ->(uuid) { User.find_or_create_by!(id: uuid) }],
    "create_or_find_by!" => [:user, ->(uuid) { User.create_or_find_by!(id: uuid) }],
    "find_or_initialize_by" => [:user, ->(uuid) { User.find_or_initialize_by(id: uuid) }],
    "a table-qualified key" => [:user, ->(uuid) { User.where("users.id" => uuid).first }],
    "a foreign key" => [:account, ->(uuid) { User.where(account_id: uuid).first&.account }],
    "an association name" => [:account, ->(uuid) { User.where(account: uuid).first&.account }],
    "find_or_create_by!(account_id:)" => [:account, ->(uuid) { User.find_or_create_by!(account_id: uuid).account }],
    "find_or_initialize_by(account:)" => [:account, ->(uuid) { User.find_or_initialize_by(account: uuid).account }],
    "a nested join condition" => [:account, ->(uuid) { User.joins(:account).find_by(accounts: { id: uuid })&.account }],
    "a qualified join key" => [:account, ->(uuid) { User.joins(:account).find_by("accounts.id" => uuid)&.account }],
  }.each do |entry_point, (target, lookup)|
    describe entry_point do
      let(:record) { public_send(target) }

      it "resolves an uppercase uuid" do
        expect(instance_exec(record.uuid.upcase, &lookup)).to eq(record)
      end

      it "resolves a whitespace-padded uuid" do
        expect(instance_exec(" #{record.uuid}\n", &lookup)).to eq(record)
      end

      it "misses a uuid that resolves to nothing, rather than the decoy" do
        found = begin
          instance_exec(UNRESOLVED_UUID, &lookup)
        rescue ActiveRecord::RecordNotFound
          nil
        end

        expect(found).to be_nil
      end
    end
  end
end
