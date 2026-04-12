require "rake"

RSpec.describe "polyid:backfill" do
  let(:task_name) { "polyid:backfill" }
  let(:task_path) { File.expand_path("../../lib/tasks/polyid.rake", __dir__) }
  let(:task) { Rake::Task[task_name] }

  before do
    task.reenable
  end

  around do |example|
    original_application = Rake.application
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load task_path

    example.run
  ensure
    Rake.application = original_application
  end

  it "backfills missing uuids for a model" do
    missing_account = Account.create!(name: "Missing UUID")
    existing_account = Account.create!(name: "Existing UUID", uuid: SecureRandom.uuid)

    task.invoke("Account")

    expect(missing_account.reload.uuid).to be_present
    expect(PolyId.is_uuid?(missing_account.uuid)).to be true
    expect(existing_account.reload.uuid).to be_present
  end

  it "preserves existing uuids while backfilling missing ones" do
    existing_uuid = SecureRandom.uuid
    missing_account = Account.create!(name: "Missing UUID")
    existing_account = Account.create!(name: "Existing UUID", uuid: existing_uuid)

    task.invoke("Account", "uuid", "1")

    expect(missing_account.reload.uuid).to be_present
    expect(existing_account.reload.uuid).to eq(existing_uuid)
  end
end
