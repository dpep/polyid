require "rake"

RSpec.describe "polyid:backfill" do
  let(:task_name) { "polyid:backfill" }
  let(:task) { Rake::Task[task_name] }

  # load once: reloading a file resets its line coverage
  before(:all) do
    @original_application = Rake.application
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load File.expand_path("../../lib/tasks/polyid.rake", __dir__)
  end

  after(:all) { Rake.application = @original_application }

  before { task.reenable }

  it "backfills a row with no uuid" do
    account = create(:account, :awaiting_uuid)
    expect(account.uuid).to be_nil

    task.invoke("Account")

    expect(account.reload.uuid).to be_a_uuid
    expect(raw_value(account, :uuid).bytesize).to eq(16)
  end

  it "leaves existing uuids alone" do
    account = create(:account)
    original_uuid = account.uuid
    create(:account, :awaiting_uuid)

    task.invoke("Account")

    expect(account.reload.uuid).to eq original_uuid
  end

  it "backfills a custom uuid attribute" do
    widget = create(:widget, :awaiting_uuid)
    expect(widget.public_id).to be_nil

    task.invoke("Widget")

    expect(widget.reload.public_id).to be_a_uuid
    expect(raw_value(widget, :public_id)).to eq(widget.public_id)
  end

  it "accepts a batch size" do
    3.times { create(:account, :awaiting_uuid) }

    task.invoke("Account", "2")

    expect(Account.where(uuid: nil)).to be_empty
  end

  it "reads a batch size with a leading zero as decimal" do
    create(:account, :awaiting_uuid)

    expect { task.invoke("Account", "08") }.not_to raise_error
    expect(Account.where(uuid: nil)).to be_empty
  end

  it "rejects a batch size that isn't a positive integer" do
    expect { task.invoke("Account", "abc") }.to raise_error(ArgumentError, /batch_size/)
    task.reenable
    expect { task.invoke("Account", "0") }.to raise_error(ArgumentError, /batch_size/)
  end

  it "refuses to write an invalid generated uuid" do
    create(:account, :awaiting_uuid)
    allow(Account).to receive(:polyid_generate_uuid).and_return("nope")

    expect {
      task.invoke("Account")
    }.to raise_error(ArgumentError, /invalid uuid/)
  end

  it "raises for a model without polyid" do
    expect {
      task.invoke("LegacyUser")
    }.to raise_error(ArgumentError, /not configured with polyid/)
  end
end
