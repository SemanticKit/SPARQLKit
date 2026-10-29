import Foundation
import Testing
import IRIKit
import RDFCore
@testable import SPARQLKit

@Test
func jsonResultDecoderParsesBindings() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "select_result", withExtension: "json"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLJSONResultDecoder()
    let result = try decoder.decode(data)

    #expect(result.variables == [Variable(rawValue: "name"), Variable(rawValue: "count")])
    #expect(result.bindings.count == 3)

    let first = try #require(result.bindings.first)
    let expectedName = try ObjectTerm(literal: "Alice")
    #expect(first[Variable(rawValue: "name")] == expectedName)
    let expectedCount = try ObjectTerm(
        literal: "3",
        datatype: "http://www.w3.org/2001/XMLSchema#integer"
    )
    #expect(first[Variable(rawValue: "count")] == expectedCount)
}

@Test
func jsonResultDecoderParsesBooleanAskResult() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "ask_result_true", withExtension: "json"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLJSONResultDecoder()
    let result = try decoder.decodeQueryResult(data)

    #expect(result == .boolean(true))
}

@Test
func jsonBindingsDecodeRejectsBooleanPayload() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "ask_result_true", withExtension: "json"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLJSONResultDecoder()

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
func jsonResultDecoderRejectsMixedPayload() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "invalid_mixed_result", withExtension: "json"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLJSONResultDecoder()

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
func jsonResultDecoderParsesAllTermKinds() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "term_coverage_result", withExtension: "json"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLJSONResultDecoder()
    let result = try decoder.decode(data)

    #expect(result.variables == [
        Variable(rawValue: "u"),
        Variable(rawValue: "b"),
        Variable(rawValue: "lang"),
        Variable(rawValue: "typed")
    ])

    let first = try #require(result.bindings.first)
    let expectedURI = try ObjectTerm(iri: "http://example.org/resource")
    let expectedBlankNode = try ObjectTerm(blankNodeLabel: "node1")
    let expectedLang = try ObjectTerm(literal: "hello", language: "en")
    let expectedTyped = try ObjectTerm(literal: "42", datatype: "http://www.w3.org/2001/XMLSchema#integer")

    #expect(first[Variable(rawValue: "u")] == expectedURI)
    #expect(first[Variable(rawValue: "b")] == expectedBlankNode)
    #expect(first[Variable(rawValue: "lang")] == expectedLang)
    #expect(first[Variable(rawValue: "typed")] == expectedTyped)
}

@Test
func jsonResultDecoderParsesTripleTermsAndDirectionalLiterals() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "select_result_json_triple_terms", withExtension: "json"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLJSONResultDecoder()
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
func jsonResultDecoderSurfacesVersionForBindingsResults() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "select_result_with_version", withExtension: "json"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLJSONResultDecoder()
    let result = try decoder.decode(data)

    #expect(result.version == "1.2")
    #expect(result.bindings.count == 1)
}

@Test
func jsonResultDecoderSurfacesVersionForBooleanResults() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "ask_result_true_with_version", withExtension: "json"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLJSONResultDecoder()
    let decoded = try decoder.decodeQueryResultWithMetadata(data)

    #expect(decoded.version == "1.2")
    #expect(decoded.result == .boolean(true))
}

@Test
func jsonResultDecoderSurfacesVersionFromContentTypeParameter() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "ask_result_true", withExtension: "json"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLJSONResultDecoder()
    let decoded = try decoder.decodeQueryResultWithMetadata(
        data,
        contentType: "application/sparql-results+json; charset=utf-8; version=1.2"
    )

    #expect(decoded.version == "1.2")
    #expect(decoded.result == .boolean(true))
}

@Test
func jsonResultDecoderPrefersPayloadVersionOverContentTypeVersion() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "ask_result_true_with_version", withExtension: "json"))
    let data = try Data(contentsOf: fixtureURL)

    let decoder = SPARQLJSONResultDecoder()
    let decoded = try decoder.decodeQueryResultWithMetadata(
        data,
        contentType: "application/sparql-results+json; version=1.1"
    )

    #expect(decoded.version == "1.2")
    #expect(decoded.result == .boolean(true))
}

@Test
func jsonResultDecoderPreservesUnicodeLanguageLiteralContent() throws {
    let payload = """
    {
      "head": { "vars": ["label"] },
      "results": {
        "bindings": [
          { "label": { "type": "literal", "xml:lang": "ja", "value": "こんにちは世界" } }
        ]
      }
    }
    """
    let data = Data(payload.utf8)

    let decoder = SPARQLJSONResultDecoder()
    let result = try decoder.decode(data)
    let first = try #require(result.bindings.first)
    let expected = try ObjectTerm(literal: "こんにちは世界", language: "ja")
    #expect(first[Variable(rawValue: "label")] == expected)
}
