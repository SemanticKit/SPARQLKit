import RDFCore
import RDFKit

/// The W3C test manifest vocabulary the SPARQL test suites are written in.
@Ontology
public struct TestManifest: Ontology {
    public func content() -> Content {
        Namespace("http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#")

        Class("Manifest") {
            Type(RDFS.Class)
            Label("Manifest")
            Comment("A set of tests.")
        }
        Class("QueryEvaluationTest") {
            Type(RDFS.Class)
            Label("Query evaluation test")
            Comment("A query whose results over the test data are the expected result.")
        }
        Class("UpdateEvaluationTest") {
            Type(RDFS.Class)
            Label("Update evaluation test")
            Comment("An update whose effect on the test dataset is the expected dataset.")
        }
        Class("CSVResultFormatTest") {
            Type(RDFS.Class)
            Label("CSV result format test")
            Comment("A query whose CSV results are the expected result.")
        }
        Property("include") {
            Label("include")
            Comment("A list of further manifests whose tests belong to this one.")
        }
        Property("entries") {
            Label("entries")
            Comment("The list of tests in this manifest.")
        }
        Property("name") {
            Label("name")
            Comment("The name of a test.")
        }
        Property("action") {
            Label("action")
            Comment("What a test runs.")
        }
        Property("result") {
            Label("result")
            Comment("The document a test expects.")
        }
    }
}
