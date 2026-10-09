# cow-swift

[![CI](https://github.com/AlexNachbaur/cow-swift/actions/workflows/ci.yaml/badge.svg)](https://github.com/AlexNachbaur/cow-swift/actions/workflows/ci.yaml)
[![Documentation](https://img.shields.io/badge/documentation-DocC-blue)](https://swiftpackageindex.com/AlexNachbaur/cow-swift/documentation/copyonwrite)
[![Swift 6.0+](https://img.shields.io/badge/swift-6.0+-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-Apple%20%7C%20Linux%20%7C%20Android%20%7C%20Windows-lightgrey)](#requirements)
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)

A tiny, dependency-free copy-on-write wrapper for your own value types.

Copying a Swift struct copies every stored property. `CopyOnWrite` moves the value onto the heap and shares
it between copies, so copying costs one reference-count increment no matter how large the value is. The
value is copied only when a copy is mutated while its storage is still shared, which is exactly what `Array`,
`Dictionary`, and `String` do. Value semantics are preserved; the copies just got cheap.

```swift
import CopyOnWrite

struct Document: Equatable, Codable, Sendable {
    @CopyOnWrite var contents: Contents   // a large struct
    var revision = 0
}

var draft = Document(contents: Contents())
let snapshot = draft                      // O(1)
draft.contents.title = "Untitled"         // copies `Contents` once; `snapshot` is unaffected
draft.contents.paragraphs.append("…")     // in place from now on
```

## Features

- **Two styles, one behavior.** Use it as a property wrapper (`@CopyOnWrite var contents: Contents`) or as a
  value (`CopyOnWrite(contents)`), whichever reads better.
- **Mutations stay in place.** Writing through `.value`, through a member (`wrapper.title = "…"`), through
  `modify { … }`, or through a wrapped property all mutate uniquely owned storage directly, without hidden copies.
- **Transparent conformances.** `Equatable`, `Hashable`, `Comparable`, `Codable`, `Sendable`, and
  `CustomStringConvertible` are provided whenever the wrapped value supports them, and they see through the
  wrapper. Synthesized conformances on types that use `@CopyOnWrite` work as expected, including optional
  properties with missing keys.
- **Identity checks.** `a.isIdentical(to: b)` (or `a === b`) tells you in O(1) whether two wrappers still share
  storage, which means neither has been mutated since they were copied.
- **Thread-safe the way `Array` is.** Copies can be read and mutated concurrently, and the wrapper is
  `Sendable` whenever its value is. There is no lock inside; see [Thread safety](#thread-safety).
- **Zero dependencies.** Only the standard library, so it builds everywhere Swift does.

## Usage

### As a property wrapper

```swift
struct Document {
    @CopyOnWrite var contents: Contents
}

var draft = Document(contents: Contents())
draft.contents.title = "Untitled"

// The `$` projection gives read-only access to the wrapper, which is useful for identity checks:
if draft.$contents.isIdentical(to: snapshot.$contents) {
    // nothing has been written since the snapshot
}
```

### As a value

```swift
var profile = CopyOnWrite(Profile(name: "Jane", tags: []))

profile.value.name = "John"       // mutate through `value`…
profile.name = "John"             // …or through dynamic member lookup
let count = profile.modify {      // …or batch several mutations, returning a result
    $0.tags.append("admin")
    $0.tags.append("staff")
    return $0.tags.count
}

var copy = profile                // shares storage
copy.name = "Jane"                // `copy` gets its own storage; `profile` still says "John"
print(profile === copy)           // false
```

The full API is documented in the [DocC catalog](https://swiftpackageindex.com/AlexNachbaur/cow-swift/documentation/copyonwrite),
including guides on [thread safety](Sources/CopyOnWrite/Documentation.docc/ThreadSafety.md) and
[performance](Sources/CopyOnWrite/Documentation.docc/Performance.md).

## Thread safety

`CopyOnWrite` offers the same guarantees as the standard library's collections:

- **Different copies are independent.** They can be read and mutated from different threads at the same time,
  even while they share storage. Storage is only ever written to by a wrapper that holds the only reference
  to it, so no other copy can observe the write.
- **A single variable is not synchronized.** Mutating one variable from several threads at once is a data race,
  just as it is for an `Array`, and the Swift 6 compiler rejects such code. Protect a shared mutable wrapper
  with an actor or a `Mutex`, as you would any other value.

Copy-on-write doesn't need a lock to be thread-safe: uniqueness checks rely on the atomic reference count
Swift already maintains, so reads and uncontended writes cost no more than a pointer dereference and a
uniqueness check. The concurrency tests run under the thread sanitizer in CI.

## Requirements

- Swift 6.0 or later
- Any platform Swift supports: Apple platforms, Linux, Android, and Windows. CI builds and tests on macOS,
  Linux, and Windows, and builds for Android.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/AlexNachbaur/cow-swift.git", from: "1.0.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: [
        .product(name: "CopyOnWrite", package: "cow-swift"),
    ]),
]
```

Or in Xcode, choose *File ▸ Add Package Dependencies…* and enter `https://github.com/AlexNachbaur/cow-swift.git`.

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) for how to build, test, and
submit changes, and [SECURITY.md](SECURITY.md) for how to report a vulnerability.

## License

cow-swift is released under the [Apache License, Version 2.0](LICENSE).

The initial implementation was extracted from the [okta-mobile-swift](https://github.com/okta/okta-mobile-swift)
library, which is also Apache 2.0 licensed. Original copyright notices are preserved in the affected source
files, and attribution is recorded in [NOTICE](NOTICE).
