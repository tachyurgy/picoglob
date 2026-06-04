# frozen_string_literal: true

module Picoglob
  # Raised when a glob pattern is malformed (e.g. an unbalanced brace or bracket).
  class ParseError < StandardError; end

  # Compiles a bash-style glob pattern into a Ruby Regexp source string.
  #
  # Supported syntax:
  #   *            any run of non-separator characters
  #   **           any run of characters, including separators (globstar)
  #   ?            any single non-separator character
  #   [abc] [a-z]  character class; [!...] or [^...] negates
  #   {a,b,c}      brace alternation (one of the comma-separated alternatives)
  #   {1..3}       numeric brace range expansion -> {1,2,3}
  #   @(a|b)       exactly one of the patterns (extglob)
  #   ?(a|b)       zero or one of the patterns (extglob)
  #   *(a|b)       zero or more of the patterns (extglob)
  #   +(a|b)       one or more of the patterns (extglob)
  #   !(a|b)       anything except the patterns (extglob)
  #   \x           escape the next character (literal)
  #
  # @api private
  class Compiler
    # @param separator [String] the path separator that `*`/`?` will not cross
    # @param dot [Boolean] when false, a leading `.` must be matched explicitly
    #   (a leading `*`/`?`/`[` will not match it), mirroring shell globbing
    # @param extglob [Boolean] enable extglob constructs (@/?/*/+/! followed by `(`)
    # @param nocase [Boolean] case-insensitive matching
    def initialize(separator: "/", dot: false, extglob: true, nocase: false)
      @sep = separator
      @dot = dot
      @extglob = extglob
      @nocase = nocase
    end

    # @param pattern [String]
    # @return [Regexp]
    def compile(pattern)
      @chars = pattern.chars
      @pos = 0
      body = parse_sequence(top_level: true)
      raise ParseError, "unexpected #{current.inspect}" unless eof?

      src = "\\A#{body}\\z"
      Regexp.new(src, @nocase ? Regexp::IGNORECASE : nil)
    end

    private

    def sep_re
      Regexp.escape(@sep)
    end

    # A single "non-separator" character class fragment, e.g. "[^/]".
    def not_sep
      "[^#{sep_re}]"
    end

    def current
      @chars[@pos]
    end

    def peek(n = 1)
      @chars[@pos + n]
    end

    def advance
      c = @chars[@pos]
      @pos += 1
      c
    end

    def eof?
      @pos >= @chars.length
    end

    # Parse a run of glob tokens until a terminator. When +stop+ is given
    # (a set of characters), parsing stops *before* consuming a terminator.
    def parse_sequence(stop: nil, top_level: false)
      out = +""
      until eof?
        c = current
        break if stop&.include?(c)

        out << parse_token(at_segment_start: out.empty? || just_after_sep?(out), top_level: top_level)
      end
      out
    end

    # Did the regex built so far end at a segment boundary? Used for the
    # leading-dot rule.
    def just_after_sep?(built)
      built.end_with?(sep_re)
    end

    def parse_token(at_segment_start:, top_level:)
      c = current

      # extglob: a prefix char immediately followed by '('
      if @extglob && "@?*+!".include?(c) && peek == "("
        return parse_extglob
      end

      case c
      when "\\"
        advance
        nxt = advance
        raise ParseError, "dangling escape" if nxt.nil?

        Regexp.escape(nxt)
      when "*"
        parse_star(at_segment_start: at_segment_start)
      when "?"
        advance
        # respect leading-dot rule at a segment start
        at_segment_start && !@dot ? "(?!\\.)#{not_sep}" : not_sep
      when "["
        parse_class
      when "{"
        parse_brace
      when "}", ")", "|", ","
        # Only meaningful inside the corresponding construct; at top level treat
        # as a literal so patterns like "a,b" or "100%}" don't explode.
        Regexp.escape(advance)
      else
        Regexp.escape(advance)
      end
    end

    def parse_star(at_segment_start:)
      advance # consume first '*'
      if current == "*"
        # globstar: consume all consecutive '*'
        advance while current == "*"
        parse_globstar(at_segment_start: at_segment_start)
      elsif at_segment_start && !@dot
        "(?:(?!\\.)#{not_sep}*)"
      else
        "#{not_sep}*"
      end
    end

    # Globstar (`**`) matches across separators. The special, shell-standard
    # form is `**/`, which matches zero or more *whole* path segments — so
    # `src/**/*.rb` also matches `src/foo.rb`. To make "zero segments" work we
    # swallow the trailing separator here and emit a group that can match
    # nothing.
    def parse_globstar(at_segment_start:)
      if at_segment_start && current == @sep
        advance # consume the '/' that follows '**'
        seg = @dot ? "#{not_sep}+" : "(?!\\.)#{not_sep}*"
        # zero or more "segment/" groups; matches the empty string too
        "(?:#{seg}#{sep_re})*"
      elsif at_segment_start && !@dot
        "(?:(?!\\.).)*"
      else
        ".*"
      end
    end

    def parse_class
      advance # '['
      negate = false
      if current == "!" || current == "^"
        negate = true
        advance
      end
      body = +""
      # A ']' immediately after the (optional) negation is a literal ']'.
      if current == "]"
        body << "\\]"
        advance
      end
      until eof? || current == "]"
        ch = advance
        body << if ch == "\\"
                  # explicit escape inside the class: take the next char literally
                  nxt = advance
                  raise ParseError, "dangling escape in character class" if nxt.nil?

                  escape_in_class(nxt)
                elsif ch == "-"
                  # keep '-' so ranges like 0-9 / a-z are preserved
                  "-"
                else
                  escape_in_class(ch)
                end
      end
      raise ParseError, "unterminated character class" if eof?

      advance # ']'
      "[#{negate ? '^' : ''}#{body}]"
    end

    # Escape a single character so it is a literal inside a Ruby regex
    # character class. Only ']', '\\' and '^' are special there (we treat '-'
    # specially in the caller so ranges survive).
    def escape_in_class(ch)
      case ch
      when "]", "\\", "^"
        "\\#{ch}"
      else
        ch
      end
    end

    # {a,b,c}  -> (?:a|b|c)
    # {1..5}   -> (?:1|2|3|4|5)
    def parse_brace
      advance # '{'
      # numeric range?
      if (range = try_numeric_range)
        return range
      end

      alts = []
      depth = 0
      current_alt = +""
      loop do
        raise ParseError, "unterminated brace" if eof?

        c = current
        if c == "}" && depth.zero?
          advance
          alts << current_alt
          break
        elsif c == "," && depth.zero?
          advance
          alts << current_alt
          current_alt = +""
        elsif c == "{"
          depth += 1
          current_alt << advance
        elsif c == "}"
          depth -= 1
          current_alt << advance
        else
          current_alt << advance
        end
      end

      # A brace with no comma (e.g. "{foo}") is treated literally by bash.
      if alts.length == 1
        return "\\{#{compile_fragment(alts.first)}\\}"
      end

      "(?:#{alts.map { |a| compile_fragment(a) }.join('|')})"
    end

    # Try to parse "{m..n}" starting just after '{'. Restores position on failure.
    def try_numeric_range
      start = @pos
      num1 = +""
      num1 << advance while current&.match?(/\d/)
      if current == "." && peek == "." && !num1.empty?
        advance
        advance
        num2 = +""
        num2 << advance while current&.match?(/\d/)
        if current == "}" && !num2.empty?
          advance
          lo = num1.to_i
          hi = num2.to_i
          range = lo <= hi ? (lo..hi) : (hi..lo).to_a.reverse
          return "(?:#{range.to_a.join('|')})"
        end
      end
      @pos = start
      nil
    end

    # extglob: PREFIX( pat | pat | ... )
    def parse_extglob
      prefix = advance # @ ? * + !
      advance # '('
      alts = []
      current_alt = +""
      depth = 0
      loop do
        raise ParseError, "unterminated extglob" if eof?

        c = current
        if c == ")" && depth.zero?
          advance
          alts << current_alt
          break
        elsif c == "|" && depth.zero?
          advance
          alts << current_alt
          current_alt = +""
        elsif c == "("
          depth += 1
          current_alt << advance
        elsif c == ")"
          depth -= 1
          current_alt << advance
        else
          current_alt << advance
        end
      end

      inner = "(?:#{alts.map { |a| compile_fragment(a) }.join('|')})"
      case prefix
      when "@" then inner
      when "?" then "#{inner}?"
      when "*" then "#{inner}*"
      when "+" then "#{inner}+"
      when "!" then "(?:(?!#{inner}#{sep_re}*$)#{not_sep}*)"
      end
    end

    # Compile a nested fragment (alternative body, extglob branch) using the
    # same options. We don't apply the leading-dot rule inside fragments.
    def compile_fragment(str)
      sub = Compiler.new(separator: @sep, dot: true, extglob: @extglob, nocase: @nocase)
      sub.compile_body(str)
    end

    protected

    # Compile +str+ to a regex body string (no anchors). Used for nested
    # fragments so we get full recursive glob support inside {} and extglobs.
    def compile_body(str)
      @chars = str.chars
      @pos = 0
      body = parse_sequence
      raise ParseError, "unexpected #{current.inspect}" unless eof?

      body
    end
  end
end
