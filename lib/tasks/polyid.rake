namespace :polyid do
  desc "Backfill NULL polyid UUIDs for a model: rake polyid:backfill[ModelName,batch_size]"
  task :backfill, [:model_name, :batch_size] => :environment do |_task, args|
    model_name = args[:model_name] or raise ArgumentError, "model_name is required"
    model = model_name.constantize
    raise ArgumentError, "#{model_name} is not configured with polyid" unless model.polyid?

    uuid_attribute = model.polyid_uuid_attribute
    # base 10, so a leading zero isn't read as octal
    batch_size = args[:batch_size] ? Integer(args[:batch_size], 10, exception: false) : 1_000
    raise ArgumentError, "batch_size must be a positive integer" unless batch_size&.positive?
    pk = model.primary_key

    model.unscoped.where(uuid_attribute => nil).in_batches(of: batch_size).each_record do |record|
      uuid = model.polyid_generate_uuid
      raise ArgumentError, "#{model_name} generated an invalid uuid: #{uuid.inspect}" unless PolyId.uuid?(uuid)

      # guarded, so a uuid the app assigned since the batch loaded is kept
      model.unscoped.where(pk => record.id, uuid_attribute => nil).update_all(uuid_attribute => uuid)
    end
  end
end
