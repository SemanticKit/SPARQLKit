import Testing
import IRIKit
import RDFCore
@testable import SPARQLKit

@Suite("Result terms are RDFCore terms", .tags(.resultTerms))
struct ObjectTermResultsTests {
    @Test("Equal literals read from results are one RDFCore term")
    func equalLiterals() throws {
        let a = try ObjectTerm(literal: "chat", language: "FR", direction: .ltr)
        let b = try ObjectTerm(literal: "chat", language: "fr", direction: .ltr)
        #expect(a == b)
        #expect(Set([a, b]).count == 1)
        #expect(a == .literal(try Literal("chat", languageTag: "fr", baseDirection: .ltr)))
    }

    @Test("The base direction distinguishes directional literals")
    func baseDirections() throws {
        let ltr = try ObjectTerm(literal: "chat", language: "fr", direction: .ltr)
        let rtl = try ObjectTerm(literal: "chat", language: "fr", direction: .rtl)
        let none = try ObjectTerm(literal: "chat", language: "fr")
        #expect(Set([ltr, rtl, none]).count == 3)
    }

    @Test("A literal typed xsd:string is the simple literal")
    func xsdString() throws {
        let typed = try ObjectTerm(literal: "Alice", datatype: "http://www.w3.org/2001/XMLSchema#string")
        #expect(typed == .literal(Literal("Alice")))
    }

    @Test("A triple term is RDFCore's triple in object position")
    func tripleTerm() throws {
        let term = try ObjectTerm(
            subject: ObjectTerm(iri: "http://example.org/s"),
            predicate: ObjectTerm(iri: "http://example.org/p"),
            object: ObjectTerm(literal: "o")
        )
        let triple = Graph.Element(subject: .iri("http://example.org/s"), predicate: "http://example.org/p", object: .literal(Literal("o")))
        #expect(term == .tripleTerm(triple))
    }

    @Test("A triple term needs a node subject and an IRI predicate")
    func malformedTripleTerm() throws {
        let literal = try ObjectTerm(literal: "o")
        let iri = try ObjectTerm(iri: "http://example.org/p")
        #expect(throws: SPARQLError.self) { try ObjectTerm(subject: literal, predicate: iri, object: iri) }
        #expect(throws: SPARQLError.self) { try ObjectTerm(subject: iri, predicate: literal, object: iri) }
    }

    @Test("Malformed result terms are rejected")
    func malformedInput() {
        #expect(throws: Error.self) { try ObjectTerm(iri: "") }
        #expect(throws: Error.self) { try ObjectTerm(blankNodeLabel: "") }
        #expect(throws: Error.self) { try ObjectTerm(literal: "hello", language: "") }
        #expect(throws: Error.self) { try ObjectTerm(literal: "hello", direction: .ltr) }
        #expect(throws: Error.self) { try ObjectTerm(literal: "hello", datatype: "relative/type") }
        #expect(throws: Error.self) { try ObjectTerm(literal: "hello", datatype: "http://www.w3.org/1999/02/22-rdf-syntax-ns#langString") }
    }
}
