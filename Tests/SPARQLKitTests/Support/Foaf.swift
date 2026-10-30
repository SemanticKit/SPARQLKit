import RDFCore
import RDFKit

/// The FOAF terms the tests query with: a test fixture, declared through
/// the DSL so that queries name these generated types, never IRIs.
@Ontology
struct Foaf: Ontology {
    var body: some Content {
        Namespace("http://xmlns.com/foaf/0.1/")

        Class("Agent") {
            Type(RDFS.Class)
            Label("Agent")
            Comment("An agent (eg. person, group, software or physical artifact).")
        }
        Class("Person") {
            Type(RDFS.Class)
            SubClassOf(Foaf.Agent)
            Label("Person")
            Comment("A person.")
        }
        Class("Document") {
            Type(RDFS.Class)
            Label("Document")
            Comment("A document.")
        }
        Property("name") {
            Label("name")
            Comment("A name for some thing.")
        }
        Property("knows") {
            Domain(Foaf.Person)
            Range(Foaf.Person)
            Label("knows")
            Comment("A person known by this person (indicating some level of reciprocated interaction between the parties).")
        }
        Property("page") {
            Range(Foaf.Document)
            Label("page")
            Comment("A page or document about this thing.")
        }
        Property("nick") {
            Label("nickname")
            Comment("A short informal nickname characterising an agent (includes login identifiers, IRC and other chat nicknames).")
        }
    }
}
