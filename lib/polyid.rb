require "active_support"
require "active_support/cache"
require "active_support/concern"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/class/attribute"
require "active_support/lazy_load_hooks"
require "polyid/cache"
require "polyid/model"
require "polyid/version"

module PolyId
  UUID_PATTERN = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/i

  class << self
    attr_writer :cache, :cache_binary_uuids

    def cache
      @cache ||= ActiveSupport::Cache::MemoryStore.new
    end

    def reset
      @cache&.clear if instance_variable_defined?(:@cache)

      remove_instance_variable(:@cache) if instance_variable_defined?(:@cache)
      remove_instance_variable(:@cache_binary_uuids) if instance_variable_defined?(:@cache_binary_uuids)
    end

    def cache_binary_uuids?
      unless instance_variable_defined?(:@cache_binary_uuids)
        @cache_binary_uuids = !!(defined?(Rails) && Rails.respond_to?(:env) && Rails.env.production?)
      end
      
      @cache_binary_uuids
    end

    def is_uuid?(value)
      value.is_a?(String) && UUID_PATTERN.match?(value)
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include PolyId::Model
end
