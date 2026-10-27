namespace :polyid do
  desc "Backfill NULL polyid UUIDs for a model: rake polyid:backfill[ModelName,uuid_attribute,batch_size]"
  task :backfill, [:model_name, :uuid_attribute, :batch_size] => :environment do |_task, args|
    model_name = args[:model_name] or raise ArgumentError, "model_name is required"
    model = model_name.constantize
    raise ArgumentError, "#{model_name} is not configured with polyid" unless model.polyid?

    uuid_attribute = (args[:uuid_attribute] || model.polyid_uuid_attribute).to_s
    batch_size = (args[:batch_size] || 1_000).to_i
    pk = model.primary_key

    model.unscoped.where(uuid_attribute => nil).in_batches(of: batch_size).each_record do |record|
      uuid = model.polyid_generate_uuid
      raise ArgumentError, "#{model_name} generated an invalid uuid: #{uuid.inspect}" unless PolyId.uuid?(uuid)

      # guarded, so a uuid the app assigned since the batch loaded is kept
      model.unscoped.where(pk => record.id, uuid_attribute => nil).update_all(uuid_attribute => uuid)
    end
  end
end
