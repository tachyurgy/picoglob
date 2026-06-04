# frozen_string_literal: true

require_relative "picoglob/version"
require_relative "picoglob/compiler"

# Picoglob compiles bash-style glob patterns into Ruby Regexps so you can match
# *arbitrary strings* — S3 keys, routes, log lines, branch names — not just
# files on disk.
#
# It's the missing Ruby counterpart to JS's picomatch / minimatch. Ruby ships
# `File.fnmatch` and `Dir.glob`, but neither gives you a reusable `Regexp`, and
# `File.fnmatch` has limited brace/extglob support that's awkward to use off the
# filesystem.
#
# @example One-shot match
#   Picoglob.match?("src/**/*.{rb,erb}", "src/app/models/user.rb") # => true
#
# @example Compile once, match many (fast)
#   g = Picoglob.new("logs/*.log")
#   g.match?("logs/app.log")   # => true
#   g.match?("logs/2026/x.log") # => false (single * doesn't cross "/")
#
# @example Filter a list
#   Picoglob.filter("**/*.rb", ["a.rb", "lib/b.rb", "c.txt"]) # => ["a.rb", "lib/b.rb"]
#
# @example Extglob
#   Picoglob.match?("image.+(jpg|png)", "image.png") # => true
module Picoglob
  # Build a reusable matcher.
  #
  # @param pattern [String] the glob pattern
  # @param separator [String] path separator that `*`/`?` won't cross (default "/")
  # @param dot [Boolean] match leading dots with wildcards (default false, shell-like)
  # @param extglob [Boolean] enable extglob syntax (default true)
  # @param nocase [Boolean] case-insensitive (default false)
  # @return [Picoglob::Matcher]
  def self.new(pattern, **opts)
    Matcher.new(pattern, **opts)
  end

  # Convenience: does +string+ match +pattern+?
  # @return [Boolean]
  def self.match?(pattern, string, **opts)
    Matcher.new(pattern, **opts).match?(string)
  end

  # Convenience: compile +pattern+ to a Regexp.
  # @return [Regexp]
  def self.to_regexp(pattern, **opts)
    Matcher.new(pattern, **opts).to_regexp
  end

  # Convenience: keep only the strings that match +pattern+.
  # @return [Array<String>]
  def self.filter(pattern, strings, **opts)
    Matcher.new(pattern, **opts).filter(strings)
  end

  # A compiled glob. Compile once, match many times.
  class Matcher
    # @return [String] the original glob pattern
    attr_reader :pattern
    # @return [Regexp] the compiled regular expression
    attr_reader :regexp

    def initialize(pattern, separator: "/", dot: false, extglob: true, nocase: false)
      @pattern = pattern
      @regexp = Compiler.new(
        separator: separator, dot: dot, extglob: extglob, nocase: nocase
      ).compile(pattern)
    end

    # @param string [String]
    # @return [Boolean]
    def match?(string)
      @regexp.match?(string)
    end
    alias === match?

    # @return [Regexp]
    def to_regexp
      @regexp
    end

    # @param strings [Enumerable<String>]
    # @return [Array<String>]
    def filter(strings)
      strings.select { |s| @regexp.match?(s) }
    end
  end
end
