if defined?(Rails::Railtie)
  module PolyId
    class Railtie < Rails::Railtie
      rake_tasks do
        load File.expand_path("../tasks/polyid.rake", __dir__)
      end
    end
  end
end
