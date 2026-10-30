import EntailmentRegimes
import Formats
import Foundation
import IRIKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import RDFCore
import RDFFormats
import ServiceDescription
import Testing
@testable import SPARQLKit

@Suite("Service descriptions", .tags(.decoding, .vocabulary))
struct SPARQLServiceDescriptionTests {
    let select = SPARQLSelectQuery(["s"], where: [.triple(SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o")))])

    func client(_ session: MockSession) -> SPARQLEndpointClient {
        SPARQLEndpointClient(
            configuration: SPARQLEndpointConfiguration(queryURL: URL(string: "https://example.org/sparql")!),
            session: session
        )
    }

    /// A description of a service that names these result formats and
    /// entailment regimes, made in Swift: the service an instance of the
    /// translated `sd:Service` class, the regimes the translated
    /// `ent:Entailment` individuals.
    func service(resultFormats: [any Formats.Format] = [], regimes: [any EntailmentRegimes.Entailment] = []) -> SPARQLServiceDescription {
        let service = ServiceDescription.ServiceIndividual()
        service.resultFormat = resultFormats
        return SPARQLServiceDescription(service: service, entailmentRegimes: regimes)
    }

    /// The translated individuals of a vocabulary module that are members of
    /// a class.
    func individuals<Individual>(_ ontology: [any RDFCore.Description], _: Individual.Type) -> [Individual] {
        ontology.compactMap { $0 as? Individual }
    }

    @Test("A Turtle description decodes into the translated sd:Service and the individuals it names")
    func decodesIntoTranslatedIndividuals() throws {
        let turtle = try #require(String(data: try fixture("service_description.ttl"), encoding: .utf8))
        let decoded = try SPARQLServiceDescriptionDecoder().decode(turtle)
        let description = decoded.service

        #expect(description is ServiceDescription.ServiceIndividual)
        #expect(decoded.endpointURLs == [URL(string: "https://example.org/sparql")!])
        #expect(description.supportsLanguage(ServiceDescription.SPARQLQuery))
        #expect(!description.supportsLanguage(ServiceDescription.SPARQL10Query))
        #expect(description.hasFeature(ServiceDescription.UnionDefaultGraph))
        #expect(description.supports(SPARQLAccept.jsonResults))
        #expect(!description.supports(SPARQLAccept.xmlResults))
        #expect(description.supports(SPARQLGraphAccept.turtle))
        #expect(decoded.supportsEntailment(EntailmentRegimes.RDFS))
        #expect(!decoded.supportsEntailment(EntailmentRegimes.`OWL-Direct`))
    }

    @Test("A term the vocabularies do not declare names nothing and is left out")
    func undeclaredTermsAreLeftOut() throws {
        let description = try SPARQLServiceDescriptionDecoder().decode("""
            @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
            <https://example.org/sparql> sd:feature <https://example.org/vendor#FullText> , sd:EmptyGraphs .
            """).service
        #expect(description.feature.count == 1)
        #expect(description.hasFeature(ServiceDescription.EmptyGraphs))
    }

    @Test("A document that describes no service, or two, does not decode")
    func decodesExactlyOneService() {
        #expect(throws: SPARQLError.self) {
            try SPARQLServiceDescriptionDecoder().decode("<https://example.org/a> <https://example.org/b> <https://example.org/c> .")
        }
        #expect(throws: SPARQLError.self) {
            try SPARQLServiceDescriptionDecoder().decode("""
                @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
                <https://example.org/one> a sd:Service .
                <https://example.org/two> a sd:Service .
                """)
        }
    }

    @Test("Each media type maps to the format individual a description names")
    func mediaTypesMapToFormats() {
        #expect(SPARQLAccept.csv.format === Formats.SPARQL_Results_CSV)
        #expect(SPARQLGraphAccept.ntriples.format === Formats.`N-Triples`)
        let description = service(resultFormats: [Formats.SPARQL_Results_JSON, Formats.Turtle]).service
        #expect(description.supports(SPARQLAccept.jsonResults))
        #expect(!description.supports(SPARQLGraphAccept.ntriples))
        #expect(service().service.supports(SPARQLAccept.tsv))
    }

    @Test("Vocabulary IRIs decode back to their individuals, named graphs included", .tags(.vocabulary))
    func vocabularyIRIsDecode() throws {
        let decoded = try SPARQLServiceDescriptionDecoder().decode("""
            @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
            @prefix formats: <http://www.w3.org/ns/formats/> .
            @prefix entailment: <http://www.w3.org/ns/entailment/> .
            <https://example.org/sparql> a sd:Service ;
              sd:supportedLanguage sd:SPARQL11Update ;
              sd:feature sd:SPARQLQuery ;
              sd:resultFormat formats:N-Triples ;
              sd:defaultDataset [
                sd:namedGraph [
                  sd:name <https://example.org/graph> ;
                  sd:entailmentRegime entailment:OWL-Direct , entailment:Unknown
                ]
              ] .
            """)
        let description = decoded.service
        #expect(description.supportedLanguage.count == 1)
        #expect(description.supportedLanguage.first === ServiceDescription.SPARQL11Update)
        #expect(description.feature.count == 1)
        #expect(description.feature.first === ServiceDescription.SPARQLQuery)
        #expect(description.resultFormat.count == 1)
        #expect(description.resultFormat.first === Formats.`N-Triples`)
        #expect(description.defaultDataset.first?.namedGraph.count == 1)
        #expect(decoded.entailmentRegimes.count == 1)
        #expect(decoded.entailmentRegimes.first === EntailmentRegimes.`OWL-Direct`)
        #expect(decoded.supportsEntailment(EntailmentRegimes.`OWL-Direct`))
    }

    @Test("Every format the published formats vocabulary declares decodes into its individual", .tags(.vocabulary))
    func decodesEveryDeclaredFormat() throws {
        // Every format of http://www.w3.org/ns/formats/, as Overview.ttl
        // lists them (rdfs:seeAlso of formats:Format).
        let turtle = """
            @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
            @prefix formats: <http://www.w3.org/ns/formats/> .
            <https://example.org/sparql> a sd:Service ;
              sd:resultFormat formats:JSON-LD , formats:N3 , formats:N-Triples , formats:N-Quads ,
                formats:LD_Patch , formats:microdata , formats:OWL_XML , formats:OWL_Functional ,
                formats:OWL_Manchester , formats:POWDER , formats:POWDER-S , formats:PROV-N ,
                formats:PROV-XML , formats:RDFa , formats:RDF_JSON , formats:RDF_XML , formats:RIF_XML ,
                formats:SPARQL_Results_XML , formats:SPARQL_Results_JSON , formats:SPARQL_Results_CSV ,
                formats:SPARQL_Results_TSV , formats:Turtle , formats:TriG .
            """
        let decoded = try SPARQLServiceDescriptionDecoder().decode(turtle).service.resultFormat
        // The formats the translated vocabulary holds: the decoder must know
        // each of them, so the vocabulary and the decoder cannot drift.
        let declared = individuals(Formats.ontology, (any Formats.Format).self)

        #expect(declared.count == 23)
        #expect(decoded.count == 23)
        #expect(declared.allSatisfy { format in decoded.contains { $0 === format } })
        #expect(decoded.contains { $0 === Formats.RDFa })
    }

    @Test("Every entailment regime the published entailment documents describe decodes into its individual", .tags(.vocabulary))
    func decodesEveryDeclaredRegime() throws {
        // The regimes http://www.w3.org/ns/entailment/ lists (rdfs:seeAlso of
        // ent:Entailment), each named as the document its IRI dereferences
        // to describes it: OWL-RDF-Based.ttl describes ent:OWL-RDF-based.
        let turtle = """
            @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
            @prefix ent: <http://www.w3.org/ns/entailment/> .
            <https://example.org/sparql> a sd:Service ;
              sd:defaultEntailmentRegime ent:Simple , ent:RDF , ent:RDFS , ent:D , ent:OWL-RDF-based , ent:OWL-Direct , ent:RIF .
            """
        let decoded = try SPARQLServiceDescriptionDecoder().decode(turtle).entailmentRegimes
        let regimes: [any EntailmentRegimes.Entailment] = [
            EntailmentRegimes.Simple, EntailmentRegimes.RDF, EntailmentRegimes.RDFS, EntailmentRegimes.D,
            EntailmentRegimes.`OWL-RDF-based`, EntailmentRegimes.`OWL-Direct`, EntailmentRegimes.RIF
        ]

        #expect(decoded.count == regimes.count)
        #expect(zip(decoded, regimes).allSatisfy { $0 === $1 })
        // ent:RDF is its own individual, apart from the RDF module it shares
        // its name with.
        #expect(EntailmentRegimes.RDF !== EntailmentRegimes.RDFS)
    }

    @Test("Every language and feature the service description vocabulary declares decodes into its individual", .tags(.vocabulary))
    func decodesEveryDeclaredFeature() throws {
        let features = individuals(ServiceDescription.ontology, (any ServiceDescription.Feature).self)
        let languages = individuals(ServiceDescription.ontology, (any ServiceDescription.Language).self)
        let list = features.compactMap { IRI(of: $0) }.map { "<\($0.rawValue)>" }.joined(separator: " , ")
        let turtle = """
            @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
            <https://example.org/sparql> a sd:Service ;
              sd:feature \(list) ;
              sd:supportedLanguage \(list) .
            """
        let description = try SPARQLServiceDescriptionDecoder().decode(turtle).service

        // sparql-service-description.ttl declares five languages and five
        // other features.
        #expect(features.count == 10)
        #expect(languages.count == 5)
        #expect(description.feature.count == features.count)
        #expect(features.allSatisfy { description.hasFeature($0) })
        #expect(description.supportedLanguage.count == languages.count)
        #expect(languages.allSatisfy { description.supportsLanguage($0) })
        #expect(languages.allSatisfy { $0 is any ServiceDescription.Feature })
    }

    @Test("A result term decodes into the translated individual it denotes", .tags(.vocabulary))
    func iriDenotesTranslatedIndividual() throws {
        let terms = try fixtureIRIs("entailment_binding_terms.ttl")
        let binding: Binding = ["regime": .iri(terms.subject), "other": .iri(terms.object)]
        let regimes: [any EntailmentRegimes.Entailment] = [EntailmentRegimes.RDFS, EntailmentRegimes.`OWL-Direct`]
        #expect(binding.individual("regime", among: regimes) === EntailmentRegimes.`OWL-Direct`)
        #expect(binding.individual("other", among: regimes) == nil)
    }

    @Test("A description that names no entailment regime restricts none", .tags(.vocabulary))
    func noRegimeRestrictsNone() {
        #expect(service().supportsEntailment(EntailmentRegimes.RIF))
        #expect(service(regimes: [EntailmentRegimes.RDF]).supportsEntailment(EntailmentRegimes.RDF))
        #expect(!service(regimes: [EntailmentRegimes.RDF]).supportsEntailment(EntailmentRegimes.RIF))
    }

    @Test("An individual that is not an entailment regime does not decode as one", .tags(.vocabulary))
    func nonRegimesDoNotDecodeAsRegimes() throws {
        let turtle = """
            @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
            @prefix formats: <http://www.w3.org/ns/formats/> .
            <https://example.org/sparql> a sd:Service ;
              sd:defaultEntailmentRegime formats:Turtle , sd:SPARQLQuery .
            """
        #expect(try SPARQLServiceDescriptionDecoder().decode(turtle).entailmentRegimes.isEmpty)
        #expect(!(Formats.Turtle is any EntailmentRegimes.Entailment))
        #expect(!(ServiceDescription.SPARQLQuery is any EntailmentRegimes.Entailment))
    }

    @Test("The client refuses a result format the endpoint does not offer", .tags(.protocol))
    func refusesUnsupportedResultFormat() async {
        let session = MockSession()
        let description = service(resultFormats: [Formats.SPARQL_Results_JSON])
        await #expect(throws: SPARQLError.invalidRequest("Endpoint service description does not support requested result format.")) {
            _ = try await client(session).executeQuery(select, accept: .xmlResults, serviceDescription: description)
        }
        #expect(session.requests.isEmpty)
    }

