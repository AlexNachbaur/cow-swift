//
// Copyright (c) 2025, Okta, Inc. and/or its affiliates. All rights reserved.
// The Okta software accompanied by this notice is provided pursuant to the Apache License, Version 2.0 (the "License.")
//
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0.
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//
// See the License for the specific language governing permissions and limitations under the License.
//
// Modifications Copyright (c) 2026, Alexandra Nachbaur. All rights reserved.
// This file is derived from okta-mobile-swift and has been substantially modified for cow-swift.
// The modifications are licensed under the same Apache License, Version 2.0.
//

/// A wrapper that gives any value copy-on-write storage.
///
/// Copying a `CopyOnWrite` is a single reference-count increment, no matter how large the wrapped value
/// is. The wrapped value itself is only copied when one of the copies is mutated while its storage is still
/// shared, which is the same strategy `Array`, `Dictionary`, and `String` use.
///
/// ```swift
/// var original = CopyOnWrite([1, 2, 3])
/// var copy = original                  // O(1): both share one storage
/// print(original === copy)             // true
///
/// copy.value.append(4)                 // storage is shared, so `copy` gets its own first
///
/// print(original.value)                // [1, 2, 3]
/// print(copy.value)                    // [1, 2, 3, 4]
/// print(original === copy)             // false
/// ```
///
/// ## Reading and writing the value
///
/// Use ``value`` to read or mutate the wrapped value. Mutations through `value` happen in place whenever
/// the storage is uniquely referenced. Members of the wrapped value are also available directly on the
/// wrapper through dynamic member lookup, and ``modify(_:)`` batches several mutations together:
///
/// ```swift
/// struct Profile {
///     var name: String
///     var tags: [String]
/// }
///
/// var profile = CopyOnWrite(Profile(name: "Jane", tags: []))
/// profile.name = "John"                // same as `profile.value.name = "John"`
/// profile.modify {
///     $0.tags.append("admin")
///     $0.tags.append("staff")
/// }
/// ```
///
/// ## Using it as a property wrapper
///
/// `CopyOnWrite` is also a property wrapper, which is the simplest way to give a large or frequently
/// copied struct cheap copies without changing how the rest of your code uses it:
///
/// ```swift
/// struct Document {
///     @CopyOnWrite var contents: Contents
/// }
///
/// var draft = Document(contents: Contents())
/// var snapshot = draft                 // O(1), regardless of the size of `Contents`
/// draft.contents.title = "Untitled"    // copies `Contents` once, because `snapshot` shares it
/// ```
///
/// ## Thread safety
///
/// `CopyOnWrite` has the same thread-safety guarantees as the standard library's collections, and
/// it is `Sendable` whenever the wrapped value is:
///
/// - Different copies can be read and mutated from different threads at the same time, even while they
///   share storage. A mutation never changes what another copy observes.
/// - A single *variable* is not synchronized. As with `Array`, mutating one variable from several threads
///   at once requires a lock, an actor, or another form of mutual exclusion. In Swift 6 language mode
///   the compiler rejects such code.
///
/// There is no lock inside `CopyOnWrite`, so reads and uncontended writes cost no more than a pointer
/// dereference and a uniqueness check.
///
/// ## Wrapping reference types
///
/// Copy-on-write copies the wrapped value the way Swift copies any value. If `Value` is a class, or contains
/// a class reference, the copy still refers to the same object. Wrap value types to get value semantics.
@propertyWrapper
@dynamicMemberLookup
public struct CopyOnWrite<Value> {
    @usableFromInline
    internal var _storage: _Storage<Value>

    /// Creates a copy-on-write wrapper around the given value.
    ///
    /// - Parameter value: The value to wrap.
    @inlinable
    public init(_ value: Value) {
        _storage = _Storage(value)
    }

    /// Creates a copy-on-write wrapper around the given value.
    ///
    /// This initializer supports property wrapper syntax. Prefer ``init(_:)`` when creating a wrapper directly.
    ///
    /// - Parameter wrappedValue: The value to wrap.
    @inlinable
    public init(wrappedValue: Value) {
        _storage = _Storage(wrappedValue)
    }

    /// The wrapped value.
    ///
    /// Reading the value never copies the storage. Mutating it, as in `wrapper.value.count += 1`,
    /// happens in place when this wrapper is the only one referencing its storage. If the storage is
    /// shared with other copies, this wrapper first gets its own copy of the value, and the other copies are
    /// left untouched.
    ///
    /// Assigning a whole new value never copies the old one.
    ///
    /// - Complexity: O(1) to read. O(1) to mutate in place when the storage is uniquely referenced.
    ///   Otherwise the cost of copying `Value`, which for a struct is the cost of retaining its
    ///   stored references.
    public var value: Value {
        @inlinable
        _read {
            yield _storage.value
        }
        @inlinable
        set {
            if isKnownUniquelyReferenced(&_storage) {
                _storage.value = newValue
            } else {
                _storage = _Storage(newValue)
            }
        }
        @inlinable
        _modify {
            _makeUnique()
            yield &_storage.value
        }
    }

