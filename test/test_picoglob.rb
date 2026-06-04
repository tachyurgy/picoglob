# frozen_string_literal: true

require "minitest/autorun"
require "picoglob"

class TestPicoglob < Minitest::Test
  def assert_match_glob(pattern, string, **opts)
    assert Picoglob.match?(pattern, string, **opts),
           "expected #{pattern.inspect} to match #{string.inspect}"
  end

  def refute_match_glob(pattern, string, **opts)
    refute Picoglob.match?(pattern, string, **opts),
           "expected #{pattern.inspect} NOT to match #{string.inspect}"
  end

  # --- literals -----------------------------------------------------------

  def test_literal_exact
    assert_match_glob "foo.rb", "foo.rb"
    refute_match_glob "foo.rb", "foo.rbx"
    refute_match_glob "foo.rb", "xfoo.rb"
  end

  def test_dot_is_literal
    assert_match_glob "a.b", "a.b"
    refute_match_glob "a.b", "axb"
  end

  def test_regex_metachars_are_literal
    assert_match_glob "a+b(c)", "a+b(c)"
    assert_match_glob "1.5$", "1.5$"
    refute_match_glob "a+b(c)", "aaab(c)"
  end

  # --- single star --------------------------------------------------------

  def test_star_matches_within_segment
    assert_match_glob "*.rb", "foo.rb"
    assert_match_glob "src/*.rb", "src/foo.rb"
    assert_match_glob "*", "anything"
  end

  def test_star_does_not_cross_separator
    refute_match_glob "*.rb", "src/foo.rb"
    refute_match_glob "src/*", "src/a/b"
  end

  def test_star_matches_empty
    assert_match_glob "a*b", "ab"
    assert_match_glob "a*b", "axxxb"
  end

  # --- question mark ------------------------------------------------------

  def test_question_matches_single_char
    assert_match_glob "?.rb", "a.rb"
    refute_match_glob "?.rb", "ab.rb"
    refute_match_glob "?.rb", ".rb"  # ? requires exactly one char
  end

  def test_question_does_not_cross_separator
    refute_match_glob "a?b", "a/b"
  end

  # --- globstar -----------------------------------------------------------

  def test_globstar_crosses_separators
    assert_match_glob "src/**/*.rb", "src/foo.rb"
    assert_match_glob "src/**/*.rb", "src/a/b/c/foo.rb"
    assert_match_glob "**/*.rb", "a.rb"
    assert_match_glob "**/*.rb", "deep/nested/a.rb"
  end

  def test_globstar_standalone
    assert_match_glob "**", "a/b/c"
    assert_match_glob "**", "x"
  end

  def test_globstar_vs_single_star
    refute_match_glob "src/*/*.rb", "src/a/b/c.rb"  # single stars: exactly one dir
    assert_match_glob "src/*/*.rb", "src/a/b.rb"
  end

  # --- character classes --------------------------------------------------

  def test_char_class
    assert_match_glob "[abc].rb", "a.rb"
    assert_match_glob "[abc].rb", "c.rb"
    refute_match_glob "[abc].rb", "d.rb"
  end

  def test_char_range
    assert_match_glob "file[0-9].txt", "file7.txt"
    refute_match_glob "file[0-9].txt", "filea.txt"
  end

  def test_negated_class
    assert_match_glob "[!x]oo", "foo"
    refute_match_glob "[!f]oo", "foo"
    assert_match_glob "[^x]oo", "foo"
  end

  def test_class_does_not_cross_separator_implicitly
    # a class still only matches one char; that char shouldn't be allowed to be
    # part of crossing a separator since it's a single char anyway
    refute_match_glob "[a-z].rb", "ab.rb"
  end

  # --- brace expansion ----------------------------------------------------

  def test_brace_alternation
    assert_match_glob "*.{rb,erb}", "foo.rb"
    assert_match_glob "*.{rb,erb}", "foo.erb"
    refute_match_glob "*.{rb,erb}", "foo.txt"
  end

  def test_brace_with_paths_inside
    assert_match_glob "src/{models,views}/*.rb", "src/models/user.rb"
    assert_match_glob "src/{models,views}/*.rb", "src/views/user.rb"
    refute_match_glob "src/{models,views}/*.rb", "src/controllers/user.rb"
  end

  def test_nested_braces
    assert_match_glob "{a,b{c,d}}.rb", "a.rb"
    assert_match_glob "{a,b{c,d}}.rb", "bc.rb"
    assert_match_glob "{a,b{c,d}}.rb", "bd.rb"
    refute_match_glob "{a,b{c,d}}.rb", "be.rb"
  end

  def test_numeric_range
    assert_match_glob "file{1..3}.txt", "file1.txt"
    assert_match_glob "file{1..3}.txt", "file3.txt"
    refute_match_glob "file{1..3}.txt", "file4.txt"
  end

  def test_single_element_brace_is_literal
    assert_match_glob "a{b}c", "a{b}c"
    refute_match_glob "a{b}c", "abc"
  end

  # --- extglobs -----------------------------------------------------------

  def test_extglob_at_one_of
    assert_match_glob "image.@(jpg|png)", "image.jpg"
    assert_match_glob "image.@(jpg|png)", "image.png"
    refute_match_glob "image.@(jpg|png)", "image.gif"
    refute_match_glob "image.@(jpg|png)", "image."
  end

  def test_extglob_optional
    assert_match_glob "foo?(bar)", "foo"
    assert_match_glob "foo?(bar)", "foobar"
    refute_match_glob "foo?(bar)", "foobarbar"
  end

  def test_extglob_star
    assert_match_glob "foo*(bar)", "foo"
    assert_match_glob "foo*(bar)", "foobar"
    assert_match_glob "foo*(bar)", "foobarbar"
  end

  def test_extglob_plus
    refute_match_glob "foo+(bar)", "foo"
    assert_match_glob "foo+(bar)", "foobar"
    assert_match_glob "foo+(bar)", "foobarbar"
  end

  def test_extglob_negation
    assert_match_glob "!(*.rb)", "foo.txt"
    refute_match_glob "!(*.rb)", "foo.rb"
  end

  def test_extglob_can_be_disabled
    # With extglob off, "@(...)" is treated literally.
    assert_match_glob "@(a)", "@(a)", extglob: false
    refute_match_glob "@(a)", "a", extglob: false
  end

  # --- escaping -----------------------------------------------------------

  def test_escaped_wildcards_are_literal
    assert_match_glob "a\\*b", "a*b"
    refute_match_glob "a\\*b", "axb"
    assert_match_glob "a\\?b", "a?b"
    assert_match_glob "a\\{b", "a{b"
  end

  # --- leading dot rule ---------------------------------------------------

  def test_wildcards_do_not_match_leading_dot_by_default
    refute_match_glob "*", ".hidden"
    refute_match_glob "*.txt", ".secret.txt"
    refute_match_glob "?file", ".file"
  end

  def test_dot_option_allows_leading_dot
    assert_match_glob "*", ".hidden", dot: true
    assert_match_glob "*.txt", ".secret.txt", dot: true
  end

  def test_explicit_dot_matches_dotfiles
    assert_match_glob ".*", ".hidden"
    assert_match_glob ".env*", ".env.local"
  end

  # --- options ------------------------------------------------------------

  def test_nocase
    refute_match_glob "*.RB", "foo.rb"
    assert_match_glob "*.RB", "foo.rb", nocase: true
  end

  def test_custom_separator
    assert_match_glob "a.*.c", "a.b.c", separator: "."
    refute_match_glob "a.*.c", "a.b.x.c", separator: "."
  end

  # --- API surface --------------------------------------------------------

  def test_compile_once_match_many
    g = Picoglob.new("logs/*.log")
    assert g.match?("logs/app.log")
    refute g.match?("logs/2026/x.log")
    refute g.match?("other/app.log")
  end

  def test_to_regexp_returns_a_regexp
    re = Picoglob.to_regexp("*.rb")
    assert_kind_of Regexp, re
    assert re.match?("foo.rb")
  end

  def test_filter
    files = ["a.rb", "lib/b.rb", "c.txt", "lib/d.txt"]
    assert_equal ["a.rb", "lib/b.rb"], Picoglob.filter("**/*.rb", files)
  end

  def test_matcher_triple_equals_works_in_case
    matched =
      case "image.png"
      when Picoglob.new("*.png") then :png
      else :other
      end
    assert_equal :png, matched
  end

  def test_exposes_pattern_and_regexp
    g = Picoglob.new("*.rb")
    assert_equal "*.rb", g.pattern
    assert_kind_of Regexp, g.regexp
  end

  # --- error handling -----------------------------------------------------

  def test_unterminated_class_raises
    assert_raises(Picoglob::ParseError) { Picoglob.new("[abc") }
  end

  def test_unterminated_brace_raises
    assert_raises(Picoglob::ParseError) { Picoglob.new("{a,b") }
  end

  def test_dangling_escape_raises
    assert_raises(Picoglob::ParseError) { Picoglob.new("foo\\") }
  end

  # --- real-world-ish ------------------------------------------------------

  def test_s3_key_matching
    g = Picoglob.new("uploads/*/thumbnails/*.{jpg,png}")
    assert g.match?("uploads/2026/thumbnails/cat.jpg")
    assert g.match?("uploads/users/thumbnails/avatar.png")
    refute g.match?("uploads/2026/originals/cat.jpg")
  end

  def test_route_matching_with_globstar
    g = Picoglob.new("/api/**")
    assert g.match?("/api/v1/users")
    assert g.match?("/api/")
    refute g.match?("/admin/users")
  end
end
