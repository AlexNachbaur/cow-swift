# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `CopyOnWrite<Value>`, a copy-on-write wrapper for any value type, usable directly or as the
  `@CopyOnWrite` property wrapper.
- In-place mutation through `value`, through dynamic member lookup, through `modify(_:)`, and through
  wrapped properties, with a single uniqueness check per mutation.
- `modify(_:)` with typed throws, so the closure's error type is preserved.
- `isIdentical(to:)`, `===`, and `!==` for O(1) storage identity checks.
- Conditional `Sendable`, `Equatable`, `Hashable`, `Comparable`, `Encodable`, and `Decodable` conformances,
  plus `CustomStringConvertible`, `CustomDebugStringConvertible`, and `CustomReflectable`.
- `KeyedDecodingContainer`/`KeyedEncodingContainer` overloads so `@CopyOnWrite` optional properties decode a
  missing key as `nil` and omit `nil` when encoding, like plain optional properties.
- A DocC catalog with guides on getting started, thread safety, and performance.
- Support for Apple platforms, Linux, Android, and Windows, with no dependencies beyond the standard library.
