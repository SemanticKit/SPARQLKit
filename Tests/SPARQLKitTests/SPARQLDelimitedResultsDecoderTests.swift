import Foundation
import Testing
@testable import SPARQLKit

@Suite("SPARQL Query Results CSV and TSV decoding", .tags(.decoding))
struct SPARQLDelimitedResultsDecoderTests {
    let decoder = SPARQLDelimitedResultsDecoder()

    @Test("CSV values are simple literals: CSV does not record term kinds")
    func csvValuesAreSimpleLiterals() throws {
        let result = try decoder.decodeCSV(try fixture("select_result_csv.csv"))

        #expect(result.variables == ["name", "count"])
        #expect(result.bindings.count == 3)
        let first = try #require(result.bindings.first)
        #expect(first["name"] == (try literal("Alice")))
        #expect(first["count"] == (try literal("3")))
    }

    @Test("CSV quoted fields keep commas and doubled quotes; empty fields are unbound")
    func csvQuotingAndUnbound() throws {
        let result = try decoder.decodeCSV(try fixture("select_result_csv_edge.csv"))

        #expect(result.bindings.count == 2)
        let first = try #require(result.bindings.first)
        #expect(first["name"] == (try literal("Alice, A.")))
        #expect(first["note"] == (try literal("He said \"hi\"")))
        let second = try #require(result.bindings.last)
        #expect(second["count"] == nil)
        #expect(second["note"] == nil)
    }

    @Test("CSV keeps term-like text as the text it is")
    func csvKeepsTermLikeText() throws {
        let row = try #require(try decoder.decodeCSV(try fixture("select_result_csv_terms.csv")).bindings.first)

        #expect(row["iri"] == (try literal("http://example.org/r")))
        #expect(row["bnode"] == (try literal("_:b1")))
        #expect(row["typed"] == (try literal("42")))
        #expect(row["label"] == (try literal("chat")))
    }

    @Test("TSV fields are Turtle terms, numbers included")
    func tsvFieldsAreTurtleTerms() throws {
        let result = try decoder.decodeTSV(try fixture("select_result_tsv.tsv"))

        #expect(result.variables == ["name", "count"])
        #expect(result.bindings.count == 3)
        let first = try #require(result.bindings.first)
        #expect(first["name"] == (try literal("Alice")))
        #expect(first["count"] == (try literal("3", datatype: xsdInteger)))
    }

    @Test("TSV decodes IRIs, blank nodes, language-tagged and typed literals")
    func tsvDecodesEveryTermKind() throws {
        let row = try #require(try decoder.decodeTSV(try fixture("select_result_tsv_terms.tsv")).bindings.first)

        #expect(row["iri"] == iri("http://example.org/r"))
        #expect(try row["bnode"] == blank("b1"))
        #expect(row["lang"] == (try literal("bonjour", language: "fr")))
        #expect(row["typed"] == (try literal("42", datatype: xsdInteger)))
        #expect(row["plain"] == (try literal("text")))
    }

    @Test("TSV decodes triple terms and directional literals")
    func tsvDecodesTripleTerms() throws {
        let row = try #require(try decoder.decodeTSV(try fixture("select_result_tsv_triple_terms.tsv")).bindings.first)

        #expect(row["triple"] == triple("http://example.org/alice", "http://example.org/name", try literal("Alice")))
        #expect(row["label"] == (try literal("chat", language: "fr", direction: .ltr)))
    }

    @Test("TSV keeps a blank node label across rows")
    func tsvKeepsBlankNodeLabels() throws {
        let result = try decoder.decodeTSV(Data("?x\n_:b1\n_:b1\n".utf8))
        #expect(try result.bindings == [["x": blank("b1")], ["x": blank("b1")]])
    }

    @Test("TSV unescapes string escapes and keeps Unicode")
    func tsvUnescapes() throws {
        let result = try decoder.decodeTSV(Data("?label\n\"γειά σου\"@el\n\"tab\\there\"\n".utf8))
        #expect(result.bindings == [["label": try literal("γειά σου", language: "el")], ["label": try literal("tab\there")]])
    }

    @Test("A TSV field that is not one term is rejected", arguments: ["UNDEF", "<http://example.org/a> , <http://example.org/b>", "\"open"])
    func tsvRejectsNonTerms(field: String) {
        #expect(throws: SPARQLError.self) {
            _ = try decoder.decodeTSV(Data("?x\n\(field)\n".utf8))
        }
    }
}
