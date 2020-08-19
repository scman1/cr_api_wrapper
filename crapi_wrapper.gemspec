# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "cr_api_wrapper/version"

Gem::Specification.new do |spec|
  spec.name          = "crossref_api_wrapper"
  spec.version       = CrApiWrapper::VERSION
  spec.authors       = ["Abraham Nieva de la Hidalga"]
  spec.email         = ["a_nieva@hotmail.com"]

  spec.summary       = %q{ruby wrapper for the cross ref serrano api }
  spec.description   = %q{A Ruby gem that enables fetching and formating crossref publications data}
  spec.homepage      = "https://github.com/scman1"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "webmock"

  spec.add_development_dependency 'faraday', '~> 0.17.1'

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 10.0"
end
