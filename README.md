# picoglob

Compile **bash-style glob patterns into reusable Ruby `Regexp`s** so you can
match *arbitrary strings* — S3 keys, routes, log lines, branch names, queue
topics — not just files on disk.

It's the missing Ruby counterpart to JavaScript's
[picomatch](https://github.com/micromatch/picomatch) / minimatch. Ruby ships
`File.fnmatch` and `Dir.glob`, but neither hands you a reusable `Regexp`, and
`File.fnmatch`'s brace/extglob support is awkward to use off the filesystem.

Pure Ruby, zero dependencies.

## Installation

```ruby
# Gemfile
gem "picoglob"
```

```sh
gem install picoglob
```

## Usage

```ruby
require "picoglob"

# One-shot
Picoglob.match?("src/**/*.{rb,erb}", "src/app/models/user.rb")  # => true
Picoglob.match?("*.rb", "lib/foo.rb")                           # => false (single * doesn't cross "/")

# Compile once, match many (recommended in hot paths)
g = Picoglob.new("logs/*.log")
g.match?("logs/app.log")    # => true
g.match?("logs/2026/x.log") # => false

# Get the underlying Regexp
Picoglob.to_regexp("*.rb")   # => /\A(?:(?!\.)[^\/]*)\.rb\z/

# Filter a list
Picoglob.filter("**/*.rb", ["a.rb", "lib/b.rb", "c.txt"])  # => ["a.rb", "lib/b.rb"]

# Use it in a case/when (Matcher implements ===)
case key
when Picoglob.new("uploads/**/*.jpg") then handle_image
end
```

## Supported syntax

| Pattern | Meaning |
|---|---|
| `*` | any run of non-separator characters |
| `**` | globstar — any run of characters, *including* separators |
| `**/` | zero or more whole path segments (so `src/**/*.rb` also matches `src/foo.rb`) |
| `?` | exactly one non-separator character |
| `[abc]` `[a-z]` | character class |
| `[!abc]` `[^abc]` | negated character class |
| `{a,b,c}` | alternation — one of the alternatives |
| `{1..5}` | numeric range expansion |
| `@(a\|b)` | exactly one of (extglob) |
| `?(a\|b)` | zero or one of (extglob) |
| `*(a\|b)` | zero or more of (extglob) |
| `+(a\|b)` | one or more of (extglob) |
| `!(a\|b)` | anything except (extglob) |
| `\*` | a literal `*` (escape any metacharacter) |

Braces and extglobs nest, and compile recursively, so things like
`{a,b{c,d}}` and `image.@(jp?(e)g\|png)` work.

## Options

```ruby
Picoglob.new(pattern,
  separator: "/",   # the char that * / ? won't cross (use "." for dotted names, etc.)
  dot:       false, # when false, wildcards won't match a leading "." (shell behavior)
  extglob:   true,  # enable @()/?()/*()/+()/!() extglobs
  nocase:    false) # case-insensitive matching
```

```ruby
Picoglob.match?("*.RB", "foo.rb", nocase: true)        # => true
Picoglob.match?("*", ".hidden")                        # => false (dotfile protected)
Picoglob.match?("*", ".hidden", dot: true)             # => true
Picoglob.match?("a.*.c", "a.b.c", separator: ".")      # => true
```

## Why not just use `File.fnmatch`?

`File.fnmatch` is fine for matching against the filesystem, but:

- it doesn't give you a reusable `Regexp` to combine, inspect, or reuse;
- brace expansion requires `File::FNM_EXTGLOB` and still can't be turned into a
  pattern you keep;
- there's no extglob (`@()`, `+()`, `!()`, …) support;
- the dotfile / separator rules aren't configurable per call.

`picoglob` gives you a compiled `Regexp` you own, with picomatch-style semantics,
that works on any string.

## Development

```sh
bundle install
bundle exec rake test
```

## License

MIT © Levelbrook Consulting. See [LICENSE](LICENSE).
