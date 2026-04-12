require "rake"

RSpec.describe "polyid:backfill" do
  let(:task_name) { "polyid:backfill" }
  let(:task_path) { File.expand_path("../../lib/tasks/polyid.rake", __dir__) }
  let(:task) { Rake::Task[task_name] }

  def raw_account_uuid(account)
    Account.connection.select_value(Account.where(id: account.id).select(:uuid).to_sql)
  end

  def raw_widget_uuid(widget)
    Widget.connection.select_value(Widget.where(id: widget.id).select(:public_id).to_sql)
  end

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

  it "backfills missing binary uuids for a model" do
    existing_uuid = SecureRandom.uuid
    missing_account = Account.create!(name: "Missing UUID")
    existing_account = Account.create!(name: "Existing UUID", uuid: existing_uuid)

    task.invoke("Account")

    expect(missing_account.reload.uuid).to be_a_uuid
    expect(raw_account_uuid(missing_account).bytesize).to eq(16)
    expect(existing_account.reload.uuid).to eq existing_uuid
    expect(raw_account_uuid(existing_account).bytesize).to eq(16)
  end

  it "preserves existing uuids while backfilling missing ones" do
    existing_uuid = SecureRandom.uuid
    missing_account = Account.create!(name: "Missing UUID")
    existing_account = Account.create!(name: "Existing UUID", uuid: existing_uuid)

    task.invoke("Account")

    expect(missing_account.reload.uuid).to be_a_uuid
    expect(raw_account_uuid(missing_account).bytesize).to eq(16)
    expect(existing_account.reload.uuid).to eq existing_uuid
    expect(raw_account_uuid(existing_account).bytesize).to eq(16)
  end

  it "backfills missing string uuids for a custom uuid attribute" do
    existing_uuid = SecureRandom.uuid
    missing_widget = Widget.create!(name: "Missing UUID", public_id: nil)
    existing_widget = Widget.create!(name: "Existing UUID", public_id: existing_uuid)

    task.invoke("Widget")

    expect(missing_widget.reload.public_id).to be_a_uuid
    expect(raw_widget_uuid(missing_widget)).to eq(missing_widget.public_id)
    expect(raw_widget_uuid(missing_widget).bytesize).to eq(36)
    expect(existing_widget.reload.public_id).to eq(existing_uuid)
    expect(raw_widget_uuid(existing_widget)).to eq(existing_uuid)
  end
end
