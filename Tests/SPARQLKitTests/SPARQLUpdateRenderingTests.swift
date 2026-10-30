import FOAF
import IRIKit
import RDF
import RDFCore
import ServiceDescription
import SPARQLKitTestSupport
import Testing
@testable import SPARQLKit

@Suite("Typed updates render to SPARQL Update", .tags(.rendering))
struct SPARQLUpdateRenderingTests {
    let alice: SPARQLPatternTerm
    let known: SPARQLPatternTerm
    let graph: IRI

    init() throws {
        let terms = try Fixture("update_terms.ttl", in: .module)
        alice = .iri(try terms.subject(FOAF.knows.self))
        known = .iri(try terms.iri(FOAF.knows.self))
        graph = try terms.namedGraph()
    }

    @Test("INSERT DATA and DELETE DATA write ground triples, in a named graph when given one")
    func dataOperationsRender() throws {
        let triple = SPARQLTriplePattern(alice, .property(FOAF.name.sparql), .literal(try Literal("Alice", languageTag: "en")))
        let update = try SPARQLUpdateRequest([
            .insertData([triple, SPARQLTriplePattern(alice, .a, .term(FOAF.PersonIndividual.sparql))]),
            .deleteData([triple], graph: graph)
        ])

        #expect(update.render() == """
            INSERT DATA {
              <http://example.org/alice> <http://xmlns.com/foaf/0.1/name> "Alice"@en .
              <http://example.org/alice> a <http://xmlns.com/foaf/0.1/Person> .
            } ;
            DELETE DATA {
              GRAPH <http://example.org/g> {
                <http://example.org/alice> <http://xmlns.com/foaf/0.1/name> "Alice"@en .
              }
            }
            """)
    }

    @Test("INSERT DATA may hold blank nodes")
    func insertDataHoldsBlankNodes() throws {
        let update = try SPARQLUpdateRequest([
            .insertData([SPARQLTriplePattern(.blankNode(try SPARQLBlankNode("b1")), .property(FOAF.name.sparql), .literal(Literal("x")))])
        ])
        #expect(update.render().contains("_:b1 <http://xmlns.com/foaf/0.1/name> \"x\" ."))
    }

    @Test("DELETE DATA refuses a blank node, as the grammar does")
    func deleteDataRefusesBlankNodes() throws {
        let node = SPARQLPatternTerm.blankNode(try SPARQLBlankNode("b1"))
        #expect(throws: SPARQLError.invalidRequest("DELETE DATA cannot hold a blank node.")) {
            try SPARQLUpdateRequest([.deleteData([SPARQLTriplePattern(node, .property(FOAF.name.sparql), known)])])
        }
        let nested = SPARQLPatternTerm.tripleTerm(subject: node, predicate: .term(FOAF.name.sparql), object: known)
        #expect(throws: SPARQLError.self) {
            try SPARQLUpdateRequest([.deleteData([SPARQLTriplePattern(alice, .property(RDF.reifies.sparql), nested)])])
        }
    }

    @Test("A DELETE template refuses a blank node")
    func deleteTemplateRefusesBlankNodes() throws {
        let node = SPARQLPatternTerm.blankNode(try SPARQLBlankNode("b1"))
        #expect(throws: SPARQLError.invalidRequest("A DELETE template cannot hold a blank node.")) {
            try SPARQLUpdateRequest([
                .modify(
                    delete: [SPARQLTriplePattern(.variable("s"), .property(FOAF.knows.sparql), node)],
                    insert: [],
                    where: [.triple(SPARQLTriplePattern(.variable("s"), .property(FOAF.knows.sparql), .variable("o")))]
                )
            ])
        }
    }

    @Test("Data operations are ground and templates hold no paths")
    func dataIsGroundAndTemplatesHoldNoPaths() {
        #expect(throws: SPARQLError.invalidRequest("INSERT DATA holds ground triples only, not variables.")) {
            try SPARQLUpdateRequest([.insertData([SPARQLTriplePattern(.variable("s"), .property(FOAF.name.sparql), .variable("o"))])])
        }
        #expect(throws: SPARQLError.invalidRequest("An INSERT template cannot hold a property path.")) {
            try SPARQLUpdateRequest([
                .modify(
                    delete: [],
                    insert: [SPARQLTriplePattern(.variable("s"), .path(.inverse(.property(FOAF.knows.sparql))), .variable("o"))],
                    where: []
                )
            ])
        }
    }

    @Test("DELETE/INSERT WHERE renders its templates and pattern")
    func modifyRenders() throws {
        let update = try SPARQLUpdateRequest([
            .modify(
                with: graph,
                delete: [SPARQLTriplePattern(.variable("s"), .property(FOAF.nick.sparql), .variable("o"))],
                insert: [SPARQLTriplePattern(.variable("s"), .property(FOAF.name.sparql), .variable("o"))],
                where: [.triple(SPARQLTriplePattern(.variable("s"), .property(FOAF.nick.sparql), .variable("o")))]
            )
        ])

        #expect(update.render() == """
            WITH <http://example.org/g>
            DELETE {
              ?s <http://xmlns.com/foaf/0.1/nick> ?o .
            }
            INSERT {
              ?s <http://xmlns.com/foaf/0.1/name> ?o .
            }
            WHERE {
              ?s <http://xmlns.com/foaf/0.1/nick> ?o .
            }
            """)
    }

    @Test("Graph management operations render their targets")
    func graphManagementRenders() throws {
        let load = try Fixture("graph_load.ttl", in: .module)
        let source = try load.iri(ServiceDescription.graph.self)
        let g = try load.namedGraph()
        let a = try Fixture("graph_copy_source.ttl", in: .module).namedGraph()
        let b = try Fixture("graph_copy_target.ttl", in: .module).namedGraph()
        let created = try Fixture("graph_created.ttl", in: .module).namedGraph()
        let update = try SPARQLUpdateRequest([
            .load(source, into: g),
            .clear(.named(g), silent: true),
            .create(created),
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