    @Test("The client refuses a graph format the endpoint does not offer", .tags(.protocol))
    func refusesUnsupportedGraphFormat() async throws {
        let construct = try SPARQLConstructQuery(
            [SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o"))],
            where: [.triple(SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o")))]
        )
        let description = service(resultFormats: [Formats.Turtle])
        await #expect(throws: SPARQLError.invalidRequest("Endpoint service description does not support requested graph format.")) {
            _ = try await client(MockSession()).executeGraphQuery(construct, accept: .ntriples, serviceDescription: description)
        }
    }

    @Test("The client gates the entailment regime on the description", .tags(.protocol))
    func gatesEntailment() async throws {
        let description = service(regimes: [EntailmentRegimes.RDFS])
        let ask = SPARQLAskQuery(where: [.triple(SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o")))])

        await #expect(throws: SPARQLError.invalidRequest("Endpoint service description does not support requested entailment regime.")) {
            _ = try await client(MockSession()).executeQuery(
                ask,
                options: SPARQLQueryRequestOptions(requiredEntailmentRegime: EntailmentRegimes.`OWL-Direct`),
                serviceDescription: description
            )
        }

        let allowed = try await client(MockSession(body: #"{"boolean":true}"#)).executeQuery(
            ask,
            options: SPARQLQueryRequestOptions(requiredEntailmentRegime: EntailmentRegimes.RDFS),
            serviceDescription: description
        )
        #expect(String(data: allowed, encoding: .utf8) == #"{"boolean":true}"#)

        let ungated = try await client(MockSession(body: #"{"boolean":true}"#)).executeAsk(
            ask,
            options: SPARQLQueryRequestOptions(requiredEntailmentRegime: EntailmentRegimes.`OWL-Direct`)
        )
        #expect(ungated)
    }
}
