module ActiveSupport
  module Cache
    class MemoryStore
      def empty?
        instance_variable_get(:@data).empty?
      end
    end
  end
end
