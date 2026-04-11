module ActiveSupport
  module Cache
    class Store
      def empty?
        instance_variable_get(:@data).empty?
      end
    end
  end
end
