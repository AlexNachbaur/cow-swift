# Contributing to cow-swift

Thanks for your interest in contributing. This is a small package with a deliberately small surface area,
so the bar for new API is high, and the bar for bug fixes, documentation improvements, and new tests is low.

## Reporting bugs

Open an issue with a minimal snippet that reproduces the problem, the Swift version (`swift --version`),
and the platform. If you believe you've found a thread-safety problem, include the output of
`swift test --sanitize=thread` or a test that fails under it.

## Proposing API changes

Open an issue first. Describe the use case the current API can't express well, and sketch the API you
have in mind. Keep in mind the package's goals:

- It should be exceedingly simple to use.
- It should avoid foot-guns: there should be no way to accidentally copy a value, lose a mutation, or
  introduce a data race without the compiler saying so.
- It should be fast. Every public entry point is `@inlinable`, and mutations through every path must
  happen in place when the storage is uniquely referenced. The tests in `InPlaceMutationTests.swift`
  enforce this; any new mutating API needs a test there.
- It depends on nothing but the standard library, and works on every platform Swift supports.

## Building and testing

```sh
swift build
swift test
swift test --sanitize=thread      # the concurrency tests are written for this
swift format lint --recursive --strict .
```

CI runs the test suite on macOS, Linux (Swift 6.0 through the latest release), and Windows, builds for
Android, and runs the thread sanitizer. Please run the linter before opening a pull request; the
configuration is in `.swift-format`, and `swift format --in-place --recursive .` fixes most findings.

## Pull requests

- Keep each pull request focused on one change.
- Add or update tests for any behavior change, and documentation for any API change. Public API is documented
  with `///` comments and, where a guide is warranted, in `Sources/CopyOnWrite/Documentation.docc`.
- Add an entry to `CHANGELOG.md` under *Unreleased*.
- Source files carry the license header used by their neighbors. Files derived from okta-mobile-swift keep
  Okta's original notice followed by the modifications notice; new files use the short header with the
  project copyright line and SPDX identifier.

## License

By contributing, you agree that your contributions are licensed under the [Apache License, Version 2.0](LICENSE).
