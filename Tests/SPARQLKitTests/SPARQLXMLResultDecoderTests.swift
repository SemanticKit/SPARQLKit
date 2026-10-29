import Foundation
import Testing
import IRIKit
import RDFCore
@testable import SPARQLKit

@Test
func xmlResultDecoderParsesBindings() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "select_result_xml", withExtension: "xml"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLXMLResultDecoder()
    let result = try decoder.decode(data)

    #expect(result.variables == [Variable(rawValue: "name"), Variable(rawValue: "count")])
    #expect(result.bindings.count == 2)

    let first = try #require(result.bindings.first)
    let expectedName = try ObjectTerm(literal: "Alice", language: "en")
    let expectedCount = try ObjectTerm(literal: "3", datatype: "http://www.w3.org/2001/XMLSchema#integer")
    #expect(first[Variable(rawValue: "name")] == expectedName)
    #expect(first[Variable(rawValue: "count")] == expectedCount)
}

@Test
func xmlResultDecoderParsesBooleanAskResult() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "ask_result_true", withExtension: "xml"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLXMLResultDecoder()
    let result = try decoder.decodeQueryResult(data)

    #expect(result == .boolean(true))
}

@Test
func xmlBindingsDecodeRejectsBooleanPayload() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "ask_result_true", withExtension: "xml"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLXMLResultDecoder()

    do {
        _ = try decoder.decode(data)
        Issue.record("Expected decoder to reject boolean payload for bindings decode.")
    } catch let error as SPARQLError {
        if case .decodingFailure = error {
            #expect(Bool(true))
        } else {
            Issue.record("Expected decodingFailure but got: \(error)")
        }
    }
}

@Test
func xmlResultDecoderRejectsMixedPayload() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "invalid_mixed_result", withExtension: "xml"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLXMLResultDecoder()

    do {
        _ = try decoder.decodeQueryResult(data)
        Issue.record("Expected decoder to reject mixed boolean/results payload.")
    } catch let error as SPARQLError {
        if case .decodingFailure = error {
            #expect(Bool(true))
        } else {
            Issue.record("Expected decodingFailure but got: \(error)")
        }
    }
}

@Test
func xmlResultDecoderParsesTripleTermsAndDirectionalLiterals() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "select_result_xml_triple_terms", withExtension: "xml"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLXMLResultDecoder()
    let result = try decoder.decode(data)
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
func xmlResultDecoderPreservesUnicodeLanguageLiteralContent() throws {
    let payload = """
    <?xml version="1.0" encoding="UTF-8"?>
    <sparql xmlns="http://www.w3.org/2005/sparql-results#">
      <head><variable name="label"/></head>
      <results>
        <result>
          <binding name="label"><literal xml:lang="ar">مرحبا</literal></binding>
        </result>
      </results>
    </sparql>
    """
    let data = Data(payload.utf8)

    let decoder = SPARQLXMLResultDecoder()
    let result = try decoder.decode(data)
    let first = try #require(result.bindings.first)
    let expected = try ObjectTerm(literal: "مرحبا", language: "ar")
    #expect(first[Variable(rawValue: "label")] == expected)
}
