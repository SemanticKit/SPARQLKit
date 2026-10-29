import IRIKit

/// A `DESCRIBE` query (SPARQL 1.2 Query Language §16.4).
public struct SPARQLDescribeQuery: SPARQLGraphQuery, Hashable {
    /// The variables and IRIs to describe; empty is `DESCRIBE *`.
    public var resources: [SPARQLPatternTerm]
    public var fromGraphs: [IRI]
    public var fromNamedGraphs: [IRI]
    /// The `WHERE` pattern; none when the query describes only IRIs.
    public var patterns: [SPARQLPattern]
    public var limit: Int?

    public init(
        _ resources: [SPARQLPatternTerm],
        fromGraphs: [IRI] = [],
        fromNamedGraphs: [IRI] = [],
        where patterns: [SPARQLPattern] = [],
        limit: Int? = nil
    ) {
        self.resources = resources
        self.fromGraphs = fromGraphs
        self.fromNamedGraphs = fromNamedGraphs
        self.patterns = patterns
        self.limit = limit
    }

    public func render() -> String {
        let writer = SPARQLTermWriter()
        var lines = SPARQLLines()
        lines.append("DESCRIBE " + (resources.isEmpty ? "*" : resources.map { $0.render() }.joined(separator: " ")))
        for graph in fromGraphs { lines.append("FROM " + writer.write(graph)) }
        for graph in fromNamedGraphs { lines.append("FROM NAMED " + writer.write(graph)) }
        if !patterns.isEmpty {
            lines.block("WHERE") { SPARQLPattern.render(patterns, into: &$0) }
        }
        if let limit { lines.append("LIMIT \(limit)") }
        return lines.text
    }
}
