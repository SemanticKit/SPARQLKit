import IRIKit
import RDFCore
import RDFFormats
import Testing
@testable import SPARQLKit

@Suite("Typed updates render to SPARQL Update", .tags(.rendering))
struct SPARQLUpdateRenderingTests {
    let alice: IRI = "http://example.org/alice"
    let name: IRI = "http://example.org/name"

    @Test("INSERT DATA and DELETE DATA write ground triples, in a named graph when given one")
    func dataOperationsRender() throws {
        let triple = DecodedTriple(subject: .iri(alice), predicate: name, object: .literal(try Literal("Alice", languageTag: "en")))
        let update = SPARQLUpdateRequest([
            .insertData([triple]),
            .deleteData([triple], graph: "http://example.org/g")
        ])

        #expect(update.render() == """
            INSERT DATA {
              <http://example.org/alice> <http://example.org/name> "Alice"@en .
            } ;
            DELETE DATA {
              GRAPH <http://example.org/g> {
                <http://example.org/alice> <http://example.org/name> "Alice"@en .
              }
            }
            """)
    }

    @Test("DELETE/INSERT WHERE renders its templates and pattern")
    func modifyRenders() {
        let old: IRI = "http://example.org/old"
        let new: IRI = "http://example.org/new"
        let update = SPARQLUpdateRequest([
            .modify(
                with: "http://example.org/g",
                delete: [SPARQLTriplePattern(.variable("s"), .iri(old), .variable("o"))],
                insert: [SPARQLTriplePattern(.variable("s"), .iri(new), .variable("o"))],
                where: [.triple(SPARQLTriplePattern(.variable("s"), .iri(old), .variable("o")))]
            )
        ])

        #expect(update.render() == """
            WITH <http://example.org/g>
            DELETE {
              ?s <http://example.org/old> ?o .
            }
            INSERT {
              ?s <http://example.org/new> ?o .
            }
            WHERE {
              ?s <http://example.org/old> ?o .
            }
            """)
    }

    @Test("Graph management operations render their targets")
    func graphManagementRenders() {
        let a: IRI = "http://example.org/a"
        let b: IRI = "http://example.org/b"
        let update = SPARQLUpdateRequest([
            .load("http://example.org/source", into: "http://example.org/g"),
            .clear(.named("http://example.org/g"), silent: true),
            .create("http://example.org/new"),
            .drop(.default),
            .copy(from: .named(a), to: .named(b)),
            .move(from: .named(a), to: .default, silent: true),
            .add(from: .default, to: .named(b))
        ])

        #expect(update.render() == """
            LOAD <http://example.org/source> INTO GRAPH <http://example.org/g> ;
            CLEAR SILENT GRAPH <http://example.org/g> ;
            CREATE GRAPH <http://example.org/new> ;
            DROP DEFAULT ;
            COPY GRAPH <http://example.org/a> TO GRAPH <http://example.org/b> ;
            MOVE SILENT GRAPH <http://example.org/a> TO DEFAULT ;
            ADD DEFAULT TO GRAPH <http://example.org/b>
            """)
    }
}
