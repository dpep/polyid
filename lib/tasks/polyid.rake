namespace :polyid do
  desc "Backfill NULL polyid UUIDs for a model: rake polyid:backfill[ModelName,uuid_attribute,batch_size]"
  task :backfill, [:model_name, :uuid_attribute, :batch_size] => :environment do |_task, args|
    model_name = args[:model_name] or raise ArgumentError, "model_name is required"
    model = model_name.constantize
    uuid_attribute = (args[:uuid_attribute] || model.send(:polyid_uuid_attribute) || :uuid).to_s
    batch_size = (args[:batch_size] || 1_000).to_i

    raise ArgumentError, "#{model_name} is not configured with polyid" unless model.respond_to?(:polyid?) && model.polyid?

    model.unscoped.where(uuid_attribute => nil).in_batches(of: batch_size) do |records|
      records.each do |record|
        serialized_uuid = model.send(:polyid_uuid_type).serialize(model.send(:polyid_generate_uuid)).to_s

        record.update_columns(uuid_attribute => serialized_uuid)
      end
    end
  end
end
