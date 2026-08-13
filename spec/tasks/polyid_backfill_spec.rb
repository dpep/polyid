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

  # create! assigns a uuid, so a row that predates polyid has to be made by
  # clearing the column behind the callbacks
  def strip_uuid(record, attribute = :uuid)
    record.update_columns(attribute => nil)
    record.reload
  end

  it "backfills a row with no uuid" do
    account = strip_uuid(Account.create!(name: "Legacy"))
    expect(account.uuid).to be_nil

    task.invoke("Account")

    expect(account.reload.uuid).to be_a_uuid
    expect(raw_account_uuid(account).bytesize).to eq(16)
  end

  it "leaves existing uuids alone" do
    account = Account.create!(name: "Existing")
    original_uuid = account.uuid
    strip_uuid(Account.create!(name: "Legacy"))

    task.invoke("Account")

    expect(account.reload.uuid).to eq original_uuid
  end

  it "backfills a custom uuid attribute" do
    widget = strip_uuid(Widget.create!(name: "Legacy"), :public_id)
    expect(widget.public_id).to be_nil

    task.invoke("Widget")

    expect(widget.reload.public_id).to be_a_uuid
    expect(raw_widget_uuid(widget)).to eq(widget.public_id)
  end

  it "accepts a batch size" do
    3.times { |i| strip_uuid(Account.create!(name: "Legacy #{i}")) }

    task.invoke("Account", "uuid", "2")

    expect(Account.where(uuid: nil)).to be_empty
  end

  it "raises for a model without polyid" do
    expect {
      task.invoke("LegacyUser")
    }.to raise_error(ArgumentError, /not configured with polyid/)
  end
end
