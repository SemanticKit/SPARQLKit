import Foundation
import SPARQLKitTestSupport
import Testing
@testable import SPARQLKit

@Suite("SPARQL Query Results CSV decoding", .tags(.decoding))
struct SPARQLCSVResultDecoderTests {
    let decoder = SPARQLCSVResultDecoder()

    @Test("CSV values are simple literals: CSV does not record term kinds")
    func csvValuesAreSimpleLiterals() throws {
        let result = try decoder.decode(try Fixture.data("select_result_csv.csv", in: .module))

        #expect(result.variables == ["name", "count"])
        #expect(result.bindings.count == 3)
        let first = try #require(result.bindings.first)
        #expect(first["name"] == (try literal("Alice")))
        #expect(first["count"] == (try literal("3")))
    }

    @Test("CSV quoted fields keep commas and doubled quotes; empty fields are unbound")
    func csvQuotingAndUnbound() throws {
        let result = try decoder.decode(try Fixture.data("select_result_csv_edge.csv", in: .module))

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
        let row = try #require(try decoder.decode(try Fixture.data("select_result_csv_terms.csv", in: .module)).bindings.first)

        #expect(row["iri"] == (try literal("http://example.org/r")))
        #expect(row["bnode"] == (try literal("_:b1")))
        #expect(row["typed"] == (try literal("42")))
        #expect(row["label"] == (try literal("chat")))
    }
}
