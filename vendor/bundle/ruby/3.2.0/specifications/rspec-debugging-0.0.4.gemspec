# -*- encoding: utf-8 -*-
# stub: rspec-debugging 0.0.4 ruby lib

Gem::Specification.new do |s|
  s.name = "rspec-debugging".freeze
  s.version = "0.0.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Daniel Pepper".freeze]
  s.date = "2025-02-07"
  s.description = "Tools to improve debugging in RSpec".freeze
  s.homepage = "https://github.com/dpep/rspec-debugging".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.1".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Tools to improve debugging in RSpec".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<rspec-expectations>.freeze, [">= 3"])
  s.add_development_dependency(%q<debug>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 0"])
  s.add_development_dependency(%q<simplecov>.freeze, [">= 0"])
end
