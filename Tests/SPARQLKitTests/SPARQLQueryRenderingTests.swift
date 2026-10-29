import Testing
import IRIKit
import RDFCore
@testable import SPARQLKit

@Test
func selectQueryRenderingIncludesExpectedSections() throws {
    let query = SPARQLSelectQuery(
        prefixes: ["foaf": try IRI(validating: "http://xmlns.com/foaf/0.1/")],
        variables: [Variable(rawValue: "name"), Variable(rawValue: "count")],
        wherePatterns: [
            "?person foaf:name ?name .",
            "?person foaf:knows ?friend ."
        ],
        groupBy: [Variable(rawValue: "person"), Variable(rawValue: "name")],
        limit: 20
    )

    let rendered = query.render()

    #expect(rendered.contains("PREFIX foaf: <http://xmlns.com/foaf/0.1/>"))
    #expect(rendered.contains("SELECT ?name ?count"))
    #expect(rendered.contains("GROUP BY ?person ?name"))
    #expect(rendered.contains("LIMIT 20"))
}

@Test
func selectQueryRenderingIncludesGraphPatternCompositionClauses() throws {
    let query = SPARQLSelectQuery(
        variables: [Variable(rawValue: "s"), Variable(rawValue: "o2"), Variable(rawValue: "calc")],
        wherePatterns: ["?s ?p ?o ."],
        optionalBlocks: [["?s <http://example.org/opt> ?opt ."]],
        unionBlocks: [
            ["?s <http://example.org/p1> ?o1 ."],
            ["?s <http://example.org/p2> ?o2 ."]
        ],
        minusBlocks: [["?s <http://example.org/blocked> ?x ."]],
        graphBlocks: [
            SPARQLGraphPatternClause(
                graphIRI: try IRI(validating: "http://example.org/graph"),
                patterns: ["?s <http://example.org/inGraph> ?g ."]
            )
        ],
        filters: ["BOUND(?o2)"],
        bindClauses: [SPARQLBindClause(expression: "STRLEN(STR(?o2))", variable: Variable(rawValue: "calc"))],
        valuesClauses: [SPARQLValuesClause(
            variables: [Variable(rawValue: "s")],
            rows: [["<http://example.org/a>"], ["<http://example.org/b>"]]
        )]
    )

    let rendered = query.render()

    #expect(rendered.contains("OPTIONAL {"))
    #expect(rendered.contains("UNION {"))
    #expect(rendered.contains("MINUS {"))
    #expect(rendered.contains("GRAPH <http://example.org/graph> {"))
    #expect(rendered.contains("FILTER(BOUND(?o2))"))
    #expect(rendered.contains("BIND(STRLEN(STR(?o2)) AS ?calc)"))
    #expect(rendered.contains("VALUES ?s {"))
}

@Test
func selectQueryRenderingIncludesModifiersAndDatasetClauses() throws {
    let query = SPARQLSelectQuery(
        variables: [Variable(rawValue: "s"), Variable(rawValue: "count")],
        wherePatterns: ["?s <http://example.org/p> ?o ."],
        valuesClauses: [SPARQLValuesClause(
            variables: [Variable(rawValue: "s"), Variable(rawValue: "o")],
            rows: [["<http://example.org/a>", "\"one\""], ["UNDEF", "\"two\""]]
        )],
        fromGraphs: [try IRI(validating: "http://example.org/default")],
        fromNamedGraphs: [try IRI(validating: "http://example.org/named")],
        distinct: true,
        groupBy: [Variable(rawValue: "s")],
        having: ["(COUNT(?o) > 1)"],
        orderBy: [SPARQLOrderByClause(expression: "?s", ascending: false)],
        limit: 10,
        offset: 20
    )

    let rendered = query.render()

    #expect(rendered.contains("SELECT DISTINCT ?s ?count"))
    #expect(rendered.contains("FROM <http://example.org/default>"))
    #expect(rendered.contains("FROM NAMED <http://example.org/named>"))
    #expect(rendered.contains("GROUP BY ?s"))
    #expect(rendered.contains("HAVING ((COUNT(?o) > 1))"))
    #expect(rendered.contains("ORDER BY DESC(?s)"))
    #expect(rendered.contains("LIMIT 10"))
    #expect(rendered.contains("OFFSET 20"))
    #expect(rendered.contains("VALUES (?s ?o) {"))
    #expect(rendered.contains("(UNDEF \"two\")"))
}

