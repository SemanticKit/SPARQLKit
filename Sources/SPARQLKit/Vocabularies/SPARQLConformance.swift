import RDFCore
import RDFKit

/// SPARQLKit's conformance vocabulary: the kinds of case and the expectations
/// SPARQLKit's own manifests add to the W3C test manifest vocabulary.
@Ontology
public struct SPARQLConformance: Ontology {
    public var body: some Content {
        Namespace("https://codex.local/sparqlkit/conformance#")

        Class("DecodeJSONBindingsTest") {
            Type(RDFS.Class)
            Label("Decode JSON bindings test")
            Comment("A SPARQL Query Results JSON document with bindings.")
        }
        Class("DecodeJSONBooleanTest") {
            Type(RDFS.Class)
            Label("Decode JSON boolean test")
            Comment("A SPARQL Query Results JSON document with a boolean.")
        }
        Class("DecodeXMLBindingsTest") {
            Type(RDFS.Class)
            Label("Decode XML bindings test")
            Comment("A SPARQL Query Results XML document with bindings.")
        }
        Class("DecodeXMLBooleanTest") {
            Type(RDFS.Class)
            Label("Decode XML boolean test")
            Comment("A SPARQL Query Results XML document with a boolean.")
        }
        Class("DecodeCSVBindingsTest") {
            Type(RDFS.Class)
            Label("Decode CSV bindings test")
            Comment("A SPARQL Query Results CSV document.")
        }
        Class("DecodeTSVBindingsTest") {
            Type(RDFS.Class)
            Label("Decode TSV bindings test")
            Comment("A SPARQL Query Results TSV document.")
        }
        Class("RenderQueryTest") {
            Type(RDFS.Class)
            Label("Render query test")
            Comment("A typed query whose rendered SPARQL contains the expected fragments.")
        }
        Class("ProtocolGetQueryRequestTest") {
            Type(RDFS.Class)
            Label("Protocol GET query request test")
            Comment("A SPARQL Protocol query request sent with GET.")
        }
        Class("ProtocolPostQueryRequestTest") {
            Type(RDFS.Class)
            Label("Protocol POST query request test")
            Comment("A SPARQL Protocol query request sent with POST.")
        }
        Class("ProtocolPostUpdateRequestTest") {
            Type(RDFS.Class)
            Label("Protocol POST update request test")
            Comment("A SPARQL Protocol update request.")
        }
        Class("GraphStoreGetDefaultRequestTest") {
            Type(RDFS.Class)
            Label("Graph Store GET default graph request test")
            Comment("A Graph Store Protocol GET of the default graph.")
        }
        Class("GraphStoreHeadNamedRequestTest") {
            Type(RDFS.Class)
            Label("Graph Store HEAD named graph request test")
            Comment("A Graph Store Protocol HEAD of a named graph.")
        }
        Class("GraphStorePostServiceRequestTest") {
            Type(RDFS.Class)
            Label("Graph Store POST service request test")
            Comment("A Graph Store Protocol POST to the graph store.")
        }
        Class("GraphStorePutNamedRequestTest") {
            Type(RDFS.Class)
            Label("Graph Store PUT named graph request test")
            Comment("A Graph Store Protocol PUT of a named graph.")
        }
        Class("GraphStoreDeleteNamedRequestTest") {
            Type(RDFS.Class)
            Label("Graph Store DELETE named graph request test")
            Comment("A Graph Store Protocol DELETE of a named graph.")
        }

        Property("queryTemplate") {
            Label("query template")
            Comment("The typed query a render case renders.")
        }
        Property("query") {
            Label("query")
            Comment("The query a protocol case sends.")
        }
        Property("update") {
            Label("update")
            Comment("The update a protocol case sends.")
        }
        Property("defaultGraphURI") {
            Label("default graph URI")
            Comment("A default graph of the request's dataset.")
        }
        Property("namedGraphURI") {
            Label("named graph URI")
            Comment("A named graph of the request's dataset.")
        }
        Property("usingGraphURI") {
            Label("using graph URI")
            Comment("A default graph of the update's dataset.")
        }
        Property("usingNamedGraphURI") {
            Label("using named graph URI")
            Comment("A named graph of the update's dataset.")
        }
        Property("expectVariableCount") {
            Label("expect variable count")
            Comment("The number of variables the decoded results have.")
        }
        Property("expectBindingCount") {
            Label("expect binding count")
            Comment("The number of solutions the decoded results have.")
        }
        Property("expectBoolean") {
            Label("expect boolean")
            Comment("The boolean the decoded results hold.")
        }
        Property("expectContains") {
            Label("expect contains")
            Comment("A fragment the rendered query contains.")
        }
        Property("expectURLContains") {
            Label("expect URL contains")
            Comment("A fragment the request URL contains.")
        }
        Property("expectBodyContains") {
            Label("expect body contains")
            Comment("A fragment the request body contains.")
        }
        Property("expectHeaderContains") {
            Label("expect header contains")
            Comment("A header and a fragment its value contains, written Header:fragment.")
        }
    }
}
