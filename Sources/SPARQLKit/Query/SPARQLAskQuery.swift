import IRIKit

/// An `ASK` query (SPARQL 1.2 Query Language §16.3).
public struct SPARQLAskQuery: SPARQLResultsQuery, Hashable {
    public var fromGraphs: [IRI]
    public var fromNamedGraphs: [IRI]
    public var patterns: [SPARQLPattern]

    public init(fromGraphs: [IRI] = [], fromNamedGraphs: [IRI] = [], where patterns: [SPARQLPattern]) {
        self.fromGraphs = fromGraphs
        self.fromNamedGraphs = fromNamedGraphs
        self.patterns = patterns
    }

    public func render() -> String {
        var lines = SPARQLLines()
        lines.append("ASK")
        for graph in fromGraphs { lines.append("FROM " + graph.render()) }
        for graph in fromNamedGraphs { lines.append("FROM NAMED " + graph.render()) }
        lines.block("WHERE") { SPARQLPattern.render(patterns, into: &$0) }
        return lines.text
    }
}
