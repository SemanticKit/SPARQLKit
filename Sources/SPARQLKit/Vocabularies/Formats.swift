import RDFCore
import RDFKit

/// The W3C Unique URIs for File Formats vocabulary.
///
/// A SPARQL service description names the result and input formats it
/// supports with these individuals (SPARQL 1.2 Service Description §3.2.14).
@Ontology
public struct Formats: Ontology {
    public var body: some Content {
        Namespace("http://www.w3.org/ns/formats/")

        Class("Format") {
            Type(RDFS.Class)
            Label("Format")
            Comment("A file format.")
        }

        Individual("JSON-LD") {
            Type(Formats.Format)
            Label("JSON-LD")
            Comment("The JSON-LD file format.")
        }
        Individual("N3") {
            Type(Formats.Format)
            Label("N3")
            Comment("The N3 file format.")
        }
        Individual("N-Triples") {
            Type(Formats.Format)
            Label("N-Triples")
            Comment("The N-Triples file format.")
        }
        Individual("N-Quads") {
            Type(Formats.Format)
            Label("N-Quads")
            Comment("The N-Quads file format.")
        }
        Individual("LD_Patch") {
            Type(Formats.Format)
            Label("LD Patch")
            Comment("The LD Patch file format.")
        }
        Individual("microdata") {
            Type(Formats.Format)
            Label("Microdata")
            Comment("The Microdata file format.")
        }
        Individual("OWL_XML") {
            Type(Formats.Format)
            Label("OWL XML Serialization")
            Comment("The OWL XML file format.")
        }
        Individual("OWL_Functional") {
            Type(Formats.Format)
            Label("OWL Functional Syntax")
            Comment("The OWL Functional Syntax file format.")
        }
        Individual("OWL_Manchester") {
            Type(Formats.Format)
            Label("OWL Manchester Syntax")
            Comment("The OWL Manchester Syntax file format.")
        }
        Individual("POWDER") {
            Type(Formats.Format)
            Label("POWDER")
            Comment("The POWDER file format.")
        }
        Individual("POWDER-S") {
            Type(Formats.Format)
            Label("POWDER-S")
            Comment("The POWDER-S file format.")
        }
        Individual("PROV-N") {
            Type(Formats.Format)
            Label("PROV-N")
            Comment("The PROV-N file format.")
        }
        Individual("PROV-XML") {
            Type(Formats.Format)
            Label("PROV-XML")
            Comment("The PROV-XML file format.")
        }
        Individual("RDF_JSON") {
            Type(Formats.Format)
            Label("RDF/JSON")
            Comment("The RDF/JSON file format.")
        }
        Individual("RDF_XML") {
            Type(Formats.Format)
            Label("RDF/XML")
            Comment("The RDF/XML file format.")
        }
        Individual("RIF_XML") {
            Type(Formats.Format)
            Label("RIF XML Syntax")
            Comment("The RIF XML file format.")
        }
        Individual("SPARQL_Results_XML") {
            Type(Formats.Format)
            Label("SPARQL Results in XML")
            Comment("The SPARQL Query Results XML Format.")
        }
        Individual("SPARQL_Results_JSON") {
            Type(Formats.Format)
            Label("SPARQL Results in JSON")
            Comment("The SPARQL Query Results JSON Format.")
        }
        Individual("SPARQL_Results_CSV") {
            Type(Formats.Format)
            Label("SPARQL Results in CSV")
            Comment("The SPARQL Query Results CSV Format.")
        }
        Individual("SPARQL_Results_TSV") {
            Type(Formats.Format)
            Label("SPARQL Results in TSV")
            Comment("The SPARQL Query Results TSV Format.")
        }
        Individual("Turtle") {
            Type(Formats.Format)
            Label("Turtle")
            Comment("The Turtle file format.")
        }
        Individual("TriG") {
            Type(Formats.Format)
            Label("TriG")
            Comment("The TriG file format.")
        }
    }
}
