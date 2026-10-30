import Foundation
import IRIKit
import RDFCore
import RDFFormats
import Testing
@testable import SPARQLKit

@Suite("Graph results decode with RDFFormats", .tags(.decoding))
struct SPARQLGraphResultDecoderTests {
    let knows: IRI = "http://example.org/knows"

    @Test("A Turtle graph decodes into its set of triples")
    func decodesTurtle() throws {
        let graph = try SPARQLGraphResultDecoder().decode(try fixture("construct_result_turtle.ttl"), as: .turtle)

        #expect(graph == [
            Graph.Element(subject: .iri("http://example.org/alice"), predicate: knows, object: .iri("http://example.org/bob")),
            Graph.Element(subject: .iri("http://example.org/bob"), predicate: knows, object: .iri("http://example.org/charlie"))
        ])
    }

    @Test("Relative references resolve against the base")
    func resolvesAgainstBase() throws {
        let graph = try SPARQLGraphResultDecoder().decode(
            Data("<a> <knows> <b> .".utf8),
            as: .turtle,
            base: "http://example.org/"
        )
        #expect(graph == [Graph.Element(subject: .iri("http://example.org/a"), predicate: knows, object: .iri("http://example.org/b"))])
    }

    @Test("An N-Triples graph decodes")
    func decodesNTriples() throws {
        let graph = try SPARQLGraphResultDecoder().decode(
            Data("<http://example.org/a> <http://example.org/knows> <http://example.org/b> .\n".utf8),
            as: .ntriples
        )
        #expect(graph.count == 1)
    }

    @Test("A document that is not Turtle is rejected")
    func rejectsInvalidTurtle() {
        #expect(throws: SPARQLError.self) {
            _ = try SPARQLGraphResultDecoder().decode(Data("this is not turtle <<".utf8), as: .turtle)
        }
    }

    @Test("Clients ask only for graph formats RDFFormats decodes")
    func offersOnlyDecodableFormats() throws {
        #expect(SPARQLGraphAccept.allCases == [.turtle, .ntriples])
        #expect(SPARQLGraphAccept(rawValue: "application/rdf+xml") == nil)
        #expect(SPARQLGraphAccept(rawValue: "application/ld+json") == nil)
        for accept in SPARQLGraphAccept.allCases {
            let graph = try SPARQLGraphResultDecoder().decode(
                Data("<http://example.org/a> <http://example.org/knows> <http://example.org/b> .\n".utf8),
                as: accept
            )
            #expect(graph.count == 1)
        }
    }
}
