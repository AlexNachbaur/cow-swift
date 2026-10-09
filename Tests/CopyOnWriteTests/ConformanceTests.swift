//
// Copyright (c) 2026, Alexandra Nachbaur. All rights reserved.
//
// This source file is part of the cow-swift open source project.
// Licensed under the Apache License, Version 2.0. See LICENSE for details.
//
// SPDX-License-Identifier: Apache-2.0
//

import CopyOnWrite
import Foundation
import Testing

private struct Profile: Equatable, Codable {
    @CopyOnWrite var name: String
    @CopyOnWrite var nickname: String?
}

@Suite("Conformances")
struct ConformanceTests {
    @Test("Equality compares wrapped values")
    func equatable() {
        let a = CopyOnWrite([1, 2, 3])
        let b = CopyOnWrite([1, 2, 3])
        let c = CopyOnWrite([4])

        #expect(a == b)
        #expect(a != c)
        #expect(a == a)
    }

    @Test("Copies sharing storage are equal without comparing values")
    func equatableIdentityFastPath() {
        struct CountsComparisons: Equatable {
            nonisolated(unsafe) static var comparisons = 0

            static func == (lhs: Self, rhs: Self) -> Bool {
                comparisons += 1
                return true
            }
        }

        let a = CopyOnWrite(CountsComparisons())
        let b = a
        #expect(a == b)
        #expect(CountsComparisons.comparisons == 0)

        #expect(a == CopyOnWrite(CountsComparisons()))
        #expect(CountsComparisons.comparisons == 1)
    }

    @Test("Hashing matches the wrapped value")
    func hashable() {
        let value = ["a", "b"]
        #expect(CopyOnWrite(value).hashValue == value.hashValue)

        let set: Set = [CopyOnWrite(1), CopyOnWrite(1), CopyOnWrite(2)]
        #expect(set.count == 2)
    }

    @Test("Ordering matches the wrapped value")
    func comparable() {
        #expect(CopyOnWrite(1) < CopyOnWrite(2))
        #expect([CopyOnWrite(3), CopyOnWrite(1), CopyOnWrite(2)].sorted().map(\.value) == [1, 2, 3])
    }

    @Test("Encoding is transparent")
    func encodable() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let wrapped = try encoder.encode(CopyOnWrite(["b": 2, "a": 1]))
        #expect(String(decoding: wrapped, as: UTF8.self) == #"{"a":1,"b":2}"#)
    }

    @Test("Decoding is transparent")
    func decodable() throws {
        let decoded = try JSONDecoder().decode(CopyOnWrite<[Int]>.self, from: Data("[1,2,3]".utf8))
        #expect(decoded.value == [1, 2, 3])
    }

    @Test("Wrapped optional properties decode a missing key as nil")
    func decodesMissingOptional() throws {
        let decoder = JSONDecoder()

        let missing = try decoder.decode(Profile.self, from: Data(#"{"name":"Jane"}"#.utf8))
        #expect(missing == Profile(name: "Jane", nickname: nil))

        let null = try decoder.decode(Profile.self, from: Data(#"{"name":"Jane","nickname":null}"#.utf8))
        #expect(null == Profile(name: "Jane", nickname: nil))

        let present = try decoder.decode(Profile.self, from: Data(#"{"name":"Jane","nickname":"JD"}"#.utf8))
        #expect(present == Profile(name: "Jane", nickname: "JD"))
    }

    @Test("Wrapped optional properties omit nil when encoding")
    func encodesOptional() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let without = try encoder.encode(Profile(name: "Jane", nickname: nil))
        #expect(String(decoding: without, as: UTF8.self) == #"{"name":"Jane"}"#)

        let with = try encoder.encode(Profile(name: "Jane", nickname: "JD"))
        #expect(String(decoding: with, as: UTF8.self) == #"{"name":"Jane","nickname":"JD"}"#)
    }

    @Test("Wrapped required properties still require their key")
    func decodeRequiresNonOptional() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Profile.self, from: Data(#"{"nickname":"JD"}"#.utf8))
        }
    }

    @Test("Descriptions show the wrapped value")
    func descriptions() {
        let cow = CopyOnWrite(["a"])
        #expect(String(describing: cow) == #"["a"]"#)
        #expect(String(reflecting: cow) == #"CopyOnWrite(["a"])"#)
        #expect("\(cow)" == #"["a"]"#)

        let children = Mirror(reflecting: cow).children.map { $0.label }
        #expect(children == ["value"])
    }
}
