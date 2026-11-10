module PermittedParams
  # stands in for ActionController::Parameters
  def permitted_params(hash)
    Class.new do
      def initialize(hash) = @hash = hash
      def permitted? = true
      def to_h = @hash
    end.new(hash)
  end
end

RSpec.configure do |config|
  config.include PermittedParams
end
