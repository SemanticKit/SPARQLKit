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
        let writer = SPARQLTermWriter()
        var lines = SPARQLLines()
        lines.append("ASK")
        for graph in fromGraphs { lines.append("FROM " + writer.write(graph)) }
        for graph in fromNamedGraphs { lines.append("FROM NAMED " + writer.write(graph)) }
        lines.block("WHERE") { SPARQLPattern.render(patterns, into: &$0) }
        return lines.text
    }
}
