import Foundation
import RDFCore
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

    @Test("A TSV field that is not one term is rejected", arguments: [
        "UNDEF",
        "<http://example.org/a> , <http://example.org/b>",
        "<http://example.org/a> , <http://example.org/a>",
        "\"x\" . @prefix p: <http://example.org/>",
        "\"x\" )>> . @prefix p: <http://example.org/> . <http://example.org/s> <http://example.org/p> <<( <http://example.org/s> <http://example.org/p> \"x\"",
        "<http://example.org/a> )>> . #",
        "( <http://example.org/a> )",
        "[ <http://example.org/p> <http://example.org/o> ]",
        "\"open",
    ])
    func tsvRejectsNonTerms(field: String) {
        #expect(throws: SPARQLError.self) {
            _ = try decoder.decode(Data("?x\n\(field)\n".utf8))
        }
    }

    @Test("An anonymous blank node is not a TSV term", arguments: [
        "[]",
        "<<( [] <http://example.org/p> <http://example.org/o> )>>",
        "<<( _:b1 <http://example.org/p> [] )>>",
        "<<( [] <http://example.org/p> _:b1 )>>",
        "<<( [] <http://example.org/p> \"_:b1\" )>>",
    ])
    func tsvRejectsAnonymousBlankNodes(field: String) {
        #expect(throws: SPARQLError.self) {
            _ = try decoder.decode(Data("?x\n\(field)\n".utf8))
        }
    }

    @Test("Blank nodes written _:label keep their labels inside triple terms")
    func tsvKeepsLabelsInTripleTerms() throws {
        let result = try decoder.decode(Data("?x\n<<( _:b2 <http://example.org/p> _:b1 )>>\n".utf8))
        let expected = ObjectTerm.tripleTerm(Triple(
            subject: .blankNode(try BlankNode("b2")),
            predicate: "http://example.org/p",
            object: .blankNode(try BlankNode("b1"))
        ))
        #expect(result.bindings == [["x": expected]])
    }

    @Test("Only a line feed ends a TSV record; other line separators stay in the literal", arguments: ["\u{2028}", "\u{0085}", "\u{000B}", "\u{000C}", "\u{2029}"])
    func tsvKeepsUnicodeLineSeparators(separator: String) throws {
        let result = try decoder.decode(Data("?x\t?y\r\n\"a\(separator)b\"\t\"c\"\r\n".utf8))
        #expect(result.bindings == [["x": try literal("a\(separator)b"), "y": try literal("c")]])
    }
}
