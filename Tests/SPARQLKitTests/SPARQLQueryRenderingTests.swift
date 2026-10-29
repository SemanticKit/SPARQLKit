import IRIKit
import RDFCore
import Testing
@testable import SPARQLKit

@Suite("Typed queries render to SPARQL", .tags(.rendering))
struct SPARQLQueryRenderingTests {
    let foafName: IRI = "http://xmlns.com/foaf/0.1/name"
    let foafKnows: IRI = "http://xmlns.com/foaf/0.1/knows"

    func pattern(_ s: Variable, _ p: IRI, _ o: Variable) -> SPARQLPattern {
        .triple(SPARQLTriplePattern(.variable(s), .iri(p), .variable(o)))
    }

    @Test("A SELECT renders its projection, pattern and modifiers")
    func selectRendersSections() {
        let query = SPARQLSelectQuery(
            ["name", .expression(.aggregate(.count, distinct: true, .variable("friend")), as: "count")],
            where: [pattern("person", foafName, "name"), pattern("person", foafKnows, "friend")],
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
        let p1: IRI = "http://example.org/p1"
        let p2: IRI = "http://example.org/p2"
        let query = SPARQLSelectQuery(
            ["s", "o2", "calc"],
            where: [
                .triple(SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o"))),
                .optional([pattern("s", "http://example.org/opt", "opt")]),
                .union([[pattern("s", p1, "o1")], [pattern("s", p2, "o2")]]),
                .minus([pattern("s", "http://example.org/blocked", "x")]),
                .graph(.iri("http://example.org/graph"), [pattern("s", "http://example.org/inGraph", "g")]),
                .filter(.builtIn(.bound, [.variable("o2")])),
                .bind(.builtIn(.strlen, [.builtIn(.str, [.variable("o2")])]), as: "calc"),
                .values(SPARQLValues(variables: ["s"], rows: [[iri("http://example.org/a")], [iri("http://example.org/b")]]))
            ]
        )

        #expect(query.render() == """
            SELECT ?s ?o2 ?calc
            WHERE {
              ?s ?p ?o .
              OPTIONAL {
                ?s <http://example.org/opt> ?opt .
              }
              {
                ?s <http://example.org/p1> ?o1 .
              }
              UNION {
                ?s <http://example.org/p2> ?o2 .
              }
              MINUS {
                ?s <http://example.org/blocked> ?x .
              }
              GRAPH <http://example.org/graph> {
                ?s <http://example.org/inGraph> ?g .
              }
              FILTER(BOUND(?o2))
              BIND(STRLEN(STR(?o2)) AS ?calc)
              VALUES ?s {
                <http://example.org/a>
                <http://example.org/b>
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
                pattern("s", "http://example.org/p", "o"),
                .values(SPARQLValues(
                    variables: ["s", "o"],
                    rows: [[iri("http://example.org/a"), try literal("one")], [nil, try literal("two")]]
                ))
            ],
            groupBy: ["s"],
            having: [.binary(.aggregate(.count, distinct: false, .variable("o")), .greaterThan, .literal(try Literal("1", datatype: xsdInteger)))],
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
            where: [pattern("s", "http://example.org/p", "o")],
            limit: 5
        )
        let outer = SPARQLSelectQuery(["s"], where: [.subquery(inner)])

        #expect(outer.render() == """
            SELECT ?s
            WHERE {
              {
                SELECT ?s
                WHERE {
                  ?s <http://example.org/p> ?o .
                }
                LIMIT 5
              }
            }
            """)
    }

    @Test("SELECT with no projection is SELECT *")
    func selectStar() {
        let query = SPARQLSelectQuery(where: [pattern("s", "http://example.org/p", "o")])
        #expect(query.render().hasPrefix("SELECT *\nWHERE {"))
        #expect(query.projectedVariables == ["s", "o"])
    }

    @Test("Property paths group by precedence")
    func propertyPathsRender() {
        let p1 = SPARQLPropertyPath.iri("http://example.org/p1")
        let p2 = SPARQLPropertyPath.iri("http://example.org/p2")
        let p3 = SPARQLPropertyPath.iri("http://example.org/p3")
        let pattern = SPARQLTriplePattern(
            .variable("s"),
            .path(.sequence([.zeroOrMore(.alternative([p1, p2])), .zeroOrOne(.inverse(p3))])),
            .variable("o")
        )
        #expect(pattern.render() == "?s (<http://example.org/p1>|<http://example.org/p2>)*/(^<http://example.org/p3>)? ?o .")

        let negated = SPARQLTriplePattern(
            .variable("s"),
            .path(.negated([.iri("http://example.org/p1"), .inverse("http://example.org/p2")])),
            .variable("o")
        )
        #expect(negated.render() == "?s !(<http://example.org/p1>|^<http://example.org/p2>) ?o .")
    }

    @Test("Expressions render operators, built-ins, IRI functions and EXISTS")
    func expressionsRender() throws {
        let flag = SPARQLExpression.unary(
            .logicalNot,
            .binary(.builtIn(.bound, [.variable("x")]), .or, .unary(.unaryMinus, .literal(try Literal("2", datatype: xsdInteger))))
        )
        #expect(flag.render() == #"!((BOUND(?x) || -("2"^^<http://www.w3.org/2001/XMLSchema#integer>)))"#)

        let cast = SPARQLExpression.function(xsdInteger, [.variable("n")])
        #expect(cast.render() == "<http://www.w3.org/2001/XMLSchema#integer>(?n)")

        let membership = SPARQLExpression.notIn(.variable("x"), [.iri("http://example.org/a"), .literal(try Literal("b"))])
        #expect(membership.render() == #"(?x NOT IN (<http://example.org/a>, "b"))"#)

        let joined = SPARQLExpression.aggregate(.groupConcat(separator: ", "), distinct: false, .variable("name"))
        #expect(joined.render() == #"GROUP_CONCAT(?name; SEPARATOR=", ")"#)

        let exists = SPARQLExpression.notExists([pattern("x", "http://example.org/p", "y")])
        #expect(exists.render() == "NOT EXISTS { ?x <http://example.org/p> ?y . }")
    }

    @Test("Literals render with escapes, language tags, base directions and datatypes")
    func literalsRender() throws {
        let writer = SPARQLTermWriter()
        #expect(writer.write(try Literal("quote=\" slash=\\ newline=\n")) == #""quote=\" slash=\\ newline=\n""#)
        #expect(writer.write(try Literal("42", datatype: xsdInteger)) == #""42"^^<http://www.w3.org/2001/XMLSchema#integer>"#)
        #expect(writer.write(try Literal("bonjour", languageTag: "fr")) == #""bonjour"@fr"#)
        #expect(writer.write(try Literal("chat", languageTag: "fr", textDirection: .ltr)) == #""chat"@fr--ltr"#)
        #expect(writer.write(try Literal("café é")) == "\"café é\"")
    }

    @Test("A triple term pattern renders as <<( s p o )>>")
    func tripleTermPatternRenders() throws {
        let pattern = SPARQLTriplePattern(
            .variable("r"),
            .iri("http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies"),
            .tripleTerm(subject: .variable("s"), predicate: .iri("http://example.org/name"), object: .literal(try Literal("Alice")))
        )
        #expect(pattern.render() == #"?r <http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies> <<( ?s <http://example.org/name> "Alice" )>> ."#)
        #expect(pattern.variables == ["r", "s"])
    }

    @Test("A decoded term becomes the pattern position that matches it")
    func decodedTermBecomesPatternTerm() throws {
        let term = triple("http://example.org/alice", "http://example.org/name", try literal("Alice"))
        #expect(SPARQLPatternTerm(term).render() == #"<<( <http://example.org/alice> <http://example.org/name> "Alice" )>>"#)
    }

    @Test("ASK, CONSTRUCT and DESCRIBE render their forms")
    func otherFormsRender() throws {
        let ask = SPARQLAskQuery(where: [
            pattern("person", foafName, "name"),
            .filter(.binary(.variable("name"), .equal, .literal(try Literal("Alice"))))
        ])
        #expect(ask.render() == """
            ASK
            WHERE {
              ?person <http://xmlns.com/foaf/0.1/name> ?name .
              FILTER((?name = "Alice"))
            }
            """)

        let construct = SPARQLConstructQuery(
            [SPARQLTriplePattern(.variable("person"), .iri("http://www.w3.org/2000/01/rdf-schema#label"), .variable("name"))],
            where: [pattern("person", foafName, "name")],
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

        let describe = SPARQLDescribeQuery(
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
        #expect(SPARQLDescribeQuery([]).render() == "DESCRIBE *")
    }
}

@Suite("Subquery scope", .tags(.rendering))
struct SPARQLSubqueryScopeTests {
    func pattern(_ s: Variable, _ p: IRI, _ o: Variable) -> SPARQLPattern {
        .triple(SPARQLTriplePattern(.variable(s), .iri(p), .variable(o)))
    }

    @Test("Projected subquery variables are visible to the outer query")
    func projectedVariablesAreVisible() {
        let inner = SPARQLSelectQuery(["friend"], where: [pattern("person", "http://example.org/knows", "friend")])
        let outer = SPARQLSelectQuery(
            ["person", "friend"],
            where: [pattern("friend", "http://example.org/name", "name"), .subquery(inner)]
        )
        #expect(outer.validateSubqueryScopes().isEmpty)
    }

    @Test("An outer FILTER on an unprojected subquery variable is reported")
    func unprojectedVariableIsReported() {
        let inner = SPARQLSelectQuery(["friend"], where: [
            pattern("person", "http://example.org/knows", "friend"),
            pattern("friend", "http://example.org/secret", "hidden")
        ])
        let outer = SPARQLSelectQuery(["friend", "label"], where: [
            pattern("friend", "http://example.org/label", "label"),
            .subquery(inner),
            .filter(.builtIn(.bound, [.variable("hidden")]))
        ])

        let issues = outer.validateSubqueryScopes()
        #expect(issues == [SPARQLSubqueryScopeIssue(variable: "hidden", subqueryProjection: ["friend"])])
    }

    @Test("Leaks from nested subqueries are reported at every level")
    func nestedLeaksAreReported() {
        let nested = SPARQLSelectQuery(["x"], where: [pattern("x", "http://example.org/secret", "nestedOnly")])
        let middle = SPARQLSelectQuery(["x"], where: [
            .subquery(nested),
            .filter(.builtIn(.bound, [.variable("nestedOnly")]))
        ])
        let outer = SPARQLSelectQuery(["x", "v"], where: [
            pattern("x", "http://example.org/q", "v"),
            .optional([.subquery(middle)]),
            .filter(.builtIn(.bound, [.variable("nestedOnly")]))
        ])

        #expect(outer.validateSubqueryScopes().contains { $0.variable == "nestedOnly" })
    }
}
