import Foundation
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

    @Test("A TSV directional literal keeps a language tag with subtags", arguments: [
        ("\"chat\"@en-US--ltr", "en-US", BaseDirection.ltr),
        ("\"chat\"@zh-Hant-TW--rtl", "zh-Hant-TW", BaseDirection.rtl),
        ("\"chat\"@en--ltr", "en", BaseDirection.ltr),
    ])
    func tsvDirectionalSubtags(_ cell: String, _ language: String, _ direction: BaseDirection) throws {
        let result = try SPARQLDelimitedResultsDecoder().decodeTSV(Data("?x\n\(cell)\n".utf8))
        let row = try #require(result.bindings.first)
        #expect(row[Variable(rawValue: "x")] == (try ObjectTerm(literal: "chat", language: language, direction: direction)))
    }

    @Test("A CSV directional literal keeps a language tag with subtags", arguments: [
        ("\"\"\"chat\"\"@en-US--ltr\"", "en-US", BaseDirection.ltr),
        ("\"\"\"chat\"\"@zh-Hant-TW--rtl\"", "zh-Hant-TW", BaseDirection.rtl),
    ])
    func csvDirectionalSubtags(_ cell: String, _ language: String, _ direction: BaseDirection) throws {
        let result = try SPARQLDelimitedResultsDecoder().decodeCSV(Data("x\n\(cell)\n".utf8), normalizeTerms: true)
        let row = try #require(result.bindings.first)
        #expect(row[Variable(rawValue: "x")] == (try ObjectTerm(literal: "chat", language: language, direction: direction)))
    }

    @Test("CSV rows end with CRLF, as the SPARQL CSV format writes them")
    func csvCRLF() throws {
        let result = try SPARQLDelimitedResultsDecoder().decodeCSV(Data("x\r\n\"\"\"chat\"\"@en-US--ltr\"\r\n".utf8), normalizeTerms: true)
        #expect(result.variables == [Variable(rawValue: "x")])
        let row = try #require(result.bindings.first)
        #expect(row[Variable(rawValue: "x")] == (try ObjectTerm(literal: "chat", language: "en-US", direction: .ltr)))
    }

    @Test("A delimited base direction other than ltr or rtl is an error")
    func delimitedMalformedDirection() {
        #expect(throws: SPARQLError.self) {
            try SPARQLDelimitedResultsDecoder().decodeTSV(Data("?x\n\"chat\"@en-US--auto\n".utf8))
        }
        #expect(throws: SPARQLError.self) {
            try SPARQLDelimitedResultsDecoder().decodeCSV(Data("x\n\"\"\"chat\"\"@en--auto\"\n".utf8), normalizeTerms: true)
        }
    }

    @Test("A JSON its:dir other than ltr or rtl is an error")
    func jsonMalformedDirection() {
        let document = #"{"head":{"vars":["x"]},"results":{"bindings":[{"x":{"type":"literal","value":"a","xml:lang":"en","its:dir":"auto"}}]}}"#
        #expect(throws: SPARQLError.self) {
            try SPARQLJSONResultDecoder().decode(Data(document.utf8))
        }
    }

    @Test("An XML its:dir other than ltr or rtl is an error")
    func xmlMalformedDirection() {
        let document = """
            <?xml version="1.0"?>
            <sparql xmlns="http://www.w3.org/2005/sparql-results#" xmlns:its="http://www.w3.org/2005/11/its">
              <head><variable name="x"/></head>
              <results><result><binding name="x"><literal xml:lang="en" its:dir="auto">a</literal></binding></result></results>
            </sparql>
            """
        #expect(throws: SPARQLError.self) {
            try SPARQLXMLResultDecoder().decode(Data(document.utf8))
        }
    }
}
