import FOAF
import IRIKit
import RDF
import RDFCore
import RDFFormats
import ServiceDescription
import SPARQLKitTestSupport
import Testing
@testable import SPARQLKit

@Suite("Typed queries render to SPARQL", .tags(.rendering))
struct SPARQLQueryRenderingTests {
    /// Alice, whom the rendering terms state she knows, and the named graph
    /// they name.
    let alice: IRI
    let known: IRI
    let graphName: IRI
    let dataset: Fixture
    let ignoredGraph: IRI
    /// The subject and object of the example triple.
    let exampleSubject: IRI
    let exampleObject: IRI

    init() throws {
        let terms = try Fixture("rendering_terms.ttl", in: .module)
        alice = try terms.subject(FOAF.knows)
        known = try terms.iri(FOAF.knows)
        graphName = try terms.namedGraph()
        dataset = try Fixture("rendering_dataset.ttl", in: .module)
        ignoredGraph = try Fixture("rendering_subquery_dataset.ttl", in: .module).iri(ServiceDescription.defaultGraph)
        let example = try Fixture("example_triple.ttl", in: .module).triple()
        exampleSubject = try #require(example.subjectIRI)
        exampleObject = try #require(example.objectIRI)
    }

    func pattern(_ s: Variable, _ p: SPARQLTerm, _ o: Variable) -> SPARQLPattern {
        .triple(SPARQLTriplePattern(.variable(s), .property(p), .variable(o)))
    }

