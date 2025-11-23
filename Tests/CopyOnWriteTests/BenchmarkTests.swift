//
//  BenchmarkTests.swift
//  swift-cow
//
//  Created by Alex Nachbaur on 2025-11-22.
//

import Testing
@testable import CopyOnWrite

fileprivate struct TestValue: Sendable, Equatable {
    var firstName: String
    var lastName: String
}

@Suite("Benchmark Tests")
struct BenchmarkTests {
    @Test("Benchmark append with modify")
    func testBenchmarkAppendWithModify() async throws {
        let iterations = 5_000
        let clock = ContinuousClock()
        let start = clock.now

        var totalCount = 0
        for i in 0..<iterations {
            let shared = CopyOnWrite([Int]())
            var local = shared
            local.modify { $0.append(i) }
            totalCount += local.value.count
        }

        let duration = start.duration(to: clock.now)
        let nanos = Double(duration.components.attoseconds) / 1_000_000_000.0
        #expect(totalCount == iterations)

        print("[Benchmark] modify append x\(iterations): ~\(nanos) ns (attoseconds/1e9)")
    }

    @Test("Benchmark read heavy, no copy")
    func testBenchmarkReadHeavyNoCopy() async throws {
        let iterations = 100_000
        let large = Array(0..<1_000)
        let cow = CopyOnWrite(large)

        let clock = ContinuousClock()
        let start = clock.now

        var sum = 0
        for _ in 0..<iterations {
            // Reading .value should not trigger a copy
            sum &+= cow.value.count
        }

        let duration = start.duration(to: clock.now)
        let nanos = Double(duration.components.attoseconds) / 1_000_000_000.0
        #expect(sum == iterations * large.count)
        print("[Benchmark] read count x\(iterations): ~\(nanos) ns (attoseconds/1e9)")
    }
}
