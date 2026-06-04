# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-28

### Added
- Initial release.
- `Picoglob.new(pattern, **opts)` -> `Picoglob::Matcher` (compile once, match many).
- `Picoglob.match?`, `Picoglob.to_regexp`, `Picoglob.filter` convenience methods.
- `Matcher#match?`, `#===`, `#to_regexp`, `#filter`, `#pattern`, `#regexp`.
- Glob syntax: `*`, `**`, `**/`, `?`, `[...]`, `[!...]`/`[^...]`, `{a,b}`,
  `{1..n}` ranges, and extglobs `@()`, `?()`, `*()`, `+()`, `!()`, plus escaping.
- Options: `separator`, `dot`, `extglob`, `nocase`.
- `Picoglob::ParseError` for malformed patterns.

[Unreleased]: https://github.com/tachyurgy/picoglob/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/tachyurgy/picoglob/releases/tag/v0.1.0
