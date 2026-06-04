# frozen_string_literal: true

require_relative "lib/picoglob/version"

Gem::Specification.new do |spec|
  spec.name = "picoglob"
  spec.version = Picoglob::VERSION
  spec.authors = ["Levelbrook Team"]
  spec.email = ["levelbrookteam@gmail.com"]

  spec.summary = "Compile bash-style glob patterns into Ruby Regexps (picomatch for Ruby)."
  spec.description = <<~DESC.strip
    Picoglob turns bash-style glob patterns (*, **, ?, [...], {a,b}, {1..3}, and extglobs
    like @(a|b), +(a|b), !(a|b)) into reusable Ruby Regexps, so you can match arbitrary
    strings -- S3 keys, routes, log lines, branch names -- not just files on disk. It is
    the missing Ruby counterpart to JavaScript's picomatch / minimatch. Pure Ruby, no
    dependencies.
  DESC
  spec.homepage = "https://consulting.levelbrook.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/tachyurgy/picoglob"
  spec.metadata["changelog_uri"] = "https://github.com/tachyurgy/picoglob/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*.rb",
    "README.md",
    "CHANGELOG.md",
    "LICENSE"
  ]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