    @Test("A SELECT renders its projection, pattern and modifiers")
    func selectRendersSections() {
        let query = SPARQLSelectQuery(
            ["name", .expression(.aggregate(.count, distinct: true, .variable("friend")), as: "count")],
            where: [pattern("person", FOAF.name.sparql, "name"), pattern("person", FOAF.knows.sparql, "friend")],
            groupBy: ["person", "name"],
            limit: 20
        )

        #expect(query.render() == """
            SELECT ?name (COUNT(DISTINCT ?friend) AS ?count)
            WHERE {
              ?person <http://xmlns.com/foaf/0.1/name> ?name .
              ?person <http://xmlns.com/foaf/0.1/knows> ?friend .
            }
            GROUP BY ?person ?name
            LIMIT 20
            """)
    }

    @Test("Group graph patterns nest OPTIONAL, UNION, MINUS, GRAPH, FILTER, BIND and VALUES")
    func groupPatternsRender() throws {
        let query = SPARQLSelectQuery(
            ["s", "o2", "calc"],
            where: [
                .triple(SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o"))),
                .optional([pattern("s", FOAF.nick.sparql, "opt")]),
                .union([[pattern("s", FOAF.name.sparql, "o1")], [pattern("s", FOAF.knows.sparql, "o2")]]),
                .minus([pattern("s", FOAF.page.sparql, "x")]),
                .graph(.iri(graphName), [pattern("s", FOAF.name.sparql, "g")]),
                .filter(.builtIn(.bound, [.variable("o2")])),
                .bind(.builtIn(.strlen, [.builtIn(.str, [.variable("o2")])]), as: "calc"),
                .values(try SPARQLValues(variables: ["s"], rows: [[.iri(known)], [.term(FOAF.PersonIndividual.sparql)]]))
            ]
        )

        #expect(query.render() == """
            SELECT ?s ?o2 ?calc
            WHERE {
              ?s ?p ?o .
              OPTIONAL {
                ?s <http://xmlns.com/foaf/0.1/nick> ?opt .
              }
              {
                ?s <http://xmlns.com/foaf/0.1/name> ?o1 .
              }
              UNION {
                ?s <http://xmlns.com/foaf/0.1/knows> ?o2 .
              }
              MINUS {
                ?s <http://xmlns.com/foaf/0.1/page> ?x .
              }
              GRAPH <http://example.org/graph> {
                ?s <http://xmlns.com/foaf/0.1/name> ?g .
              }
              FILTER(BOUND(?o2))
              BIND(STRLEN(STR(?o2)) AS ?calc)
              VALUES ?s {
                <http://example.org/a>
                <http://xmlns.com/foaf/0.1/Person>
              }
            }
            """)
    }

    @Test("Solution modifiers and the dataset clause render in grammar order")
    func modifiersAndDatasetRender() throws {
        let query = SPARQLSelectQuery(
            ["s", "count"],
            distinct: true,
            fromGraphs: dataset.defaultGraphs,
            fromNamedGraphs: dataset.namedGraphs,
            where: [
                pattern("s", FOAF.name.sparql, "o"),
                .values(try SPARQLValues(
                    variables: ["s", "o"],
                    rows: [[.iri(known), .literal(Literal("one"))], [nil, .literal(Literal("two"))]]
                ))
            ],
            groupBy: ["s"],
            having: [.binary(.aggregate(.count, distinct: false, .variable("o")), .greaterThan, .literal(try integer("1")))],
            orderBy: [SPARQLOrderCondition(.variable("s"), ascending: false)],
            limit: 10,
            offset: 20
        )

        let rendered = query.render()
        #expect(rendered.hasPrefix("SELECT DISTINCT ?s ?count\nFROM <http://example.org/default>\nFROM NAMED <http://example.org/named>\nWHERE {"))
        #expect(rendered.contains("VALUES (?s ?o) {\n    (<http://example.org/a> \"one\")\n    (UNDEF \"two\")\n  }"))
        #expect(rendered.hasSuffix("""
            GROUP BY ?s
            HAVING ((COUNT(?o) > "1"^^<http://www.w3.org/2001/XMLSchema#integer>))
            ORDER BY DESC(?s)
            LIMIT 10
            OFFSET 20
            """))
    }

    @Test("A subquery renders inside braces without a dataset clause")
    func subqueryRenders() {
        let inner = SPARQLSelectQuery(
            ["s"],
            fromGraphs: [ignoredGraph],
            where: [pattern("s", FOAF.name.sparql, "o")],
            limit: 5
        )
        let outer = SPARQLSelectQuery(["s"], where: [.subquery(inner)])

        #expect(outer.render() == """
            SELECT ?s
            WHERE {
              {
                SELECT ?s
                WHERE {
                  ?s <http://xmlns.com/foaf/0.1/name> ?o .
                }
                LIMIT 5
              }
            }
            """)
    }

    @Test("SELECT with no projection is SELECT *")
    func selectStar() {
        let query = SPARQLSelectQuery(where: [pattern("s", FOAF.name.sparql, "o")])
        #expect(query.render().hasPrefix("SELECT *\nWHERE {"))
        #expect(query.projectedVariables == ["s", "o"])
    }

    @Test("Property paths group by precedence")
    func propertyPathsRender() {
        let p1 = SPARQLPropertyPath.property(FOAF.knows.sparql)
        let p2 = SPARQLPropertyPath.property(FOAF.name.sparql)
        let p3 = SPARQLPropertyPath.property(FOAF.page.sparql)
        let pattern = SPARQLTriplePattern(
            .variable("s"),
            .path(.sequence([.zeroOrMore(.alternative([p1, p2])), .zeroOrOne(.inverse(p3))])),
            .variable("o")
        )
        #expect(pattern.render() == "?s (<http://xmlns.com/foaf/0.1/knows>|<http://xmlns.com/foaf/0.1/name>)*/(^<http://xmlns.com/foaf/0.1/page>)? ?o .")

        let negated = SPARQLTriplePattern(
            .variable("s"),
            .path(.negated([.property(FOAF.knows.sparql), .inverse(FOAF.name.sparql)])),
            .variable("o")
        )
        #expect(negated.render() == "?s !(<http://xmlns.com/foaf/0.1/knows>|^<http://xmlns.com/foaf/0.1/name>) ?o .")
    }

    @Test("Expressions render operators, built-ins, IRI functions and EXISTS")
    func expressionsRender() throws {
        let flag = SPARQLExpression.unary(
            .logicalNot,
            .binary(.builtIn(.bound, [.variable("x")]), .or, .unary(.unaryMinus, .literal(try integer("2"))))
        )
        #expect(flag.render() == #"!((BOUND(?x) || -("2"^^<http://www.w3.org/2001/XMLSchema#integer>)))"#)

        let call = SPARQLExpression.function(RDF.JSONIndividual.sparql, [.variable("n")])
        #expect(call.render() == "<http://www.w3.org/1999/02/22-rdf-syntax-ns#JSON>(?n)")

        let membership = SPARQLExpression.notIn(.variable("x"), [.iri(known), .term(FOAF.PersonIndividual.sparql), .literal(Literal("b"))])
        #expect(membership.render() == #"(?x NOT IN (<http://example.org/a>, <http://xmlns.com/foaf/0.1/Person>, "b"))"#)

        let joined = SPARQLExpression.aggregate(.groupConcat(separator: ", "), distinct: false, .variable("name"))
        #expect(joined.render() == #"GROUP_CONCAT(?name; SEPARATOR=", ")"#)

        let exists = SPARQLExpression.notExists([pattern("x", FOAF.knows.sparql, "y")])
        #expect(exists.render() == "NOT EXISTS { ?x <http://xmlns.com/foaf/0.1/knows> ?y . }")
    }

    @Test("Literals render with escapes, language tags, base directions and datatypes")
    func literalsRender() throws {
        #expect(Literal("quote=\" slash=\\ newline=\n").render() == #""quote=\" slash=\\ newline=\n""#)
        #expect((try integer("42")).render() == #""42"^^<http://www.w3.org/2001/XMLSchema#integer>"#)
        #expect((try Literal("bonjour", languageTag: "fr")).render() == #""bonjour"@fr"#)
        #expect((try Literal("chat", languageTag: "fr", baseDirection: .ltr)).render() == #""chat"@fr--ltr"#)
        #expect(Literal("café é").render() == "\"café é\"")
    }

    @Test("A triple term pattern renders as <<( s p o )>>")
    func tripleTermPatternRenders() throws {
        let pattern = SPARQLTriplePattern(
            .variable("r"),
            .property(RDF.reifies.sparql),
            .tripleTerm(subject: .variable("s"), predicate: .term(FOAF.name.sparql), object: .literal(Literal("Alice")))
        )
        #expect(pattern.render() == #"?r <http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies> <<( ?s <http://xmlns.com/foaf/0.1/name> "Alice" )>> ."#)
        #expect(pattern.variables == ["r", "s"])
    }

    @Test("A decoded term becomes the pattern position that matches it")
    func decodedTermBecomesPatternTerm() throws {
        let term = triple(alice, IRI(of: FOAF.name)!, try literal("Alice"))
        #expect(try SPARQLPatternTerm(term).render() == #"<<( <http://example.org/alice> <http://xmlns.com/foaf/0.1/name> "Alice" )>>"#)
    }

    @Test("A decoded blank node is refused, since a query cannot name the same node")
    func decodedBlankNodeIsRefused() throws {
        #expect(throws: SPARQLError.self) { try SPARQLPatternTerm(blank("a b.")) }
        #expect(throws: SPARQLError.self) { try SPARQLPatternTerm(blank("b1")) }
        let nested = ObjectTerm.tripleTerm(Triple(subject: .blankNode(try BlankNode("b1")), predicate: IRI(of: FOAF.name)!, object: .iri(exampleObject)))
        #expect(throws: SPARQLError.self) { try SPARQLPatternTerm(nested) }
    }

    @Test("Translated terms render as the IRI that denotes them, and compare by identity")
    func declaredTermsRender() {
        #expect(SPARQLTriplePattern(.variable("s"), .a, .term(FOAF.PersonIndividual.sparql)).render() == "?s a <http://xmlns.com/foaf/0.1/Person> .")
        #expect(SPARQLPatternTerm.term(SPARQLTerm(RDF.nil)).render() == "<http://www.w3.org/1999/02/22-rdf-syntax-ns#nil>")
        #expect(FOAF.name.sparql == FOAF.name.sparql)
        #expect(FOAF.name.sparql != FOAF.nick.sparql)
        #expect(SPARQLTerm(RDF.nil) == SPARQLTerm(RDF.nil))
    }

    @Test("ASK, CONSTRUCT and DESCRIBE render their forms")
    func otherFormsRender() throws {
        let ask = SPARQLAskQuery(where: [
            pattern("person", FOAF.name.sparql, "name"),
            .filter(.binary(.variable("name"), .equal, .literal(Literal("Alice"))))
        ])
        #expect(ask.render() == """
            ASK
            WHERE {
              ?person <http://xmlns.com/foaf/0.1/name> ?name .
              FILTER((?name = "Alice"))
            }
            """)

        let construct = try SPARQLConstructQuery(
            [SPARQLTriplePattern(.variable("person"), .property(RDF.label.sparql), .variable("name"))],
            where: [pattern("person", FOAF.name.sparql, "name")],
            limit: 10
        )
        #expect(construct.render() == """
            CONSTRUCT {
              ?person <http://www.w3.org/2000/01/rdf-schema#label> ?name .
            }
            WHERE {
              ?person <http://xmlns.com/foaf/0.1/name> ?name .
            }
            LIMIT 10
            """)

        let describe = try SPARQLDescribeQuery(
            [.variable("person"), .iri(alice)],
            where: [.triple(SPARQLTriplePattern(.variable("person"), .variable("p"), .variable("o")))],
            limit: 5
        )
        #expect(describe.render() == """
            DESCRIBE ?person <http://example.org/alice>
            WHERE {
              ?person ?p ?o .
            }
            LIMIT 5
            """)
        #expect(try SPARQLDescribeQuery([]).render() == "DESCRIBE *")
    }
}

@Suite("Subquery scope", .tags(.rendering))
struct SPARQLSubqueryScopeTests {
    func pattern(_ s: Variable, _ p: SPARQLTerm, _ o: Variable) -> SPARQLPattern {
        .triple(SPARQLTriplePattern(.variable(s), .property(p), .variable(o)))
    }

    @Test("Projected subquery variables are visible to the outer query")
    func projectedVariablesAreVisible() {
        let inner = SPARQLSelectQuery(["friend"], where: [pattern("person", FOAF.knows.sparql, "friend")])
        let outer = SPARQLSelectQuery(
            ["person", "friend"],
            where: [pattern("friend", FOAF.name.sparql, "name"), .subquery(inner)]
        )
        #expect(outer.validateSubqueryScopes().isEmpty)
    }

    @Test("An outer FILTER on an unprojected subquery variable is reported")
    func unprojectedVariableIsReported() {
        let inner = SPARQLSelectQuery(["friend"], where: [
            pattern("person", FOAF.knows.sparql, "friend"),
            pattern("friend", FOAF.nick.sparql, "hidden")
        ])
        let outer = SPARQLSelectQuery(["friend", "label"], where: [
            pattern("friend", FOAF.name.sparql, "label"),
            .subquery(inner),
            .filter(.builtIn(.bound, [.variable("hidden")]))
        ])

        let issues = outer.validateSubqueryScopes()
        #expect(issues == [SPARQLSubqueryScopeIssue(variable: "hidden", subqueryProjection: ["friend"])])
    }

    @Test("Leaks from nested subqueries are reported at every level")
    func nestedLeaksAreReported() {
        let nested = SPARQLSelectQuery(["x"], where: [pattern("x", FOAF.nick.sparql, "nestedOnly")])
        let middle = SPARQLSelectQuery(["x"], where: [
            .subquery(nested),
            .filter(.builtIn(.bound, [.variable("nestedOnly")]))
        ])
        let outer = SPARQLSelectQuery(["x", "v"], where: [
            pattern("x", FOAF.page.sparql, "v"),
            .optional([.subquery(middle)]),
            .filter(.builtIn(.bound, [.variable("nestedOnly")]))
        ])

        #expect(outer.validateSubqueryScopes().contains { $0.variable == "nestedOnly" })
    }
}
