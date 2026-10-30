import RDFCore
import RDFKit

/// A typed query a render case renders.
///
/// Each subclass of `sk:QueryTemplate` that ``SPARQLConformance`` declares is
/// one: its generated individual type conforms here and builds its query, so
/// a manifest names the query by the class its `sk:queryTemplate` node is
/// typed with.
public protocol SPARQLConformanceQueryTemplate: RDFCore.Resource, Sendable {
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
