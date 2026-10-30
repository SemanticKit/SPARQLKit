import IRIKit
import RDFCore
import RDFFormats
import RDFKit
import Testing
@testable import SPARQLKit

@Suite("Typed queries render to SPARQL", .tags(.rendering))
struct SPARQLQueryRenderingTests {
    func pattern(_ s: Variable, _ p: SPARQLTerm, _ o: Variable) -> SPARQLPattern {
        .triple(SPARQLTriplePattern(.variable(s), .property(p), .variable(o)))
    }

    @Test("A SELECT renders its projection, pattern and modifiers")
    func selectRendersSections() {
        let query = SPARQLSelectQuery(
            ["name", .expression(.aggregate(.count, distinct: true, .variable("friend")), as: "count")],
            where: [pattern("person", Foaf.name.sparql, "name"), pattern("person", Foaf.knows.sparql, "friend")],
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
                .optional([pattern("s", Foaf.nick.sparql, "opt")]),
                .union([[pattern("s", Foaf.name.sparql, "o1")], [pattern("s", Foaf.knows.sparql, "o2")]]),
                .minus([pattern("s", Foaf.page.sparql, "x")]),
                .graph(.iri("http://example.org/graph"), [pattern("s", Foaf.name.sparql, "g")]),
                .filter(.builtIn(.bound, [.variable("o2")])),
                .bind(.builtIn(.strlen, [.builtIn(.str, [.variable("o2")])]), as: "calc"),
                .values(try SPARQLValues(variables: ["s"], rows: [[.iri("http://example.org/a")], [.term(Foaf.PersonIndividual.sparql)]]))
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
            fromGraphs: ["http://example.org/default"],
            fromNamedGraphs: ["http://example.org/named"],
            where: [
                pattern("s", Foaf.name.sparql, "o"),
                .values(try SPARQLValues(
                    variables: ["s", "o"],
                    rows: [[.iri("http://example.org/a"), .literal(try Literal("one"))], [nil, .literal(try Literal("two"))]]
                ))
            ],
            groupBy: ["s"],
            having: [.binary(.aggregate(.count, distinct: false, .variable("o")), .greaterThan, .literal(try Literal("1", datatype: XSD.integer.metadata.id)))],
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
            fromGraphs: ["http://example.org/ignored"],
            where: [pattern("s", Foaf.name.sparql, "o")],
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
        let query = SPARQLSelectQuery(where: [pattern("s", Foaf.name.sparql, "o")])
        #expect(query.render().hasPrefix("SELECT *\nWHERE {"))
        #expect(query.projectedVariables == ["s", "o"])
    }

    @Test("Property paths group by precedence")
    func propertyPathsRender() {
        let p1 = SPARQLPropertyPath.property(Foaf.knows.sparql)
        let p2 = SPARQLPropertyPath.property(Foaf.name.sparql)
        let p3 = SPARQLPropertyPath.property(Foaf.page.sparql)
        let pattern = SPARQLTriplePattern(
            .variable("s"),
            .path(.sequence([.zeroOrMore(.alternative([p1, p2])), .zeroOrOne(.inverse(p3))])),
            .variable("o")
        )
        #expect(pattern.render() == "?s (<http://xmlns.com/foaf/0.1/knows>|<http://xmlns.com/foaf/0.1/name>)*/(^<http://xmlns.com/foaf/0.1/page>)? ?o .")

        let negated = SPARQLTriplePattern(
            .variable("s"),
            .path(.negated([.property(Foaf.knows.sparql), .inverse(Foaf.name.sparql)])),
            .variable("o")
        )
        #expect(negated.render() == "?s !(<http://xmlns.com/foaf/0.1/knows>|^<http://xmlns.com/foaf/0.1/name>) ?o .")
    }

    @Test("Expressions render operators, built-ins, IRI functions and EXISTS")
    func expressionsRender() throws {
        let flag = SPARQLExpression.unary(
            .logicalNot,
            .binary(.builtIn(.bound, [.variable("x")]), .or, .unary(.unaryMinus, .literal(try Literal("2", datatype: XSD.integer.metadata.id))))
        )
        #expect(flag.render() == #"!((BOUND(?x) || -("2"^^<http://www.w3.org/2001/XMLSchema#integer>)))"#)

        let cast = SPARQLExpression.function(XSD.integer.sparql, [.variable("n")])
        #expect(cast.render() == "<http://www.w3.org/2001/XMLSchema#integer>(?n)")

        let membership = SPARQLExpression.notIn(.variable("x"), [.iri("http://example.org/a"), .term(Foaf.PersonIndividual.sparql), .literal(try Literal("b"))])
        #expect(membership.render() == #"(?x NOT IN (<http://example.org/a>, <http://xmlns.com/foaf/0.1/Person>, "b"))"#)

        let joined = SPARQLExpression.aggregate(.groupConcat(separator: ", "), distinct: false, .variable("name"))
        #expect(joined.render() == #"GROUP_CONCAT(?name; SEPARATOR=", ")"#)

        let exists = SPARQLExpression.notExists([pattern("x", Foaf.knows.sparql, "y")])
        #expect(exists.render() == "NOT EXISTS { ?x <http://xmlns.com/foaf/0.1/knows> ?y . }")
    }

    @Test("Literals render with escapes, language tags, base directions and datatypes")
    func literalsRender() throws {
        let writer = SPARQLTermWriter()
        #expect(writer.write(try Literal("quote=\" slash=\\ newline=\n")) == #""quote=\" slash=\\ newline=\n""#)
        #expect(writer.write(try Literal("42", datatype: XSD.integer.metadata.id)) == #""42"^^<http://www.w3.org/2001/XMLSchema#integer>"#)
        #expect(writer.write(try Literal("bonjour", languageTag: "fr")) == #""bonjour"@fr"#)
        #expect(writer.write(try Literal("chat", languageTag: "fr", textDirection: .ltr)) == #""chat"@fr--ltr"#)
        #expect(writer.write(try Literal("café é")) == "\"café é\"")
    }

    @Test("A triple term pattern renders as <<( s p o )>>")
    func tripleTermPatternRenders() throws {
        let pattern = SPARQLTriplePattern(
            .variable("r"),
            .property(RDF.reifies.sparql),
            .tripleTerm(subject: .variable("s"), predicate: .term(Foaf.name.sparql), object: .literal(try Literal("Alice")))
        )
        #expect(pattern.render() == #"?r <http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies> <<( ?s <http://xmlns.com/foaf/0.1/name> "Alice" )>> ."#)
        #expect(pattern.variables == ["r", "s"])
    }

    @Test("A decoded term becomes the pattern position that matches it")
    func decodedTermBecomesPatternTerm() throws {
        let term = triple("http://example.org/alice", Foaf.name.metadata.id, try literal("Alice"))
        #expect(try SPARQLPatternTerm(term).render() == #"<<( <http://example.org/alice> <http://xmlns.com/foaf/0.1/name> "Alice" )>>"#)
    }

    @Test("A decoded blank node is refused, since a query cannot name the same node")
    func decodedBlankNodeIsRefused() {
        #expect(throws: SPARQLError.self) { try SPARQLPatternTerm(blank("a b.")) }
        #expect(throws: SPARQLError.self) { try SPARQLPatternTerm(blank("b1")) }
        let nested = ObjectTerm.tripleTerm(TripleTermValue(subject: .blankNode(BlankNode(rawValue: "b1")), predicate: Foaf.name.metadata.id, object: .iri("http://example.org/o")))
        #expect(throws: SPARQLError.self) { try SPARQLPatternTerm(nested) }
    }

    @Test("Declared terms render as their generated type's IRI, and compare by type")
    func declaredTermsRender() {
        #expect(SPARQLTriplePattern(.variable("s"), .a, .term(Foaf.PersonIndividual.sparql)).render() == "?s a <http://xmlns.com/foaf/0.1/Person> .")
        #expect(SPARQLPatternTerm.term(SPARQLTerm(RDF.nil)).render() == "<http://www.w3.org/1999/02/22-rdf-syntax-ns#nil>")
        #expect(Foaf.name.sparql == Foaf.name.sparql)
        #expect(Foaf.name.sparql != Foaf.nick.sparql)
        #expect(SPARQLTerm(RDF.nil) == SPARQLTerm(RDF.nil))
    }

    @Test("ASK, CONSTRUCT and DESCRIBE render their forms")
    func otherFormsRender() throws {
        let ask = SPARQLAskQuery(where: [
            pattern("person", Foaf.name.sparql, "name"),
            .filter(.binary(.variable("name"), .equal, .literal(try Literal("Alice"))))
        ])
        #expect(ask.render() == """
            ASK
            WHERE {
              ?person <http://xmlns.com/foaf/0.1/name> ?name .
              FILTER((?name = "Alice"))
            }
            """)

        let construct = try SPARQLConstructQuery(
            [SPARQLTriplePattern(.variable("person"), .property(RDFS.label.sparql), .variable("name"))],
            where: [pattern("person", Foaf.name.sparql, "name")],
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
            [.variable("person"), .iri("http://example.org/alice")],
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
        let inner = SPARQLSelectQuery(["friend"], where: [pattern("person", Foaf.knows.sparql, "friend")])
        let outer = SPARQLSelectQuery(
            ["person", "friend"],
            where: [pattern("friend", Foaf.name.sparql, "name"), .subquery(inner)]
        )
        #expect(outer.validateSubqueryScopes().isEmpty)
    }

    @Test("An outer FILTER on an unprojected subquery variable is reported")
    func unprojectedVariableIsReported() {
        let inner = SPARQLSelectQuery(["friend"], where: [
            pattern("person", Foaf.knows.sparql, "friend"),
            pattern("friend", Foaf.nick.sparql, "hidden")
        ])
        let outer = SPARQLSelectQuery(["friend", "label"], where: [
            pattern("friend", Foaf.name.sparql, "label"),
            .subquery(inner),
            .filter(.builtIn(.bound, [.variable("hidden")]))
        ])

        let issues = outer.validateSubqueryScopes()
        #expect(issues == [SPARQLSubqueryScopeIssue(variable: "hidden", subqueryProjection: ["friend"])])
    }

    @Test("Leaks from nested subqueries are reported at every level")
    func nestedLeaksAreReported() {
        let nested = SPARQLSelectQuery(["x"], where: [pattern("x", Foaf.nick.sparql, "nestedOnly")])
        let middle = SPARQLSelectQuery(["x"], where: [
            .subquery(nested),
            .filter(.builtIn(.bound, [.variable("nestedOnly")]))
        ])
        let outer = SPARQLSelectQuery(["x", "v"], where: [
            pattern("x", Foaf.page.sparql, "v"),
            .optional([.subquery(middle)]),
            .filter(.builtIn(.bound, [.variable("nestedOnly")]))
        ])

        #expect(outer.validateSubqueryScopes().contains { $0.variable == "nestedOnly" })
    }
}
