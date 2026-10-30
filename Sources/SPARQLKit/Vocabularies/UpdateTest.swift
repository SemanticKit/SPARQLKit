import RDFCore
import RDFKit

/// The W3C update test vocabulary: the action of an update evaluation test.
@Ontology
public struct UpdateTest: Ontology {
    public var body: some Content {
        Namespace("http://www.w3.org/2009/sparql/tests/test-update#")

        Property("request") {
            Label("request")
            Comment("The update document a test runs.")
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
