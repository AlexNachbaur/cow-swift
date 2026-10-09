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

import CopyOnWrite
import Testing

private struct TestValue: Sendable, Equatable {
    var firstName: String
    var lastName: String
}

@Suite("CopyOnWrite Tests")
struct CopyOnWriteTests {
    @Test("Basic object copy tests")
    func copiedObjects() async throws {
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

    @Test("Mutating a shared value copies it first")
    func mutationCopiesWhenShared() {
        let a = CopyOnWrite([1, 2, 3])
        var b = a
        #expect(a === b)

        b.value.append(4)
        #expect(a !== b)
        #expect(a.value == [1, 2, 3])
        #expect(b.value == [1, 2, 3, 4])
    }

    @Test("Assigning a shared value leaves other copies untouched")
    func assignmentWhenShared() {
        let a = CopyOnWrite([1, 2, 3])
        var b = a

        b.value = [9]
        #expect(a !== b)
        #expect(a.value == [1, 2, 3])
        #expect(b.value == [9])
    }

    @Test("Assigning a uniquely referenced value keeps its storage")
    func assignmentWhenUnique() {
        var a = CopyOnWrite([1, 2, 3])
        a.value = [9]
        #expect(a.value == [9])

        let b = a
        #expect(a === b)
    }

    @Test("Modify ensures uniqueness and batches")
    func modifyEnsuresUniquenessAndBatches() {
        var a = CopyOnWrite(["a"])
        let b = a
        #expect(a === b)

        a.modify { arr in
            arr.append("b")
            arr.append("c")
        }

        #expect(a !== b)
        #expect(a.value == ["a", "b", "c"])
        #expect(b.value == ["a"])
    }

    @Test("Modify returns the closure's result")
    func modifyReturnsResult() {
        var numbers = CopyOnWrite([3, 1, 2])
        let largest = numbers.modify { numbers in
            numbers.sort()
            return numbers.removeLast()
        }

        #expect(largest == 3)
        #expect(numbers.value == [1, 2])
    }

    @Test("Modify can read other copies of the same value")
    func modifyCanReadSiblingCopies() {
        var a = CopyOnWrite([1, 2, 3])
        let b = a

        a.modify { $0.append(b.value.count) }

        #expect(a.value == [1, 2, 3, 3])
        #expect(b.value == [1, 2, 3])
    }

    @Test("Modify propagates typed errors and keeps mutations")
    func modifyThrowsPropagatesAndKeepsMutations() {
        struct Failure: Error, Equatable {}
        var value = CopyOnWrite([1])

        do throws(Failure) {
            try value.modify { (arr: inout [Int]) throws(Failure) in
                arr.append(2)
                throw Failure()
            }
            Issue.record("Should have thrown")
        } catch {
            // The annotation proves the error type is preserved, rather than erased to `any Error`.
            let failure: Failure = error
            #expect(failure == Failure())
        }

        #expect(value.value == [1, 2])
    }

    @Test("Identity operators chain")
    func identityOperatorsChain() {
        let a = CopyOnWrite([0])
        let b = a
        var c = b
        #expect(a === b)
        #expect(b === c)
        #expect(a.isIdentical(to: c))

        // Mutate c; only c should diverge
        c.value.append(1)
        #expect(a === b)
        #expect(a !== c)
        #expect(b !== c)
        #expect(!a.isIdentical(to: c))
    }

    @Test("Separately created wrappers are never identical")
    func separateWrappersAreNotIdentical() {
        let a = CopyOnWrite([0])
        let b = CopyOnWrite([0])
        #expect(a !== b)
        #expect(a == b)
    }

    @Test("Dynamic member lookup reads and writes members")
    func dynamicMemberLookup() {
        var jane = CopyOnWrite(TestValue(firstName: "Jane", lastName: "Doe"))
        let original = jane
        #expect(jane.firstName == "Jane")

        jane.firstName = "John"
        #expect(jane.firstName == "John")
        #expect(jane.value == TestValue(firstName: "John", lastName: "Doe"))
        #expect(original.firstName == "Jane")
        #expect(jane !== original)

        // Read-only members are available too.
        let numbers = CopyOnWrite([1, 2, 3])
        #expect(numbers.count == 3)
    }

    @Test("Reference type payload shares interior mutability")
    func referenceTypePayloadSharesInteriorMutability() {
        final class Box {
            var i: Int
            init(_ i: Int) { self.i = i }
        }

        let a = CopyOnWrite(Box(1))
        var b = a
        #expect(a === b)

        // Mutating the inner reference type mutates both views
        b.value.i = 2
        #expect(a.value.i == 2)
        #expect(b.value.i == 2)

        // Replacing the object gives `b` its own storage, and its own object
        b.value = Box(3)
        #expect(a !== b)
        #expect(a.value.i == 2)
        #expect(b.value.i == 3)
    }
}
