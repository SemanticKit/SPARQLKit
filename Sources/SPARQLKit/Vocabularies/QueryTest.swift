import RDFCore
import RDFKit

/// The W3C query test vocabulary: the action of a query evaluation test.
@Ontology
public struct QueryTest: Ontology {
    public func content() -> Content {
        Namespace("http://www.w3.org/2001/sw/DataAccess/tests/test-query#")

        Property("query") {
            Label("query")
            Comment("The query document a test runs.")
        }
        Property("data") {
            Label("data")
            Comment("A document loaded into the default graph.")
        }
        Property("graphData") {
            Label("graph data")
            Comment("A document loaded as a named graph.")
        }
        Property("graph") {
            Label("graph")
            Comment("The document of a named graph.")
        }
    }
}
