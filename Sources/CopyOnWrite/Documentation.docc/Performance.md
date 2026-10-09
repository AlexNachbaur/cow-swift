# Performance

What each operation costs, and how to keep mutations in place.

## Overview

| Operation | Cost |
| --- | --- |
| Copying a wrapper | One reference-count increment |
| Reading ``CopyOnWrite/CopyOnWrite/value`` or a member | A pointer dereference, no copy |
| Mutating a uniquely referenced wrapper | A uniqueness check, then the mutation in place |
| Mutating a shared wrapper | One copy of `Value`, then the mutation in place |
| Assigning a whole new value | One allocation if shared, otherwise in place; the old value is never copied |
| `==` on copies that share storage | O(1), without comparing values |

The whole public API is inlinable, so the compiler specializes it for your `Value` type and these costs
hold across module boundaries.

## Mutations are in place, whichever way you write them

Every mutating path first ensures the storage is uniquely referenced, then mutates it directly. None of
these copy the wrapped value when the wrapper is unique:

```swift
wrapper.value.items.append(x)        // through `value`
wrapper.items.append(x)              // through dynamic member lookup
wrapper.modify { $0.items.append(x) } // through `modify`
document.contents.items.append(x)    // through a wrapped property
```

Use ``CopyOnWrite/CopyOnWrite/modify(_:)`` when you have several mutations to make at once. It performs one uniqueness
check for the whole closure, and lets you return a result.

## Copies that are easy to miss

A copy of the wrapper anywhere forces the next mutation to copy the value. The usual sources are:

- Keeping a copy around on purpose, such as a snapshot for undo. That's the feature, and it costs one copy
  per mutation *of the shared version*. Once the mutated wrapper has its own storage, it stays in place.
- Reading ``CopyOnWrite/CopyOnWrite/value`` into a `var`, mutating the `var`, and assigning it back. Mutate through the
  wrapper instead, so the mutation happens in place.
- Mutating through the `$property` projection of a wrapped property. The projection is read-only for this
  reason; mutate the property itself, or use `_property.modify` inside the declaring type.

## Wrapped collections

The wrapped value keeps its own copy-on-write behavior. A `CopyOnWrite<[Int]>` holds one reference to an
array buffer, and appending to it through the wrapper appends to that buffer in place. Wrapping a single
collection is rarely worthwhile; wrapping a struct that holds several of them, or a lot of inline storage, is.
