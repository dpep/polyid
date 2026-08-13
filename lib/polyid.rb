require "active_support"
require "active_support/cache"
require "active_support/concern"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/class/attribute"
require "active_support/core_ext/numeric/time"
require "active_support/core_ext/string/inflections"
require "active_support/lazy_load_hooks"
require "securerandom"
require "active_model/type"
require "polyid/binary_uuid_type"
require "polyid/cache"
require "polyid/model"
require "polyid/relation"
require "polyid/version"

module PolyId
  UUID_PATTERN = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/i
  DEFAULT_CACHE_TTL = 30.days

  class ConfigurationError < StandardError; end

  class << self
    # read afresh on every use, so they stay settable
    attr_writer :cache, :cache_ttl, :uuid_generator

    # memoised into each model, so a late change would silently do nothing
    def auto_detect=(value)
      configurable!
      @auto_detect = value
    end

    def default_uuid_attribute=(value)
      configurable!
      @default_uuid_attribute = value
    end

    def config_resolved?
      !!@config_resolved
    end

    def config_resolved!
      @config_resolved = true
    end

    def cache
      @cache ||= ActiveSupport::Cache::MemoryStore.new
    end

    # nil disables expiry.  note that redis `volatile-*` eviction policies only
    # ever evict keys that carry a ttl, so without one these entries are never
    # reclaimed -- and under `noeviction`, the default, a full instance starts
    # refusing writes rather than making room.
    def cache_ttl
      instance_variable_defined?(:@cache_ttl) ? @cache_ttl : DEFAULT_CACHE_TTL
    end

    def reset
      @cache&.clear if instance_variable_defined?(:@cache)

      remove_instance_variable(:@cache) if instance_variable_defined?(:@cache)
      remove_instance_variable(:@cache_ttl) if instance_variable_defined?(:@cache_ttl)
      remove_instance_variable(:@uuid_generator) if instance_variable_defined?(:@uuid_generator)
      remove_instance_variable(:@auto_detect) if instance_variable_defined?(:@auto_detect)
      remove_instance_variable(:@default_uuid_attribute) if instance_variable_defined?(:@default_uuid_attribute)
      remove_instance_variable(:@config_resolved) if instance_variable_defined?(:@config_resolved)

      PolyId::Model.reset_all!
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
        SecureRandom.uuid_v7
      when :v4, 4, "v4", "4"
        SecureRandom.uuid
      else
        raise ArgumentError, "unsupported uuid generator: #{generator.inspect}"
      end
    end

    def auto_detect?
      @auto_detect.nil? ? true : @auto_detect
    end

    def default_uuid_attribute
      @default_uuid_attribute ||= "uuid"
    end

    def configurable!
      return unless config_resolved?

      raise ConfigurationError,
        "polyid is already in use; configure it in an initializer, before models are loaded"
    end

    def is_uuid?(value)
      return false unless value.is_a?(String) && UUID_PATTERN.match?(value)

      version = value.getbyte(14).chr.to_i(16)
      variant = value.getbyte(19).chr.to_i(16)

      version.between?(1, 8) && variant.between?(8, 11)
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include PolyId::Model

  ActiveRecord::Relation.prepend(PolyId::Relation)
end

require "polyid/railtie" if defined?(Rails::Railtie)
