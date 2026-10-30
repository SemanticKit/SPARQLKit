import Foundation
import IRIKit
import RDFCore
import RDFKit
import Testing
@testable import SPARQLKit

@Suite("Typed queries refuse what the SPARQL grammar does not allow", .tags(.rendering, .security))
struct SPARQLGrammarValidationTests {
    let anything = [SPARQLPattern.triple(SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o")))]

    @Test("A variable name must be a VARNAME", arguments: ["s } DROP ALL #", "", "?", "a b", "x.y", "-x", "?a-b", "$s\n"])
    func invalidVariableNamesAreRefused(name: String) {
        #expect(throws: SPARQLError.self) { try Variable(name) }
    }

    @Test("Valid VARNAMEs, with or without their marker, are accepted", arguments: [
        ("?s", "s"), ("$_x1", "_x1"), ("1st", "1st"), ("café·\u{0301}", "café·\u{0301}")
    ])
    func validVariableNames(text: String, name: String) throws {
        #expect(try Variable(text).name == name)
    }

    @Test("A results header cannot inject text through a variable name", .tags(.decoding))
    func resultHeadersCannotInject() {
        let json = #"{"head":{"vars":["s } DROP ALL #"]},"results":{"bindings":[]}}"#
        #expect(throws: SPARQLError.decodingFailure("'s } DROP ALL #' is not a SPARQL variable name.")) {
            try SPARQLJSONResultDecoder().decode(Data(json.utf8)) as SPARQLResultSet
        }
        let binding = #"{"head":{"vars":["s"]},"results":{"bindings":[{"s }":{"type":"literal","value":"x"}}]}}"#
        #expect(throws: SPARQLError.self) { try SPARQLJSONResultDecoder().decode(Data(binding.utf8)) as SPARQLResultSet }
        let xml = """
            <?xml version="1.0"?>
            <sparql xmlns="http://www.w3.org/2005/sparql-results#"><head><variable name="a b"/></head><results/></sparql>
            """
        #expect(throws: SPARQLError.self) { try SPARQLXMLResultDecoder().decode(Data(xml.utf8)) as SPARQLResultSet }
        #expect(throws: SPARQLError.self) { try SPARQLCSVResultDecoder().decode(Data("a b\r\nx\r\n".utf8)) }
        #expect(throws: SPARQLError.self) { try SPARQLTSVResultDecoder().decode(Data("?a}\n\"x\"\n".utf8)) }
    }

    @Test("A blank node label must be a BLANK_NODE_LABEL", arguments: ["a b.", "", "x.", ".x", "-x", "a}"])
    func invalidBlankNodeLabelsAreRefused(label: String) {
        #expect(throws: SPARQLError.self) { try SPARQLBlankNode(label) }
    }

    @Test("Valid blank node labels render as one token")
    func validBlankNodeLabels() throws {
        #expect(SPARQLPatternTerm.blankNode(try SPARQLBlankNode("_:b1")).render() == "_:b1")
        #expect(SPARQLPatternTerm.blankNode(try SPARQLBlankNode("a.b-c")).render() == "_:a.b-c")
        #expect(SPARQLPatternTerm.blankNode(try SPARQLBlankNode("0")).render() == "_:0")
    }

    @Test("A VALUES row must hold one entry per variable")
    func valuesRowWidthIsChecked() throws {
        #expect(throws: SPARQLError.invalidRequest("A VALUES row has 1 entries for 2 variables.")) {
            try SPARQLValues(variables: ["s", "o"], rows: [[.iri("http://example.org/a")]])
        }
        #expect(throws: SPARQLError.self) {
            try SPARQLValues(variables: ["s"], rows: [[.iri("http://example.org/a"), nil]])
        }
        #expect(try SPARQLValues(variables: ["s", "o"], rows: [[nil, nil]]).rows.count == 1)
    }

    @Test("A VALUES entry is a term, not a variable or a blank node")
    func valuesEntriesAreTerms() throws {
        #expect(throws: SPARQLError.self) { try SPARQLValues(variables: ["s"], rows: [[.variable("x")]]) }
        #expect(throws: SPARQLError.self) { try SPARQLValues(variables: ["s"], rows: [[.blankNode(try SPARQLBlankNode("b"))]]) }
    }

    @Test("LIMIT and OFFSET are unsigned, as LimitClause and OffsetClause require")
    func limitAndOffsetAreUnsigned() {
        let query = SPARQLSelectQuery(where: anything, limit: 0, offset: UInt.max)
        #expect(query.render().hasSuffix("LIMIT 0\nOFFSET \(UInt.max)"))
        #expect(UInt?.self == type(of: query.limit))
    }

    @Test("A GRAPH name is an IRI or a variable")
    func graphNameIsIRIOrVariable() {
        let named = SPARQLPattern.graph(.iri("http://example.org/g"), anything)
        let ranging = SPARQLPattern.graph(.variable("g"), anything)
        #expect(SPARQLSelectQuery(where: [named]).render().contains("GRAPH <http://example.org/g> {"))
        #expect(SPARQLSelectQuery(where: [ranging]).render().contains("GRAPH ?g {"))
        #expect(ranging.boundVariables == ["g", "s", "p", "o"])
    }

    @Test("DESCRIBE names variables and IRIs only")
    func describeNamesVariablesAndIRIs() throws {
        #expect(throws: SPARQLError.self) { try SPARQLDescribeQuery([.literal(Literal("x"))]) }
        #expect(throws: SPARQLError.self) { try SPARQLDescribeQuery([.blankNode(try SPARQLBlankNode("b"))]) }
        #expect(try SPARQLDescribeQuery([.term(Foaf.PersonIndividual.sparql)]).render() == "DESCRIBE <http://xmlns.com/foaf/0.1/Person>")
    }

    @Test("A CONSTRUCT template holds triples, not property paths")
    func constructTemplateHoldsNoPaths() {
        #expect(throws: SPARQLError.self) {
            try SPARQLConstructQuery(
                [SPARQLTriplePattern(.variable("s"), .path(.oneOrMore(.property(Foaf.knows.sparql))), .variable("o"))],
                where: anything
            )
        }
    }
}
