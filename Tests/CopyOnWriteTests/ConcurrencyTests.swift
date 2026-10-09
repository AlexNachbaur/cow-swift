//
// Copyright (c) 2026, Alexandra Nachbaur. All rights reserved.
//
// This source file is part of the cow-swift open source project.
// Licensed under the Apache License, Version 2.0. See LICENSE for details.
//
// SPDX-License-Identifier: Apache-2.0
//

import CopyOnWrite
import Testing

/// These tests are most valuable when run with the thread sanitizer: `swift test --sanitize=thread`.
@Suite("Concurrency")
struct ConcurrencyTests {
    @Test("Concurrent tasks mutating their own copies do not affect the original")
    func concurrentMutationOfCopies() async {
        let base = CopyOnWrite([Int]())
        let iterations = 200

        let results = await withTaskGroup(of: [Int].self) { group in
            for i in 0..<iterations {
                group.addTask {
                    var local = base  // shares storage with every other task
                    local.modify { $0.append(i) }
                    return local.value
                }
            }

            var arrays: [[Int]] = []
            for await array in group {
                arrays.append(array)
            }
            return arrays
        }

        #expect(base.value.isEmpty)
        #expect(results.count == iterations)
        #expect(results.allSatisfy { $0.count == 1 })
        #expect(Set(results.map { $0[0] }) == Set(0..<iterations))
    }

    @Test("Readers and writers can share storage across tasks")
    func concurrentReadersAndWriters() async {
        let base = CopyOnWrite(Array(0..<1_000))
        let expectedSum = (0..<1_000).reduce(0, +)

        await withTaskGroup(of: Void.self) { group in
            for task in 0..<16 {
                group.addTask {
                    for round in 0..<500 {
                        if task.isMultiple(of: 2) {
                            // Readers only ever see the original contents.
                            #expect(base.value.count == 1_000)
                            #expect(base.value.reduce(0, +) == expectedSum)
                        } else {
                            // Writers repeatedly take a fresh copy, mutate it, and drop it.
                            var local = base
                            local.value.append(round)
                            local.value[0] = -1
                            #expect(local.value.count == 1_001)
                        }
                    }
                }
            }
        }

        #expect(base.value == Array(0..<1_000))
    }

    @Test("A copy handed to another task diverges from the one kept behind")
    func handOffBetweenTasks() async {
        var kept = CopyOnWrite(["start"])

        // The child task and this one mutate copies that begin by sharing storage, at the same time.
        let sent = kept
        async let theirs = Self.appending(1_000, to: sent)

        for i in 0..<1_000 {
            kept.value.append("ours \(i)")
        }

        let received = await theirs
        #expect(kept.value.count == 1_001)
        #expect(received.value.count == 1_001)
        #expect(kept.value.dropFirst().allSatisfy { $0.hasPrefix("ours") })
        #expect(received.value.dropFirst().allSatisfy { $0.hasPrefix("theirs") })
    }

    private static func appending(_ count: Int, to wrapper: CopyOnWrite<[String]>) async -> CopyOnWrite<[String]> {
        var wrapper = wrapper
        for i in 0..<count {
            wrapper.value.append("theirs \(i)")
        }
        return wrapper
    }
}
