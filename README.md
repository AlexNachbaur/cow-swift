# swift-cow
A tiny, focused, thread-safe Copy‑On‑Write wrapper for your own value types.

Implements the Copy‑On‑Write (CoW) pattern to provide performant value semantics while avoiding unnecessary copies. Useful when you want your own structs (or any `T`) to behave like Swift's standard CoW containers (e.g. `Array`, `Dictionary`, `String`).

## What is Copy‑On‑Write?
Copy‑On‑Write is an optimization strategy used by many Swift standard library types. Multiple variables can share the same underlying storage as long as no one mutates it. When a mutation happens and the storage is shared, the data is copied first so that each variable continues to see its own independent value. This preserves value semantics while reducing allocations and copies.

This package wraps any `T` in a lightweight reference with an internal lock. Reads are fast; writes only copy when the storage is shared. The result: predictable value semantics, fewer allocations, and safe concurrent access.

## Features
- Generic CoW wrapper for any `T`
- Value semantics with identity checks (`===` / `!==`) to see if two wrappers share storage
- Thread-safe reads and mutations guarded by an internal lock
- Zero-copy reads; copy occurs only on mutation when storage is shared
- `modify` API to batch multiple mutations atomically and efficiently
- `Sendable` conformance when `T: Sendable`
- Small surface area, no magic

## Requirements
- Swift 6+
- Platforms: Darwin _(iOS, macOS, tvOS, watchOS, visionOS)_, Linux, Android, and Windows

> These reflect the concurrency and locking baselines typically used with modern Swift packages.

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/codergirl-dev/swift-cow.git", from: "1.0.0"),
],
```

## Provenance

The initial implementation for this was originally part of the [okta-mobile-swift](https://github.com/okta/okta-mobile-swift) library. It has been extracted and refactored to be used independently as a small, focused package. Original credit and license notices are preserved.
