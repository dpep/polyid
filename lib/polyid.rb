require "active_support"
require "active_support/cache"
require "active_support/concern"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/class/attribute"
require "active_support/lazy_load_hooks"
require "securerandom"
require "active_model/type"
require "polyid/binary_uuid_type"
require "polyid/cache"
require "polyid/model"
require "polyid/version"

module PolyId
  UUID_PATTERN = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/i

  class << self
    attr_writer :cache, :cache_binary_uuids, :uuid_generator

    def cache
      @cache ||= ActiveSupport::Cache::MemoryStore.new
    end

    def reset
      @cache&.clear if instance_variable_defined?(:@cache)

      remove_instance_variable(:@cache) if instance_variable_defined?(:@cache)
      remove_instance_variable(:@cache_binary_uuids) if instance_variable_defined?(:@cache_binary_uuids)
      remove_instance_variable(:@uuid_generator) if instance_variable_defined?(:@uuid_generator)
    end

    def cache_binary_uuids?
      unless instance_variable_defined?(:@cache_binary_uuids)
        @cache_binary_uuids = !!(defined?(Rails) && Rails.respond_to?(:env) && Rails.env.production?)
      end

      @cache_binary_uuids
    end

    def uuid_generator
      @uuid_generator ||= SecureRandom.respond_to?(:uuid_v7) ? :v7 : :v4
    end

    def generate_uuid(generator = nil)
      generator ||= uuid_generator

      case generator
      when Proc
        generator.call
      when :v7, 7, "v7", "7"
        SecureRandom.respond_to?(:uuid_v7) ? SecureRandom.uuid_v7 : SecureRandom.uuid
      when :v4, 4, "v4", "4"
        SecureRandom.uuid
      else
        raise ArgumentError, "unsupported uuid generator: #{generator.inspect}"
      end
    end

    def is_uuid?(value)
      value.is_a?(String) && UUID_PATTERN.match?(value)
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include PolyId::Model
end

require "polyid/railtie" if defined?(Rails::Railtie)
