//
// Copyright (c) 2026, Alexandra Nachbaur. All rights reserved.
//
// This source file is part of the cow-swift open source project.
// Licensed under the Apache License, Version 2.0. See LICENSE for details.
//
// SPDX-License-Identifier: Apache-2.0
//

extension CopyOnWrite: Equatable where Value: Equatable {
    /// Returns a Boolean value indicating whether two wrappers hold equal values.
    ///
    /// Wrappers that share storage are equal without comparing their values, which makes comparing
    /// a value against an unmodified copy of itself an O(1) operation. Like `Array`, this means
    /// a wrapper always equals its own copies, even for the rare values that aren't equal to themselves,
    /// such as `Double.nan`.
    @inlinable
    public static func == (lhs: CopyOnWrite<Value>, rhs: CopyOnWrite<Value>) -> Bool {
        lhs._storage === rhs._storage || lhs._storage.value == rhs._storage.value
    }
}

extension CopyOnWrite: Hashable where Value: Hashable {
    /// Hashes the wrapped value.
    ///
    /// A wrapper hashes the same as the value it wraps.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_storage.value)
    }
}

extension CopyOnWrite: Comparable where Value: Comparable {
    /// Returns a Boolean value indicating whether the first wrapper's value orders before the second's.
    @inlinable
    public static func < (lhs: CopyOnWrite<Value>, rhs: CopyOnWrite<Value>) -> Bool {
        lhs._storage.value < rhs._storage.value
    }
}

extension CopyOnWrite: Encodable where Value: Encodable {
    /// Encodes the wrapped value.
    ///
    /// The wrapper is transparent: it encodes exactly as the wrapped value does, without adding
    /// a container of its own.
    @inlinable
    public func encode(to encoder: any Encoder) throws {
        try _storage.value.encode(to: encoder)
    }
}

extension CopyOnWrite: Decodable where Value: Decodable {
    /// Decodes a wrapped value.
    ///
    /// The wrapper is transparent: it decodes exactly what the wrapped value decodes.
    @inlinable
    public init(from decoder: any Decoder) throws {
        self.init(try Value(from: decoder))
    }
}

extension CopyOnWrite: CustomStringConvertible {
    /// A textual representation of the wrapped value.
    public var description: String {
        String(describing: _storage.value)
    }
}

extension CopyOnWrite: CustomDebugStringConvertible {
    /// A textual representation of the wrapper and its value, suitable for debugging.
    public var debugDescription: String {
        "CopyOnWrite(\(String(reflecting: _storage.value)))"
    }
}

extension CopyOnWrite: CustomReflectable {
    /// A mirror that presents the wrapped value instead of the wrapper's storage.
    public var customMirror: Mirror {
        Mirror(self, children: ["value": _storage.value], displayStyle: .struct)
    }
}

// Synthesized `Codable` conformances treat a property wrapper as a required key, even when it wraps
// an optional. These overloads make `@CopyOnWrite var name: String?` behave like `var name: String?`:
// a missing key decodes as `nil`, and `nil` is omitted when encoding.

extension KeyedDecodingContainer {
    /// Decodes a copy-on-write wrapper around an optional value, treating a missing key as `nil`.
    public func decode<Wrapped: Decodable>(
        _ type: CopyOnWrite<Wrapped?>.Type,
        forKey key: Key
    ) throws -> CopyOnWrite<Wrapped?> {
        CopyOnWrite(try decodeIfPresent(Wrapped.self, forKey: key))
    }
}

extension KeyedEncodingContainer {
    /// Encodes a copy-on-write wrapper around an optional value, omitting the key when the value is `nil`.
    public mutating func encode<Wrapped: Encodable>(
        _ value: CopyOnWrite<Wrapped?>,
        forKey key: Key
    ) throws {
        try encodeIfPresent(value.value, forKey: key)
    }
}
