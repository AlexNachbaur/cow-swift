# Thread Safety

What is safe to share between threads, and what still needs synchronization.

## Overview

``CopyOnWrite/CopyOnWrite`` offers the same guarantees as the standard library's copy-on-write collections, and
it is `Sendable` whenever the wrapped value is. There are two rules.

### Copies are independent

Different copies of a wrapper can be read and mutated from different threads at the same time, even while
they share storage. Shared storage is never written to: a wrapper that is about to mutate first checks whether
it holds the only reference, and if it doesn't, it copies the value into storage of its own. Other copies never
observe a change they didn't make.

```swift
let base = CopyOnWrite(Settings())

await withTaskGroup(of: Void.self) { group in
    for _ in 0..<8 {
        group.addTask {
            var local = base            // shares storage with every other task
            local.value.retries += 1    // copies once, then mutates in place
        }
    }
}

// `base` is unchanged.
```

### A single variable is not synchronized

One *variable* mutated from several threads at once is a data race, exactly as it would be for an `Array`.
In Swift 6 language mode the compiler rejects such code. To share a mutable wrapper between threads,
protect it the way you would protect any other value: with an actor, a `Mutex`, or another form of
mutual exclusion.

```swift
import Synchronization

final class Cache: Sendable {
    private let entries = Mutex(CopyOnWrite([String: Entry]()))

    func snapshot() -> CopyOnWrite<[String: Entry]> {
        entries.withLock { $0 }         // O(1) copy; readers then work lock-free
    }
}
```

## Why there is no lock inside

Copy-on-write doesn't need a lock to be thread-safe. Uniqueness checks use the atomic reference count that
Swift maintains for every class instance, and storage is only mutated while it is uniquely owned, so there's
nothing left for a lock to protect.

A lock inside the wrapper wouldn't make a single shared variable safe either: the compiler and runtime
enforce exclusive access to the variable itself, independently of anything inside it. It would only add
overhead to every read and write, and make ``CopyOnWrite/CopyOnWrite/modify(_:)`` deadlock whenever its closure
touched another copy of the same value.

## Verifying it

The package's concurrency tests are written to be run under the thread sanitizer, and continuous
integration runs them that way:

```sh
swift test --sanitize=thread
```
