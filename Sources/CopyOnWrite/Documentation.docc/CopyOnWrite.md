# ``CopyOnWrite``

Give any value cheap, copy-on-write storage.

## Overview

Copying a Swift struct copies every stored property. For small structs that's exactly what you want, but
a struct with many fields, large inline storage, or several nested collections becomes expensive to pass
around, store in collections, or capture in closures.

``CopyOnWrite/CopyOnWrite`` moves the value onto the heap and shares it between copies. Copying the wrapper is a
single reference-count increment. The value is only copied when a wrapper is mutated while its storage is
shared with other copies, which is the same strategy `Array`, `Dictionary`, and `String` use, and the result
has exactly the same value semantics as a plain struct.

```swift
import CopyOnWrite

struct Document {
    @CopyOnWrite var contents: Contents   // `Contents` is a large struct
    var revision = 0
}

var draft = Document(contents: Contents())
let snapshot = draft                      // O(1)
draft.contents.title = "Untitled"         // copies `Contents` once; `snapshot` is unaffected
```

The package has no dependencies and uses only the standard library, so it builds anywhere Swift does,
including Apple platforms, Linux, Android, and Windows.

## Topics

### Essentials

- <doc:GettingStarted>
- ``CopyOnWrite/CopyOnWrite``

### Design

- <doc:ThreadSafety>
- <doc:Performance>
