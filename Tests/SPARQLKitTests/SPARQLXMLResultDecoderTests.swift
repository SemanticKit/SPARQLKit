import Foundation
import SPARQLKitTestSupport
import Testing
@testable import SPARQLKit

@Suite("SPARQL Query Results XML decoding", .tags(.decoding))
struct SPARQLXMLResultDecoderTests {
    let decoder = SPARQLXMLResultDecoder()

    @Test("Bindings decode into terms")
    func decodesBindings() throws {
        let result: SPARQLResultSet = try decoder.decode(try Fixture.data("select_result_xml.xml", in: .module))

        #expect(result.variables == ["name", "count"])
        #expect(result.bindings.count == 2)
        let first = try #require(result.bindings.first)
        #expect(first["name"] == (try literal("Alice", language: "en")))
        #expect(first["count"] == (.literal(try integer("3"))))
    }

    @Test("An ASK result decodes to its boolean")
    func decodesBoolean() throws {
        #expect(try (decoder.decode(try Fixture.data("ask_result_true.xml", in: .module)) as SPARQLQueryResult) == .boolean(true))
    }

    @Test("Asking for bindings from a boolean document fails")
    func bindingsFromBooleanFails() throws {
        let data = try Fixture.data("ask_result_true.xml", in: .module)
        #expect(throws: SPARQLError.decodingFailure("Expected bindings payload, found boolean ASK result.")) {
            _ = try decoder.decode(data) as SPARQLResultSet
        }
    }

    @Test("A boolean that is neither true nor false is rejected")
    func invalidBooleanFails() {
        let data = Data(#"<?xml version="1.0"?><sparql xmlns="http://www.w3.org/2005/sparql-results#"><head/><boolean>yes</boolean></sparql>"#.utf8)
        #expect(throws: SPARQLError.decodingFailure("<boolean> holds 'yes', not true or false.")) {
            _ = try (decoder.decode(data) as SPARQLQueryResult)
        }
    }

    @Test("A document with both a boolean and results is rejected")
    func mixedDocumentFails() throws {
        let data = try Fixture.data("invalid_mixed_result.xml", in: .module)
        #expect(throws: SPARQLError.decodingFailure("Invalid mixed XML result payload.")) {
            _ = try (decoder.decode(data) as SPARQLQueryResult)
        }
    }

    @Test("Triple terms and directional literals decode")
    func decodesTripleTermsAndDirections() throws {
        let row = try #require(try decoder.decode(try Fixture.data("select_result_xml_triple_terms.xml", in: .module)).bindings.first)

        #expect(row["triple"] == triple("http://example.org/alice", "http://example.org/name", try literal("Alice")))
        #expect(row["label"] == (try literal("chat", language: "fr", direction: .ltr)))
    }

    @Test("Unicode lexical forms are kept")
    func keepsUnicode() throws {
        let payload = """
        <?xml version="1.0" encoding="UTF-8"?>
        <sparql xmlns="http://www.w3.org/2005/sparql-results#">
          <head><variable name="label"/></head>
          <results><result><binding name="label"><literal xml:lang="ar">مرحبا</literal></binding></result></results>
        </sparql>
        """
        let first = try #require(try decoder.decode(Data(payload.utf8)).bindings.first)
        #expect(first["label"] == (try literal("مرحبا", language: "ar")))
    }

    @Test("A relative IRI is rejected as it enters")
    func rejectsRelativeIRI() {
        let payload = """
        <?xml version="1.0"?>
        <sparql xmlns="http://www.w3.org/2005/sparql-results#">
          <head><variable name="x"/></head>
          <results><result><binding name="x"><uri>relative/iri</uri></binding></result></results>
        </sparql>
        """
        #expect(throws: SPARQLError.decodingFailure("<relative/iri> is not an absolute IRI.")) {
            _ = try decoder.decode(Data(payload.utf8)) as SPARQLResultSet
        }
    }
}
