import Foundation
import Testing
@testable import SPARQLKit

@Suite("SPARQL Query Results JSON decoding", .tags(.decoding))
struct SPARQLJSONResultDecoderTests {
    let decoder = SPARQLJSONResultDecoder()

    @Test("Bindings decode into terms")
    func decodesBindings() throws {
        let result: SPARQLResultSet = try decoder.decode(try fixture("select_result.json"))

        #expect(result.variables == ["name", "count"])
        #expect(result.bindings.count == 3)
        let first = try #require(result.bindings.first)
        #expect(first["name"] == (try literal("Alice")))
        #expect(first["count"] == (try literal("3", datatype: xsdInteger)))
    }

    @Test("An ASK result decodes to its boolean")
    func decodesBoolean() throws {
        #expect(try (decoder.decode(try fixture("ask_result_true.json")) as SPARQLQueryResult) == .boolean(true))
    }

    @Test("An ASK result whose head has no vars decodes")
    func askWithEmptyHead() throws {
        #expect(try (decoder.decode(Data(#"{"head":{},"boolean":false}"#.utf8)) as SPARQLQueryResult) == .boolean(false))
    }

    @Test("Asking for bindings from a boolean document fails")
    func bindingsFromBooleanFails() throws {
        let data = try fixture("ask_result_true.json")
        #expect(throws: SPARQLError.decodingFailure("Expected bindings payload, found boolean ASK result.")) {
            _ = try decoder.decode(data) as SPARQLResultSet
        }
    }

    @Test("A document with both a boolean and results is rejected")
    func mixedDocumentFails() throws {
        let data = try fixture("invalid_mixed_result.json")
        #expect(throws: SPARQLError.decodingFailure("Invalid mixed JSON result payload.")) {
            _ = try (decoder.decode(data) as SPARQLQueryResult)
        }
    }

    @Test("IRIs, blank nodes, language-tagged and typed literals decode")
    func decodesEveryTermKind() throws {
        let result: SPARQLResultSet = try decoder.decode(try fixture("term_coverage_result.json"))

        #expect(result.variables == ["u", "b", "lang", "typed"])
        let first = try #require(result.bindings.first)
        #expect(first["u"] == iri("http://example.org/resource"))
        #expect(try first["b"] == blank("node1"))
        #expect(first["lang"] == (try literal("hello", language: "en")))
        #expect(first["typed"] == (try literal("42", datatype: xsdInteger)))
    }

    @Test("Triple terms and directional literals decode; xsd:string is a simple literal")
    func decodesTripleTermsAndDirections() throws {
        let row = try #require(try decoder.decode(try fixture("select_result_json_triple_terms.json")).bindings.first)

        #expect(row["triple"] == triple("http://example.org/alice", "http://example.org/name", try literal("Alice")))
        #expect(row["label"] == (try literal("chat", language: "fr", direction: .ltr)))
    }

    @Test("The version comes from the document, else from the media type")
    func decodesVersion() throws {
        #expect(try decoder.decode(try fixture("select_result_with_version.json")).version == "1.2")

        let fromDocument = try decoder.decode(try fixture("ask_result_true_with_version.json"), contentType: nil)
        #expect(fromDocument.version == "1.2")
        #expect(fromDocument.result == .boolean(true))

        let fromMediaType = try decoder.decode(
            try fixture("ask_result_true.json"),
            contentType: "application/sparql-results+json; charset=utf-8; version=1.2"
        )
        #expect(fromMediaType.version == "1.2")

        let preferred = try decoder.decode(
            try fixture("ask_result_true_with_version.json"),
            contentType: "application/sparql-results+json; version=1.1"
        )
        #expect(preferred.version == "1.2")
    }

    @Test("Unicode lexical forms are kept")
    func keepsUnicode() throws {
        let payload = #"{"head":{"vars":["label"]},"results":{"bindings":[{"label":{"type":"literal","xml:lang":"ja","value":"こんにちは世界"}}]}}"#
        let first = try #require(try decoder.decode(Data(payload.utf8)).bindings.first)
        #expect(first["label"] == (try literal("こんにちは世界", language: "ja")))
    }

    @Test("Malformed terms are rejected as they enter", arguments: [
        #"{"type":"uri","value":"relative/iri"}"#,
        #"{"type":"bnode","value":""}"#,
        #"{"type":"literal","value":"x","xml:lang":""}"#,
        #"{"type":"literal","value":"x","its:dir":"ltr"}"#,
        #"{"type":"literal","value":"x","xml:lang":"en","its:dir":"up"}"#,
        #"{"type":"literal","value":"x","datatype":"http://www.w3.org/1999/02/22-rdf-syntax-ns#langString"}"#,
        #"{"type":"typed-literal","value":"x"}"#,
        #"{"type":"triple","value":{"subject":{"type":"literal","value":"s"},"predicate":{"type":"uri","value":"http://example.org/p"},"object":{"type":"uri","value":"http://example.org/o"}}}"#
    ])
    func rejectsMalformedTerms(term: String) {
        let payload = #"{"head":{"vars":["x"]},"results":{"bindings":[{"x":"# + term + "}]}}"
        #expect(throws: SPARQLError.self) {
            _ = try decoder.decode(Data(payload.utf8)) as SPARQLResultSet
        }
    }
}
