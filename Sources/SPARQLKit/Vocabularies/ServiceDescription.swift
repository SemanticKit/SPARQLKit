import RDFCore
import RDFKit

/// The SPARQL 1.2 Service Description vocabulary (SPARQL 1.2 Service
/// Description §3).
///
/// A service description says what a SPARQL endpoint implements: the
/// languages, features, result formats and entailment regimes it supports.
/// ``SPARQLServiceDescriptionDecoder`` reads a description into these
/// generated terms; the IRIs stay in the document.
@Ontology
public struct ServiceDescription: Ontology {
    public func content() -> Content {
        Namespace("http://www.w3.org/ns/sparql-service-description#")

        Class("Service") {
            Type(RDFS.Class)
            Label("Service")
            Comment("A SPARQL service made available via the SPARQL Protocol.")
        }
        Class("Feature") {
            Type(RDFS.Class)
            Label("Feature")
            Comment("A feature of a SPARQL service.")
        }
        Class("Language") {
            Type(RDFS.Class)
            SubClassOf(ServiceDescription.Feature)
            Label("Language")
            Comment("One of the SPARQL languages, including specific configurations providing particular features or extensions.")
        }
        Class("Function") {
            Type(RDFS.Class)
            SubClassOf(ServiceDescription.Feature)
            Label("Function")
            Comment("A function that may be used in a SPARQL SELECT expression or a FILTER, HAVING, GROUP BY, ORDER BY, or BIND clause.")
        }
        Class("Aggregate") {
            Type(RDFS.Class)
            SubClassOf(ServiceDescription.Feature)
            Label("Aggregate")
            Comment("An aggregate that may be used in a SPARQL aggregate query besides the standard list of supported aggregates.")
        }
        Class("EntailmentRegime") {
            Type(RDFS.Class)
            SubClassOf(ServiceDescription.Feature)
            Label("Entailment Regime")
            Comment("An entailment regime used in basic graph pattern matching.")
        }
        Class("EntailmentProfile") {
            Type(RDFS.Class)
            SubClassOf(ServiceDescription.Feature)
            Label("Entailment Profile")
            Comment("A profile of an entailment regime.")
        }
        Class("GraphCollection") {
            Type(RDFS.Class)
            Label("Graph Collection")
            Comment("A collection of zero or more named graph descriptions.")
        }
        Class("Dataset") {
            Type(RDFS.Class)
            SubClassOf(ServiceDescription.GraphCollection)
            Label("Dataset")
            Comment("An RDF Dataset comprised of a default graph and zero or more named graphs.")
        }
        Class("Graph") {
            Type(RDFS.Class)
            Label("Graph")
            Comment("The description of an RDF graph.")
        }
        Class("NamedGraph") {
            Type(RDFS.Class)
            Label("Named Graph")
            Comment("A named graph having a name (via sd:name) and an optional graph description (via sd:graph).")
        }

        Individual("SPARQL10Query") {
            Type(ServiceDescription.Language)
            Label("SPARQL 1.0 Query")
            Comment("The SPARQL 1.0 Query Language.")
        }
        Individual("SPARQL11Query") {
            Type(ServiceDescription.Language)
            Label("SPARQL 1.1 Query")
            Comment("The SPARQL 1.1 Query Language.")
        }
        Individual("SPARQL11Update") {
            Type(ServiceDescription.Language)
            Label("SPARQL 1.1 Update")
            Comment("The SPARQL 1.1 Update language.")
        }
        Individual("SPARQL12Query") {
            Type(ServiceDescription.Language)
            Label("SPARQL 1.2 Query")
            Comment("The SPARQL 1.2 Query Language.")
        }
        Individual("SPARQL12Update") {
            Type(ServiceDescription.Language)
            Label("SPARQL 1.2 Update")
            Comment("The SPARQL 1.2 Update language.")
        }
        Individual("DereferencesURIs") {
            Type(ServiceDescription.Feature)
            Label("Dereferences URIs")
            Comment("The service dereferences IRIs used in FROM/FROM NAMED and USING/USING NAMED clauses.")
        }
        Individual("UnionDefaultGraph") {
            Type(ServiceDescription.Feature)
            Label("Union Default Graph")
            Comment("The default graph of the dataset is the RDF merge of the named graphs.")
        }
        Individual("RequiresDataset") {
            Type(ServiceDescription.Feature)
            Label("Requires Dataset")
            Comment("The service requires an explicit dataset declaration.")
        }
        Individual("EmptyGraphs") {
            Type(ServiceDescription.Feature)
            Label("Empty Graphs")
            Comment("The service supports graphs that contain no triples.")
        }
        Individual("BasicFederatedQuery") {
            Type(ServiceDescription.Feature)
            Label("Basic Federated Query")
            Comment("The service supports the SERVICE keyword of SPARQL 1.2 Federated Query.")
        }

        Property("endpoint") {
            Type(OWL.InverseFunctionalProperty)
            Domain(ServiceDescription.Service)
            Label("endpoint")
            Comment("A SPARQL endpoint that implements the SPARQL Protocol service for the service. The object is an IRI.")
        }
        Property("feature") {
            Domain(ServiceDescription.Service)
            Range(ServiceDescription.Feature)
            Label("feature")
            Comment("A supported feature.")
        }
        Property("defaultEntailmentRegime") {
            SubPropertyOf(ServiceDescription.feature)
            Domain(ServiceDescription.Service)
            Range(ServiceDescription.EntailmentRegime)
            Label("default entailment regime")
            Comment("The entailment regime used for basic graph pattern matching over the default dataset.")
        }
        Property("entailmentRegime") {
            Domain(ServiceDescription.NamedGraph)
            Range(ServiceDescription.EntailmentRegime)
            Label("entailment regime")
            Comment("The entailment regime used for basic graph pattern matching over a named graph.")
        }
        Property("defaultSupportedEntailmentProfile") {
            SubPropertyOf(ServiceDescription.feature)
            Domain(ServiceDescription.Service)
            Range(ServiceDescription.EntailmentProfile)
            Label("default supported entailment profile")
            Comment("A supported profile of the default entailment regime.")
        }
        Property("supportedEntailmentProfile") {
            Domain(ServiceDescription.NamedGraph)
            Range(ServiceDescription.EntailmentProfile)
            Label("supported entailment profile")
            Comment("A supported profile of the entailment regime used over a named graph.")
        }
        Property("extensionFunction") {
            SubPropertyOf(ServiceDescription.feature)
            Domain(ServiceDescription.Service)
            Range(ServiceDescription.Function)
            Label("extension function")
            Comment("A function that may be used in an expression.")
        }
        Property("extensionAggregate") {
            SubPropertyOf(ServiceDescription.feature)
            Domain(ServiceDescription.Service)
            Range(ServiceDescription.Aggregate)
            Label("extension aggregate")
            Comment("An aggregate that may be used in an aggregate query.")
        }
        Property("languageExtension") {
            SubPropertyOf(ServiceDescription.feature)
            Domain(ServiceDescription.Service)
            Range(ServiceDescription.Feature)
            Label("language extension")
            Comment("An implemented extension to the SPARQL Query or Update language.")
        }
        Property("supportedLanguage") {
            SubPropertyOf(ServiceDescription.feature)
            Domain(ServiceDescription.Service)
            Range(ServiceDescription.Language)
            Label("supported language")
            Comment("A SPARQL language that the service implements.")
        }
        Property("propertyFeature") {
            SubPropertyOf(ServiceDescription.feature)
            Domain(ServiceDescription.Service)
            Range(ServiceDescription.Feature)
            Label("property feature")
            Comment("An implemented feature accessed by using the named property.")
        }
        Property("defaultDataset") {
            Type(OWL.InverseFunctionalProperty)
            Domain(ServiceDescription.Service)
            Range(ServiceDescription.Dataset)
            Label("default dataset")
            Comment("The default dataset available when no explicit dataset is specified.")
        }
        Property("availableGraphs") {
            Domain(ServiceDescription.Service)
            Range(ServiceDescription.GraphCollection)
            Label("available graphs")
            Comment("The graphs allowed in the construction of a dataset.")
        }
        Property("resultFormat") {
            Domain(ServiceDescription.Service)
            Range(Formats.Format)
            Label("result format")
            Comment("A format that is supported for serializing query results.")
        }
        Property("inputFormat") {
            Domain(ServiceDescription.Service)
            Range(Formats.Format)
            Label("input format")
            Comment("A format that is supported for parsing RDF input.")
        }
        Property("defaultGraph") {
            Domain(ServiceDescription.Dataset)
            Range(ServiceDescription.Graph)
            Label("default graph")
            Comment("The description of the default graph of a dataset.")
        }
        Property("namedGraph") {
            Domain(ServiceDescription.GraphCollection)
            Range(ServiceDescription.NamedGraph)
            Label("named graph")
            Comment("The description of one of the named graphs of a graph collection.")
        }
        Property("name") {
            Domain(ServiceDescription.NamedGraph)
            Label("name")
            Comment("The name by which a named graph may be referenced in a FROM/FROM NAMED clause. The object is an IRI.")
        }
        Property("graph") {
            Domain(ServiceDescription.NamedGraph)
            Range(ServiceDescription.Graph)
            Label("graph")
            Comment("The graph description of a named graph.")
        }
    }
}
