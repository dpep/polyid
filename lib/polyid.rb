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
    attr_writer :cache

    def cache
      @cache ||= ActiveSupport::Cache::MemoryStore.new
    end

    def is_uuid?(value)
      value.is_a?(String) && UUID_PATTERN.match?(value)
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include PolyId::Model
end
