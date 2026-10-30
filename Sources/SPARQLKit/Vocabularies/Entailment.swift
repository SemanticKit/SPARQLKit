import RDFCore
import RDFKit

/// The W3C Unique URIs for Semantic Web Entailment Regimes.
///
/// Each regime is an individual of ``ServiceDescription/EntailmentRegime``
/// (`sd:EntailmentRegime`): a SPARQL service description names the
/// entailment regimes it uses for basic graph pattern matching with these
/// individuals (SPARQL 1.2 Service Description §3.3.6, SPARQL 1.2
/// Entailment Regimes).
@Ontology
public struct Entailment: Ontology {
    public var body: some Content {
        Namespace("http://www.w3.org/ns/entailment/")

        Individual("Simple") {
            Type(ServiceDescription.EntailmentRegime)
            Label("Simple Entailment")
            Comment("Simple entailment (RDF 1.2 Semantics).")
        }
        Individual("RDF") {
            Type(ServiceDescription.EntailmentRegime)
            Label("RDF Entailment")
            Comment("RDF entailment (RDF 1.2 Semantics).")
        }
        Individual("RDFS") {
            Type(ServiceDescription.EntailmentRegime)
            Label("RDFS Entailment")
            Comment("RDFS entailment (RDF 1.2 Semantics).")
        }
        Individual("D") {
            Type(ServiceDescription.EntailmentRegime)
            Label("D-Entailment")
            Comment("Datatype entailment (RDF 1.2 Semantics).")
        }
        Individual("OWL-Direct") {
            Type(ServiceDescription.EntailmentRegime)
            Label("OWL 2 Direct Semantics")
            Comment("Entailment under the OWL 2 Direct Semantics.")
        }
        Individual("OWL-RDF-Based") {
            Type(ServiceDescription.EntailmentRegime)
            Label("OWL 2 RDF-Based Semantics")
            Comment("Entailment under the OWL 2 RDF-Based Semantics.")
        }
        Individual("RIF") {
            Type(ServiceDescription.EntailmentRegime)
            Label("RIF Core Entailment")
            Comment("Entailment under RIF Core.")
        }
    }
}