    /// The wrapped value, for use with property wrapper syntax.
    ///
    /// This is the same as ``value``, and has the same copy-on-write behavior. The compiler uses it
    /// when `CopyOnWrite` is applied to a property as `@CopyOnWrite`.
    public var wrappedValue: Value {
        @inlinable
        _read {
            yield _storage.value
        }
        @inlinable
        set {
            value = newValue
        }
        @inlinable
        _modify {
            _makeUnique()
            yield &_storage.value
        }
    }

    /// The wrapper itself, for use with property wrapper syntax.
    ///
    /// When `CopyOnWrite` is applied to a property as `@CopyOnWrite var contents: Contents`,
    /// the `$contents` projection gives read-only access to the wrapper, which is useful for
    /// comparing identity with ``isIdentical(to:)``:
    ///
    /// ```swift
    /// if draft.$contents.isIdentical(to: snapshot.$contents) {
    ///     // Nothing has been written to either document since the snapshot was taken.
    /// }
    /// ```
    ///
    /// The projection is deliberately read-only, because the compiler would have to copy the wrapper
    /// to mutate through it, which defeats in-place mutation. Mutate the property itself instead.
    /// To call ``modify(_:)`` from inside the type that declares the property, use the underscored
    /// storage, as in `_contents.modify { ... }`.
    @inlinable
    public var projectedValue: CopyOnWrite<Value> {
        self
    }

    /// Accesses a member of the wrapped value.
    @inlinable
    public subscript<Member>(dynamicMember keyPath: KeyPath<Value, Member>) -> Member {
        _storage.value[keyPath: keyPath]
    }

    /// Accesses a mutable member of the wrapped value.
    ///
    /// Writing through this subscript has the same copy-on-write behavior as mutating ``value``.
    @inlinable
    public subscript<Member>(dynamicMember keyPath: WritableKeyPath<Value, Member>) -> Member {
        get {
            _storage.value[keyPath: keyPath]
        }
        _modify {
            _makeUnique()
            yield &_storage.value[keyPath: keyPath]
        }
    }

    /// Mutates the wrapped value in place and returns the result of the closure.
    ///
    /// Use this method to perform several mutations with a single uniqueness check, or to compute
    /// a result while mutating:
    ///
    /// ```swift
    /// var numbers = CopyOnWrite([3, 1, 2])
    /// let largest = numbers.modify { numbers in
    ///     numbers.sort()
    ///     return numbers.removeLast()
    /// }
    /// // largest == 3, numbers.value == [1, 2]
    /// ```
    ///
    /// If the storage is shared with other copies, this wrapper gets its own copy of the value before
    /// the closure runs. The other copies never observe the closure's mutations.
    ///
    /// If the closure throws, mutations it made before throwing are kept, exactly as they are for any
    /// `inout` argument.
    ///
    /// - Parameter body: A closure that receives the wrapped value as an `inout` argument.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by `body`.
    @inlinable
    public mutating func modify<Output, Failure: Error>(
        _ body: (inout Value) throws(Failure) -> Output
    ) throws(Failure) -> Output {
        _makeUnique()
        return try body(&_storage.value)
    }

    /// Returns a Boolean value indicating whether two wrappers share the same storage.
    ///
    /// Two wrappers are identical when one is a copy of the other and neither has been mutated since.
    /// Identical wrappers always hold the same value, so this is a fast way to detect "definitely unchanged"
    /// without comparing the values themselves. Wrappers that aren't identical may still hold equal values.
    ///
    /// - Complexity: O(1)
    @inlinable
    public func isIdentical(to other: CopyOnWrite<Value>) -> Bool {
        _storage === other._storage
    }

    /// Returns a Boolean value indicating whether two wrappers share the same storage.
    ///
    /// This is an operator form of ``isIdentical(to:)``. It compares identity, not equality. Use `==`
    /// to compare the wrapped values.
    @inlinable
    public static func === (lhs: CopyOnWrite<Value>, rhs: CopyOnWrite<Value>) -> Bool {
        lhs._storage === rhs._storage
    }

    /// Returns a Boolean value indicating whether two wrappers have separate storage.
    ///
    /// This is the inverse of ``===(_:_:)``. Wrappers with separate storage may still hold equal values.
    @inlinable
    public static func !== (lhs: CopyOnWrite<Value>, rhs: CopyOnWrite<Value>) -> Bool {
        lhs._storage !== rhs._storage
    }

    /// Ensures this wrapper holds the only reference to its storage, copying the value if it doesn't.
    @inlinable
    internal mutating func _makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _Storage(_storage.value)
        }
    }
}

// The storage is only ever written to while it is uniquely referenced by the wrapper performing the
// write, and exclusive access to that wrapper is enforced by the compiler. Storage that is visible to
// more than one wrapper is therefore immutable, which makes sharing it across threads safe.
extension CopyOnWrite: @unchecked Sendable where Value: Sendable {}

/// The heap storage for a ``CopyOnWrite`` wrapper.
@usableFromInline
internal final class _Storage<Value> {
    // Exclusive access is already guaranteed by the wrapper: writes require exclusive access to the
    // wrapper and unique ownership of this object, so the runtime check would only add overhead.
    @usableFromInline
    @exclusivity(unchecked)
    internal var value: Value

    @inlinable
    internal init(_ value: Value) {
        self.value = value
    }
}