@Test
func selectQueryRenderingIncludesSubqueryAndInlineValues() throws {
    let inner = SPARQLSelectQuery(
        variables: [Variable(rawValue: "s")],
        wherePatterns: ["?s <http://example.org/p> ?o ."],
        valuesClauses: [
            SPARQLValuesClause(
                variables: [Variable(rawValue: "s")],
                rows: [["<http://example.org/a>"], ["<http://example.org/b>"]]
            )
        ],
        limit: 5
    )

    let outer = SPARQLSelectQuery(
        variables: [Variable(rawValue: "s")],
        wherePatterns: [],
        subqueries: [inner]
    )

    let rendered = outer.render()

    #expect(rendered.contains("{\n    SELECT ?s"))
    #expect(rendered.contains("VALUES ?s {"))
    #expect(rendered.contains("<http://example.org/a>"))
    #expect(rendered.contains("LIMIT 5"))
}

@Test
func selectQueryRenderingIncludesPropertyPathsAndExpressionOperators() throws {
    let knows = SPARQLPropertyPath.iri(try IRI(validating: "http://example.org/knows"))
    let colleague = SPARQLPropertyPath.iri(try IRI(validating: "http://example.org/colleague"))
    let relationPath = SPARQLPropertyPath.oneOrMore(
        .alternative([
            knows,
            .inverse(colleague)
        ])
    )

    let scoreExpression = SPARQLExpression.binary(
        .function("STRLEN", [.function("STR", [.variable(Variable(rawValue: "name"))])]),
        .add,
        .literal("1")
    )
    let filterExpression = SPARQLExpression.binary(
        .binary(
            .variable(Variable(rawValue: "score")),
            .greaterThanOrEqual,
            .literal("3")
        ),
        .and,
        .binary(
            .variable(Variable(rawValue: "name")),
            .notEqual,
            .literal("\"\"")
        )
    )

    let query = SPARQLSelectQuery(
        variables: [Variable(rawValue: "s"), Variable(rawValue: "o"), Variable(rawValue: "score")],
        wherePatterns: ["?s <http://example.org/name> ?name ."],
        pathPatterns: [SPARQLPathPattern(subject: "?s", path: relationPath, object: "?o")],
        filterExpressions: [filterExpression],
        bindClauses: [SPARQLBindClause(expression: scoreExpression, variable: Variable(rawValue: "score"))]
    )

    let rendered = query.render()

    #expect(rendered.contains("?s (<http://example.org/knows>|^<http://example.org/colleague>)+ ?o ."))
    #expect(rendered.contains("BIND((STRLEN(STR(?name)) + 1) AS ?score)"))
    #expect(rendered.contains("FILTER(((?score >= 3) && (?name != \"\")))"))
}

@Test
func subqueryScopeValidationAllowsProjectedVariables() {
    let inner = SPARQLSelectQuery(
        variables: [Variable(rawValue: "friend")],
        wherePatterns: ["?person <http://example.org/knows> ?friend ."]
    )
    let outer = SPARQLSelectQuery(
        variables: [Variable(rawValue: "person"), Variable(rawValue: "friend")],
        wherePatterns: ["?friend <http://example.org/name> ?name ."],
        subqueries: [inner]
    )

    let issues = outer.validateSubqueryScopes()
    #expect(issues.isEmpty)
}

@Test
func subqueryScopeValidationDetectsUnprojectedVariableLeakage() {
    let inner = SPARQLSelectQuery(
        variables: [Variable(rawValue: "friend")],
        wherePatterns: [
            "?person <http://example.org/knows> ?friend .",
            "?friend <http://example.org/secret> ?hidden ."
        ]
    )
    let outer = SPARQLSelectQuery(
        variables: [Variable(rawValue: "friend"), Variable(rawValue: "label")],
        wherePatterns: ["?friend <http://example.org/label> ?label ."],
        subqueries: [inner],
        filters: ["BOUND(?hidden)"]
    )

    let issues = outer.validateSubqueryScopes()
    #expect(issues.count == 1)
    #expect(issues.first?.variable == Variable(rawValue: "hidden"))
}

