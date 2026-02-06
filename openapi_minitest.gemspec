# frozen_string_literal: true

require_relative "lib/openapi_minitest/version"

Gem::Specification.new do |spec|
  spec.name = "openapi_minitest"
  spec.version = OpenapiMinitest::VERSION
  spec.authors = ["Alex Koval"]
  spec.email = ["al3xander.koval@gmail.com"]

  spec.summary = "Generate OpenAPI documentation from Minitest integration tests"
  spec.description = "A Ruby gem that generates OpenAPI 3.0 documentation from Minitest integration tests in Rails applications. Uses serializers as the single source of truth for response schemas."
  spec.homepage = "https://github.com/k0va1/openapi_minitest"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/k0va1/openapi_minitest/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "json-schema", "~> 4.0"
  spec.add_dependency "rack", ">= 2.0"
  spec.add_dependency "bigdecimal"
end
