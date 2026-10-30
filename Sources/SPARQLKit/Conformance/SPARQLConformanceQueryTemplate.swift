import RDF
import RDFCore
import SPARQLConformance

/// A typed query a render case renders.
///
/// Each subclass of `sk:QueryTemplate` that the translated `SPARQLConformance`
/// vocabulary declares is one: its generated class conforms here and builds
/// its query, so
/// a manifest names the query by the class its `sk:queryTemplate` node is
/// typed with.
public protocol SPARQLConformanceQueryTemplate: RDFCore.ResourceClass, Sendable {
    /// The typed query this template builds.
    var query: any SPARQLQueryRenderable { get }
}

/// `sk:BasicSelectQuery`: the solutions of `?s rdf:value ?o`, limited to five.
extension SPARQLConformance.BasicSelectQueryIndividual: SPARQLConformanceQueryTemplate {
    public var query: any SPARQLQueryRenderable {
        SPARQLSelectQuery(
            ["s", "o"],
            where: [.triple(SPARQLTriplePattern(.variable("s"), .property(RDF.value.sparql), .variable("o")))],
            limit: 5
        )
    }
}
