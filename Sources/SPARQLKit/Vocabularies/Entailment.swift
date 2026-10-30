import RDFCore
import RDFKit

/// The W3C Unique URIs for Semantic Web Entailment Regimes.
///
/// A SPARQL service description names the entailment regimes it uses for
/// basic graph pattern matching with these individuals (SPARQL 1.2 Service
/// Description §3.3.6, SPARQL 1.2 Entailment Regimes).
@Ontology
public struct Entailment: Ontology {
    public var body: some Content {
        Namespace("http://www.w3.org/ns/entailment/")

        Individual("Simple") {
            Label("Simple Entailment")
            Comment("Simple entailment (RDF 1.2 Semantics).")
        }
        Individual("RDF") {
            Label("RDF Entailment")
            Comment("RDF entailment (RDF 1.2 Semantics).")
        }
        Individual("RDFS") {
            Label("RDFS Entailment")
            Comment("RDFS entailment (RDF 1.2 Semantics).")
        }
        Individual("D") {
            Label("D-Entailment")
            Comment("Datatype entailment (RDF 1.2 Semantics).")
        }
        Individual("OWL-Direct") {
            Label("OWL 2 Direct Semantics")
            Comment("Entailment under the OWL 2 Direct Semantics.")
        }
        Individual("OWL-RDF-Based") {
            Label("OWL 2 RDF-Based Semantics")
            Comment("Entailment under the OWL 2 RDF-Based Semantics.")
        }
        Individual("RIF") {
            Label("RIF Core Entailment")
            Comment("Entailment under RIF Core.")
        }
    }
}
