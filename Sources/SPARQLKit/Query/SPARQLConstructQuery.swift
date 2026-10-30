import IRIKit

/// A `CONSTRUCT` query (SPARQL 1.2 Query Language §16.2).
public struct SPARQLConstructQuery: SPARQLGraphQuery, Hashable {
    /// The triples the query builds for each solution.
    public var template: [SPARQLTriplePattern]
    public var fromGraphs: [IRI]
    public var fromNamedGraphs: [IRI]
    public var patterns: [SPARQLPattern]
    public var orderBy: [SPARQLOrderCondition]
    public var limit: UInt?
    public var offset: UInt?

    public init(
        _ template: [SPARQLTriplePattern],
        fromGraphs: [IRI] = [],
        fromNamedGraphs: [IRI] = [],
        where patterns: [SPARQLPattern],
        orderBy: [SPARQLOrderCondition] = [],
        limit: UInt? = nil,
        offset: UInt? = nil
    ) throws {
        // ConstructTemplate is built from TriplesSameSubject, whose verbs are
        // `VarOrIri | 'a'` (SPARQL 1.2 Query Language §19.8): no paths.
        for pattern in template where pattern.verb.isPath {
            throw SPARQLError.invalidRequest("A CONSTRUCT template cannot hold a property path.")
        }
        self.template = template
        self.fromGraphs = fromGraphs
        self.fromNamedGraphs = fromNamedGraphs
        self.patterns = patterns
        self.orderBy = orderBy
        self.limit = limit
        self.offset = offset
    }

    public func render() -> String {
        var lines = SPARQLLines()
        lines.block("CONSTRUCT") { lines in
            for pattern in template { lines.append(pattern.render()) }
        }
        for graph in fromGraphs { lines.append("FROM " + graph.render()) }
        for graph in fromNamedGraphs { lines.append("FROM NAMED " + graph.render()) }
        lines.block("WHERE") { SPARQLPattern.render(patterns, into: &$0) }
        if !orderBy.isEmpty {
            lines.append("ORDER BY " + orderBy.map { $0.render() }.joined(separator: " "))
        }
        if let limit { lines.append("LIMIT \(limit)") }
        if let offset { lines.append("OFFSET \(offset)") }
        return lines.text
    }
}
