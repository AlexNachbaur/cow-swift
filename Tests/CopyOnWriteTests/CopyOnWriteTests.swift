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

import Testing
@testable import CopyOnWrite

fileprivate struct TestValue: Sendable, Equatable {
    var firstName: String
    var lastName: String
}

@Suite("CopyOnWrite Tests")
struct CopyOnWriteTests {
    @Test("Basic object copy tests")
    func testCopiedObjects() async throws {
        var value1 = CopyOnWrite<TestValue>(.init(firstName: "Jane", lastName: "Doe"))
        #expect(value1.value.firstName == "Jane")

        var value2 = value1
        #expect(value2.value.firstName == "Jane")
        #expect(value1 === value2)
        #expect(value1.value == value2.value)

        value1.value.firstName = "John"
        #expect(value1.value.firstName == "John")
        #expect(value1 !== value2)
        #expect(value1.value != value2.value)

        value1.value.firstName = "Jane"
        #expect(value2.value.firstName == "Jane")
        #expect(value1 !== value2)

        let value3 = value2
        _ = await Task.detached { @Sendable [value2] in
            var value4 = value2
            #expect(value2 === value3)
            #expect(value2 === value4)

            value4.value.lastName = "Smith"
            #expect(value4.value.lastName == "Smith")
            #expect(value2 === value3)
            #expect(value2 !== value4)
        }.result

        #expect(value2 === value3)
        value2.modify { value in
            value.lastName = "Beuller"
        }
        #expect(value2.value.lastName == "Beuller")
        #expect(value2 !== value3)
    }

    @Test("Set triggers copy when shared")
    func testSetTriggersCopyWhenShared() async throws {
        let a = CopyOnWrite([1, 2, 3])
        var b = a
        #expect(a === b)

        // Setting the entire value on one side should trigger CoW
        b.value.append(4)
        #expect(a !== b)
        #expect(a.value == [1, 2, 3])
        #expect(b.value == [1, 2, 3, 4])
    }

    @Test("Modify ensures uniqueness and batches")
    func testModifyEnsuresUniquenessAndBatches() async throws {
        var a = CopyOnWrite(["a"]) 
        let b = a
        #expect(a === b)

        // Batch multiple mutations efficiently
        a.modify { arr in
            arr.append("b")
            arr.append("c")
        }

        #expect(a !== b)
        #expect(a.value == ["a", "b", "c"]) 
        #expect(b.value == ["a"]) 
    }

    @Test("Identity operators chain")
    func testIdentityOperatorsChain() async throws {
        let a = CopyOnWrite([0])
        let b = a
        var c = b
        #expect(a === b)
        #expect(b === c)

        // Mutate c; only c should diverge
        c.value.append(1)
        #expect(a === b)
        #expect(a !== c)
        #expect(b !== c)
    }

    @Test("Modify throws propagates, and keeps mutations")
    func testModifyThrowsPropagatesAndKeepsMutations() async throws {
        struct E: Error {}
        var value = CopyOnWrite([1])

        do {
            try value.modify { arr in
                arr.append(2)           // mutation happens
                throw E()               // then an error
            }
            Issue.record("Should have thrown")
        } catch is E {
            // Current semantics: mutation is not rolled back
            #expect(value.value == [1, 2])
        }
    }

    @Test("Reference type payload shares interior mutability")
    func testReferenceTypePayloadSharesInteriorMutability() async throws {
        final class Box { var i: Int; init(_ i: Int) { self.i = i } }

        let a = CopyOnWrite(Box(1))
        var b = a
        #expect(a === b)

        // Mutating the inner reference type mutates both views
        b.value.i = 2
        #expect(a.value.i == 2)
        #expect(b.value.i == 2)

        // Setting the entire value performs CoW on the wrapper, but the inner class is still shared
        b.value = Box(3)
        #expect(a !== b)
        #expect(a.value.i == 2)
        #expect(b.value.i == 3)
    }

    @Test("Concurrency tasks do not affect base object")
    func testConcurrencyTasksDoNotAffectBase() async throws {
        let base = CopyOnWrite([Int]())
        let iterations = 50

        // Spawn multiple tasks that each take a shared snapshot and mutate their own copy
        let results = try await withThrowingTaskGroup(of: [Int].self) { group in
            for i in 0..<iterations {
                group.addTask { @Sendable in
                    var local = base // shared reference initially
                    local.modify { $0.append(i) }
                    return local.value
                }
            }

            var arrays: [[Int]] = []
            for try await arr in group {
                arrays.append(arr)
            }
            return arrays
        }

        // Base remains unchanged
        #expect(base.value.isEmpty)

        // Each result should contain exactly one element (its index)
        #expect(results.count == iterations)
        #expect(results.allSatisfy { $0.count == 1 })
    }
}
