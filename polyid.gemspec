Gem::Specification.new do |s|
  s.authors     = ["Daniel Pepper"]
  s.description = "..."
  s.files       = `git ls-files * ':!:spec'`.split("\n")
  s.homepage    = "https://github.com/dpep/polyid"
  s.license     = "MIT"
  s.name        = File.basename(__FILE__, ".gemspec")
  s.summary     = "PolyId"
  s.version     = "0.0.0"

  s.required_ruby_version = ">= 3.2"

  s.add_development_dependency 'activerecord', '>= 7'
  s.add_development_dependency 'debug', '>= 1'
  s.add_development_dependency 'factory_bot', '>= 6'
  s.add_development_dependency 'faker', '>= 3'
  s.add_development_dependency 'rspec', '>= 3.10'
  s.add_development_dependency 'rspec-debugging'
  s.add_development_dependency 'simplecov', '>= 0.22'
  s.add_development_dependency 'sqlite3', '>= 1.4'
end
