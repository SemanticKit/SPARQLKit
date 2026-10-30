import Foundation
import Testing
@testable import SPARQLKit

@Suite("SPARQL Query Results TSV decoding", .tags(.decoding))
struct SPARQLTSVResultDecoderTests {
    let decoder = SPARQLTSVResultDecoder()

    @Test("TSV fields are Turtle terms, numbers included")
    func tsvFieldsAreTurtleTerms() throws {
        let result = try decoder.decode(try fixture("select_result_tsv.tsv"))

        #expect(result.variables == ["name", "count"])
        #expect(result.bindings.count == 3)
        let first = try #require(result.bindings.first)
        #expect(first["name"] == (try literal("Alice")))
        #expect(first["count"] == (try literal("3", datatype: xsdInteger)))
    }

    @Test("TSV decodes IRIs, blank nodes, language-tagged and typed literals")
    func tsvDecodesEveryTermKind() throws {
        let row = try #require(try decoder.decode(try fixture("select_result_tsv_terms.tsv")).bindings.first)

        #expect(row["iri"] == iri("http://example.org/r"))
        #expect(try row["bnode"] == blank("b1"))
        #expect(row["lang"] == (try literal("bonjour", language: "fr")))
        #expect(row["typed"] == (try literal("42", datatype: xsdInteger)))
        #expect(row["plain"] == (try literal("text")))
    }

    @Test("TSV decodes triple terms and directional literals")
    func tsvDecodesTripleTerms() throws {
        let row = try #require(try decoder.decode(try fixture("select_result_tsv_triple_terms.tsv")).bindings.first)

        #expect(row["triple"] == triple("http://example.org/alice", "http://example.org/name", try literal("Alice")))
        #expect(row["label"] == (try literal("chat", language: "fr", direction: .ltr)))
    }

    @Test("TSV keeps a blank node label across rows")
    func tsvKeepsBlankNodeLabels() throws {
        let result = try decoder.decode(Data("?x\n_:b1\n_:b1\n".utf8))
        #expect(try result.bindings == [["x": blank("b1")], ["x": blank("b1")]])
    }

    @Test("TSV unescapes string escapes and keeps Unicode")
    func tsvUnescapes() throws {
        let result = try decoder.decode(Data("?label\n\"γειά σου\"@el\n\"tab\\there\"\n".utf8))
        #expect(result.bindings == [["label": try literal("γειά σου", language: "el")], ["label": try literal("tab\there")]])
    }

    @Test("A TSV field that is not one term is rejected", arguments: ["UNDEF", "<http://example.org/a> , <http://example.org/b>", "\"open"])
    func tsvRejectsNonTerms(field: String) {
        #expect(throws: SPARQLError.self) {
            _ = try decoder.decode(Data("?x\n\(field)\n".utf8))
        }
    }
}