@Test
func subqueryScopeValidationDetectsNestedUnprojectedVariableLeakage() {
    let nested = SPARQLSelectQuery(
        variables: [Variable(rawValue: "x")],
        wherePatterns: ["?x <http://example.org/secret> ?nestedOnly ."]
    )
    let middle = SPARQLSelectQuery(
        variables: [Variable(rawValue: "x")],
        wherePatterns: [],
        subqueries: [nested],
        filters: ["BOUND(?nestedOnly)"]
    )
    let outer = SPARQLSelectQuery(
        variables: [Variable(rawValue: "x"), Variable(rawValue: "v")],
        wherePatterns: ["?x <http://example.org/q> ?v ."],
        subqueries: [middle],
        filters: ["BOUND(?nestedOnly)"]
    )

    let issues = outer.validateSubqueryScopes()
    #expect(issues.contains { $0.variable == Variable(rawValue: "nestedOnly") })
}

@Test
func propertyPathRenderingHandlesSequenceAlternativeAndClosureGrouping() throws {
    let p1 = SPARQLPropertyPath.iri(try IRI(validating: "http://example.org/p1"))
    let p2 = SPARQLPropertyPath.iri(try IRI(validating: "http://example.org/p2"))
    let p3 = SPARQLPropertyPath.iri(try IRI(validating: "http://example.org/p3"))
    let path = SPARQLPropertyPath.sequence([
        .zeroOrMore(.alternative([p1, p2])),
        .zeroOrOne(.inverse(p3))
    ])

    let rendered = SPARQLPathPattern(subject: "?s", path: path, object: "?o").render()
    #expect(rendered == "?s (<http://example.org/p1>|<http://example.org/p2>)*/(^<http://example.org/p3>)? ?o .")
}

@Test
func expressionRenderingHandlesUnaryAndFunctionForms() throws {
    let expression = SPARQLExpression.unary(
        .logicalNot,
        .binary(
            .function("BOUND", [.variable(Variable(rawValue: "x"))]),
            .or,
            .unary(.unaryMinus, .literal("2"))
        )
    )
    let bind = SPARQLBindClause(expression: expression, variable: Variable(rawValue: "flag"))

    #expect(bind.render() == "BIND(!((BOUND(?x) || -(2))) AS ?flag)")
}

@Test
func askQueryRenderingIncludesWhereClause() throws {
    let query = SPARQLAskQuery(
        prefixes: ["foaf": try IRI(validating: "http://xmlns.com/foaf/0.1/")],
        wherePatterns: [
            "?person foaf:name ?name .",
            "FILTER(?name = \"Alice\")"
        ]
    )

    let rendered = query.render()

    #expect(rendered.contains("ASK"))
    #expect(rendered.contains("WHERE {"))
    #expect(rendered.contains("FILTER(?name = \"Alice\")"))
}

@Test
func constructQueryRenderingIncludesTemplates() throws {
    let query = SPARQLConstructQuery(
        prefixes: ["foaf": try IRI(validating: "http://xmlns.com/foaf/0.1/")],
        constructPatterns: ["?person foaf:label ?name ."],
        wherePatterns: ["?person foaf:name ?name ."],
        limit: 10
    )

    let rendered = query.render()

    #expect(rendered.contains("CONSTRUCT {"))
    #expect(rendered.contains("?person foaf:label ?name ."))
    #expect(rendered.contains("WHERE {"))
    #expect(rendered.contains("LIMIT 10"))
}

@Test
func describeQueryRenderingIncludesResourcesAndVariables() throws {
    let query = SPARQLDescribeQuery(
        variables: [Variable(rawValue: "person")],
        iris: [try IRI(validating: "http://example.org/alice")],
        wherePatterns: ["?person ?p ?o ."],
        limit: 5
    )

    let rendered = query.render()

    #expect(rendered.contains("DESCRIBE ?person <http://example.org/alice>"))
    #expect(rendered.contains("WHERE {"))
    #expect(rendered.contains("LIMIT 5"))
}
