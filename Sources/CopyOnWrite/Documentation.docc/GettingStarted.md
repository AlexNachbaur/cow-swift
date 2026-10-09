# Getting Started

Wrap a value, copy it freely, and mutate it the way you already do.

## Add the package

Add cow-swift to the dependencies in your `Package.swift`, and add the `CopyOnWrite` product to any target
that uses it:

```swift
dependencies: [
    .package(url: "https://github.com/AlexNachbaur/cow-swift.git", from: "1.0.0"),
],
targets: [
    .target(name: "MyLibrary", dependencies: [
        .product(name: "CopyOnWrite", package: "cow-swift"),
    ]),
]
```

## Choose a style

There are two ways to use ``CopyOnWrite/CopyOnWrite``, and they behave identically. Pick whichever reads best.

### As a property wrapper

Mark a stored property with `@CopyOnWrite`. The rest of your code is unchanged: reads, writes, and
synthesized conformances such as `Equatable`, `Hashable`, `Codable`, and `Sendable` all see through the wrapper.

```swift
struct Document: Equatable, Codable, Sendable {
    @CopyOnWrite var contents: Contents
    var revision = 0
}

var draft = Document(contents: Contents())
draft.contents.title = "Untitled"       // mutates in place
draft.contents.paragraphs.append("…")   // still in place
```

The `$contents` projection exposes the wrapper itself, which is useful for checking whether two documents
still share the same contents:

```swift
if draft.$contents.isIdentical(to: snapshot.$contents) {
    // Nothing has been written since the snapshot was taken.
}
```

### As a value

Create a wrapper directly when you don't control the declaring type, or when the wrapper is the whole value:

```swift
var profile = CopyOnWrite(Profile(name: "Jane", tags: []))

profile.value.name = "John"         // mutate through `value`…
profile.name = "John"               // …or through dynamic member lookup
profile.modify {                    // …or batch several mutations
    $0.tags.append("admin")
    $0.tags.append("staff")
}

print(profile.value)                // the whole wrapped value
```

## Copy, then mutate

Copies share storage until one of them is mutated. The mutated copy quietly gets its own storage; the others
keep seeing the value they had.

```swift
var original = CopyOnWrite([1, 2, 3])
var copy = original
print(original === copy)            // true: one storage, two wrappers

copy.value.append(4)

print(original.value)               // [1, 2, 3]
print(copy.value)                   // [1, 2, 3, 4]
print(original === copy)            // false
```

## What to wrap

Wrap value types. ``CopyOnWrite/CopyOnWrite`` copies the wrapped value the way Swift copies any value, so if `Value`
is a class, or a struct holding a class reference, the copy still refers to the same object. The wrapper then
provides cheap copies of the *reference*, not of the object's state.

There's no need to wrap types that are already copy-on-write, such as `Array`, `Dictionary`, `Set`, `String`,
or `Data`, unless a struct holds several of them. Wrapping the struct turns several reference-count
operations per copy into one.
