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

private struct Contents: Sendable, Equatable, Hashable, Codable {
    var title = ""
    var paragraphs: [String] = []
}

private struct Document: Sendable, Equatable, Hashable, Codable {
    @CopyOnWrite var contents = Contents()
    var revision = 0

    mutating func append(_ paragraphs: String...) -> Int {
        _contents.modify { contents in
            contents.paragraphs.append(contentsOf: paragraphs)
            return contents.paragraphs.count
        }
    }
}

@Suite("Property wrapper")
struct PropertyWrapperTests {
    @Test("Wrapped properties keep value semantics")
    func valueSemantics() {
        var draft = Document(contents: Contents(title: "Draft"))
        let snapshot = draft
        #expect(draft.$contents === snapshot.$contents)

        draft.contents.title = "Final"
        draft.contents.paragraphs.append("Hello")

        #expect(draft.contents == Contents(title: "Final", paragraphs: ["Hello"]))
        #expect(snapshot.contents == Contents(title: "Draft"))
        #expect(draft.$contents !== snapshot.$contents)
    }

    @Test("Default values and memberwise initializers work")
    func initialization() {
        #expect(Document().contents == Contents())
        #expect(Document(contents: Contents(title: "A"), revision: 2).contents.title == "A")
    }

    @Test("The declaring type can modify the underlying wrapper")
    func modifyFromDeclaringType() {
        var draft = Document()
        let snapshot = draft

        let count = draft.append("One", "Two")

        #expect(count == 2)
        #expect(draft.contents.paragraphs == ["One", "Two"])
        #expect(snapshot.contents.paragraphs.isEmpty)
    }

    @Test("Synthesized conformances see through the wrapper")
    func synthesizedConformances() {
        let a = Document(contents: Contents(title: "A"))
        let b = Document(contents: Contents(title: "A"))
        let c = Document(contents: Contents(title: "C"))

        #expect(a == b)
        #expect(a != c)
        #expect(a.hashValue == b.hashValue)
        #expect(Set([a, b, c]).count == 2)
    }

    @Test("Wrapped properties can cross isolation boundaries")
    func sendable() async {
        let document = Document(contents: Contents(title: "Shared"))

        let title = await Task.detached {
            var local = document
            local.contents.title += "!"
            return local.contents.title
        }.value

        #expect(title == "Shared!")
        #expect(document.contents.title == "Shared")
    }
}
