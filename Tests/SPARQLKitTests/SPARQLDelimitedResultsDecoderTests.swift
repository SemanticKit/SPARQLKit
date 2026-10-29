import Foundation
import Testing
import IRIKit
import RDFCore
@testable import SPARQLKit

@Test
func csvDecoderParsesBindings() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "select_result_csv", withExtension: "csv"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLDelimitedResultsDecoder()
    let result = try decoder.decodeCSV(data)

    #expect(result.variables == [Variable(rawValue: "name"), Variable(rawValue: "count")])
    #expect(result.bindings.count == 3)

    let first = try #require(result.bindings.first)
    let expectedName = try ObjectTerm(literal: "Alice")
    let expectedCount = try ObjectTerm(literal: "3")
    #expect(first[Variable(rawValue: "name")] == expectedName)
    #expect(first[Variable(rawValue: "count")] == expectedCount)
}

@Test
func tsvDecoderParsesBindings() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "select_result_tsv", withExtension: "tsv"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLDelimitedResultsDecoder()
    let result = try decoder.decodeTSV(data)

    #expect(result.variables == [Variable(rawValue: "name"), Variable(rawValue: "count")])
    #expect(result.bindings.count == 3)

    let first = try #require(result.bindings.first)
    let expectedName = try ObjectTerm(literal: "Alice")
    let expectedCount = try ObjectTerm(literal: "3")
    #expect(first[Variable(rawValue: "name")] == expectedName)
    #expect(first[Variable(rawValue: "count")] == expectedCount)
}

@Test
func csvDecoderHandlesQuotedFieldsAndUnboundCells() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "select_result_csv_edge", withExtension: "csv"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLDelimitedResultsDecoder()
    let result = try decoder.decodeCSV(data)

    #expect(result.bindings.count == 2)

    let first = try #require(result.bindings.first)
    let expectedQuotedName = try ObjectTerm(literal: "Alice, A.")
    let expectedQuotedNote = try ObjectTerm(literal: "He said \"hi\"")
    #expect(first[Variable(rawValue: "name")] == expectedQuotedName)
    #expect(first[Variable(rawValue: "note")] == expectedQuotedNote)

    let second = try #require(result.bindings.last)
    #expect(second[Variable(rawValue: "count")] == nil)
    #expect(second[Variable(rawValue: "note")] == nil)
}

@Test
func tsvDecoderParsesTypedLanguageAndNodeTerms() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "select_result_tsv_terms", withExtension: "tsv"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLDelimitedResultsDecoder()
    let result = try decoder.decodeTSV(data)

    let row = try #require(result.bindings.first)
    let expectedIRI = try ObjectTerm(iri: "http://example.org/r")
    let expectedBNode = try ObjectTerm(blankNodeLabel: "b1")
    let expectedLang = try ObjectTerm(literal: "bonjour", language: "fr")
    let expectedTyped = try ObjectTerm(literal: "42", datatype: "http://www.w3.org/2001/XMLSchema#integer")
    let expectedPlain = try ObjectTerm(literal: "text")
    #expect(row[Variable(rawValue: "iri")] == expectedIRI)
    #expect(row[Variable(rawValue: "bnode")] == expectedBNode)
    #expect(row[Variable(rawValue: "lang")] == expectedLang)
    #expect(row[Variable(rawValue: "typed")] == expectedTyped)
    #expect(row[Variable(rawValue: "plain")] == expectedPlain)
}

@Test
func tsvDecoderParsesTripleTermsAndDirectionalLiterals() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "select_result_tsv_triple_terms", withExtension: "tsv"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLDelimitedResultsDecoder()
    let result = try decoder.decodeTSV(data)
    let row = try #require(result.bindings.first)

    let expectedTriple = ObjectTerm.tripleTerm(
        Graph.Element(
            subject: .iri(try IRI(validating: "http://example.org/alice")),
            predicate: try IRI(validating: "http://example.org/name"),
            object: try ObjectTerm(literal: "Alice", datatype: "http://www.w3.org/2001/XMLSchema#string")
        )
    )
    let expectedDirectionalLiteral = try ObjectTerm(literal: "chat", language: "fr", direction: .ltr)

    #expect(row[Variable(rawValue: "triple")] == expectedTriple)
    #expect(row[Variable(rawValue: "label")] == expectedDirectionalLiteral)
}

@Test
func csvDecoderNormalizesTermSyntaxIncludingTripleTerms() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "select_result_csv_terms", withExtension: "csv"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLDelimitedResultsDecoder()
    let result = try decoder.decodeCSV(data, normalizeTerms: true)
    let row = try #require(result.bindings.first)

    let expectedIRI = try ObjectTerm(iri: "http://example.org/r")
    let expectedBNode = try ObjectTerm(blankNodeLabel: "b1")
    let expectedTyped = try ObjectTerm(literal: "42", datatype: "http://www.w3.org/2001/XMLSchema#integer")
    let expectedTriple = ObjectTerm.tripleTerm(
        Graph.Element(
            subject: .iri(try IRI(validating: "http://example.org/alice")),
            predicate: try IRI(validating: "http://example.org/name"),
            object: try ObjectTerm(literal: "Alice", datatype: "http://www.w3.org/2001/XMLSchema#string")
        )
    )
    let expectedDirectionalLiteral = try ObjectTerm(literal: "chat", language: "fr", direction: .ltr)

    #expect(row[Variable(rawValue: "iri")] == expectedIRI)
    #expect(row[Variable(rawValue: "bnode")] == expectedBNode)
    #expect(row[Variable(rawValue: "typed")] == expectedTyped)
    #expect(row[Variable(rawValue: "triple")] == expectedTriple)
    #expect(row[Variable(rawValue: "label")] == expectedDirectionalLiteral)
}

@Test
func tsvDecoderPreservesUnicodeLanguageLiteralContent() throws {
    let payload = """
    ?label
    "γειά σου"@el
    """
    let data = Data(payload.utf8)

    let decoder = SPARQLDelimitedResultsDecoder()
    let result = try decoder.decodeTSV(data)
    let first = try #require(result.bindings.first)
    let expected = try ObjectTerm(literal: "γειά σου", language: "el")
    #expect(first[Variable(rawValue: "label")] == expected)
}
