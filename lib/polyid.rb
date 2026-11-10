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
require "polyid/collection_association"
require "polyid/integer_guard"
require "polyid/model"
require "polyid/relation"
require "polyid/version"

module PolyId
  UUID_PATTERN = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/i
  DEFAULT_CACHE_TTL = 30.days
  V7_GENERATORS = [:v7, 7, "v7", "7"].freeze
  V4_GENERATORS = [:v4, 4, "v4", "4"].freeze
  CONFIG_IVARS = %i[@cache @cache_ttl @uuid_generator @auto_detect @default_uuid_attribute @config_resolved].freeze

  class ConfigurationError < StandardError; end

  class << self
    # read afresh on every use, so they stay settable
    attr_writer :cache, :cache_ttl

    def uuid_generator=(generator)
      validate_uuid_generator!(generator)
      @uuid_generator = generator
    end

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

    # nil disables expiry.  redis volatile-* policies only evict keys with a ttl
    def cache_ttl
      instance_variable_defined?(:@cache_ttl) ? @cache_ttl : DEFAULT_CACHE_TTL
    end

    def reset # :nodoc:
      # drop the store rather than clear it: it may be shared, eg. Rails.cache
      CONFIG_IVARS.each do |ivar|
        remove_instance_variable(ivar) if instance_variable_defined?(ivar)
      end

      PolyId::Model.reset_all!
    end

    def uuid_generator
      @uuid_generator ||= :v7
    end

    def generate_uuid(generator = nil) # :nodoc:
      generator ||= uuid_generator
      validate_uuid_generator!(generator)

      case generator
      when Proc then generator.call
      when *V7_GENERATORS then SecureRandom.uuid_v7
      when *V4_GENERATORS then SecureRandom.uuid
      end
    end

    # a Proc can only be checked when it's called
    def validate_uuid_generator!(generator) # :nodoc:
      return if generator.nil? || generator.is_a?(Proc)
      return if V7_GENERATORS.include?(generator) || V4_GENERATORS.include?(generator)

      raise ArgumentError, "unsupported uuid generator: #{generator.inspect}"
    end

    def auto_detect?
      @auto_detect.nil? || @auto_detect
    end

    def default_uuid_attribute
      @default_uuid_attribute ||= "uuid"
    end

    def configurable!
      return unless config_resolved?

      raise ConfigurationError,
        "polyid is already in use; configure it in an initializer, before models are loaded"
    end

    # lenient, for input: the uuid a caller meant, judged by shape alone, since a
    # non-RFC uuid passed through as an id would be integer-cast ("8f47..." => 8)
    def normalize_uuid(value)
      # strip raises on invalid bytes, eg. from an import
      return unless value.is_a?(String) && value.valid_encoding?

      uuid = value.strip.downcase
      uuid if UUID_PATTERN.match?(uuid)
    end

    # strict, for what is stored
    def uuid?(value)
      return false unless value.is_a?(String) && value.valid_encoding? && UUID_PATTERN.match?(value)

      version = value.getbyte(14).chr.to_i(16)
      variant = value.getbyte(19).chr.to_i(16)

      version.between?(1, 8) && variant.between?(8, 11)
    end
    alias is_uuid? uuid?
  end
end

ActiveSupport.on_load(:active_record) do
  include PolyId::Model

  ActiveRecord::Relation.prepend(PolyId::Relation)
  ActiveRecord::Associations::CollectionAssociation.prepend(PolyId::CollectionAssociation)
end

require "polyid/railtie" if defined?(Rails::Railtie)
