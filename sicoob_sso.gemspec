# frozen_string_literal: true

require_relative "lib/sicoob_sso/version"

Gem::Specification.new do |spec|
  spec.name = "sicoob_sso"
  spec.version = SicoobSso::VERSION
  spec.authors = ["Fernando Menolli"]
  spec.email = ["femenolli@gmail.com"]

  spec.summary = "In-house SSO client (authenticate against the Tools IdP)"
  spec.description = "Reusable client side of Sicoob's in-house SSO. Provides the identity " \
                     "provider client, a controller authentication concern, and a sessions " \
                     "controller concern to authenticate host apps against the Tools IdP."
  spec.homepage = "https://github.com/sicoobmetropolitano/sicoob_sso"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib", "app/controllers"]

  spec.add_dependency "railties", ">= 7.0"
end
