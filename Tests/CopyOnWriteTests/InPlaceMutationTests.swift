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

/// A value that can report whether a hidden copy of it currently exists.
///
/// Every copy of a `Probe` retains the same token, so the token is uniquely referenced only while
/// exactly one copy of the probe is alive.
private struct Probe {
    private final class Token {}

    private var token = Token()
    var count = 0

    mutating func isOnlyCopy() -> Bool {
        isKnownUniquelyReferenced(&token)
    }
}

private struct Holder {
    @CopyOnWrite var probe = Probe()

    mutating func modifyStorage<Output>(_ body: (inout Probe) -> Output) -> Output {
        _probe.modify(body)
    }
}

/// These tests pin down the performance contract: mutating a uniquely referenced wrapper never
/// copies the wrapped value, whichever API performs the mutation.
@Suite("In-place mutation")
struct InPlaceMutationTests {
    @Test("Mutating through value is in place")
    func valueIsInPlace() {
        var cow = CopyOnWrite(Probe())
        do {
            let isOnlyCopy = cow.value.isOnlyCopy()
            #expect(isOnlyCopy)
        }

        cow.value.count += 1
        do {
            let isOnlyCopy = cow.value.isOnlyCopy()
            #expect(isOnlyCopy)
        }
        #expect(cow.value.count == 1)
    }

    @Test("Mutating through modify is in place")
    func modifyIsInPlace() {
        var cow = CopyOnWrite(Probe())
        let wasOnlyCopy = cow.modify { $0.isOnlyCopy() }
        #expect(wasOnlyCopy)
    }

    @Test("Mutating through dynamic members is in place")
    func dynamicMemberIsInPlace() {
        var cow = CopyOnWrite(Probe())
        cow.count += 1
        do {
            let isOnlyCopy = cow.value.isOnlyCopy()
            #expect(isOnlyCopy)
        }
        #expect(cow.count == 1)
    }

    @Test("Mutating through a wrapped property is in place")
    func wrappedPropertyIsInPlace() {
        var holder = Holder()
        do {
            let isOnlyCopy = holder.probe.isOnlyCopy()
            #expect(isOnlyCopy)
        }

        holder.probe.count += 1
        do {
            let isOnlyCopy = holder.probe.isOnlyCopy()
            #expect(isOnlyCopy)
        }
    }

    @Test("Modifying a wrapped property's storage is in place")
    func wrappedPropertyStorageIsInPlace() {
        var holder = Holder()
        let wasOnlyCopy = holder.modifyStorage { $0.isOnlyCopy() }
        #expect(wasOnlyCopy)
    }

    @Test("Appending to a uniquely referenced array does not reallocate it")
    func arrayAppendDoesNotReallocate() {
        var cow = CopyOnWrite([Int]())
        cow.value.reserveCapacity(64)
        let before = cow.value.withUnsafeBufferPointer { $0.baseAddress }

        for i in 0..<64 {
            cow.value.append(i)
        }

        let after = cow.value.withUnsafeBufferPointer { $0.baseAddress }
        #expect(before == after)
        #expect(cow.value.count == 64)
    }

    @Test("A wrapper that has diverged mutates in place again")
    func divergedWrapperIsInPlace() {
        var cow = CopyOnWrite([Int]())
        cow.value.reserveCapacity(64)
        let snapshot = cow

        // The first mutation gives `cow` its own storage and its own array buffer…
        cow.value.append(0)
        #expect(cow !== snapshot)
        let before = cow.value.withUnsafeBufferPointer { $0.baseAddress }

        // …and later mutations reuse both, even though `snapshot` is still alive.
        for i in 1..<32 {
            cow.value.append(i)
        }
        let after = cow.value.withUnsafeBufferPointer { $0.baseAddress }

        #expect(before == after)
        #expect(cow.value == Array(0..<32))
        #expect(snapshot.value.isEmpty)
    }
}
