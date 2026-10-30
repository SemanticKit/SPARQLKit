import EntailmentRegimes
import Formats
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import RDFCore
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

    /// A service that names these result formats, made in Swift as an
    /// instance of the translated `sd:Service` class.
    func service(resultFormats: [any Formats.Format] = [], regimes: [any ServiceDescription.EntailmentRegime] = []) -> any ServiceDescription.Service {
        let service = ServiceDescription.ServiceIndividual()
        service.resultFormat = resultFormats
        service.defaultEntailmentRegime = regimes
        return service
    }

    /// The translated individuals of a vocabulary module that are members of
    /// a class.
    func individuals<Individual>(_ ontology: [any RDFCore.Description], _: Individual.Type) -> [Individual] {
        ontology.compactMap { $0 as? Individual }
    }

    @Test("A Turtle description decodes into the translated sd:Service and the individuals it names")
    func decodesIntoTranslatedIndividuals() throws {
        let turtle = try #require(String(data: try fixture("service_description.ttl"), encoding: .utf8))
        let description = try SPARQLServiceDescriptionDecoder().decode(turtle)

        #expect(description is ServiceDescription.ServiceIndividual)
        #expect(description.endpointURLs == [URL(string: "https://example.org/sparql")!])
        #expect(description.supportsLanguage(ServiceDescription.SPARQLQuery))
        #expect(!description.supportsLanguage(ServiceDescription.SPARQL10Query))
        #expect(description.hasFeature(ServiceDescription.UnionDefaultGraph))
        #expect(description.supports(SPARQLAccept.jsonResults))
        #expect(!description.supports(SPARQLAccept.xmlResults))
        #expect(description.supports(SPARQLGraphAccept.turtle))
        #expect(description.supportsEntailment(EntailmentRegimes.RDFS))
        #expect(!description.supportsEntailment(EntailmentRegimes.`OWL-Direct`))
    }

    @Test("A term the vocabularies do not declare names nothing and is left out")
    func undeclaredTermsAreLeftOut() throws {
        let description = try SPARQLServiceDescriptionDecoder().decode("""
            @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
            <https://example.org/sparql> sd:feature <https://example.org/vendor#FullText> , sd:EmptyGraphs .
            """)
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
        let description = service(resultFormats: [Formats.SPARQL_Results_JSON, Formats.Turtle])
        #expect(description.supports(SPARQLAccept.jsonResults))
        #expect(!description.supports(SPARQLGraphAccept.ntriples))
        #expect(service().supports(SPARQLAccept.tsv))
    }

    @Test("Vocabulary IRIs decode back to their individuals, named graphs included", .tags(.vocabulary))
    func vocabularyIRIsDecode() throws {
        let description = try SPARQLServiceDescriptionDecoder().decode("""
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
        #expect(description.supportedLanguage.count == 1)
        #expect(description.supportedLanguage.first === ServiceDescription.SPARQL11Update)
        #expect(description.feature.count == 1)
        #expect(description.feature.first === ServiceDescription.SPARQLQuery)
        #expect(description.resultFormat.count == 1)
        #expect(description.resultFormat.first === Formats.`N-Triples`)
        let namedGraph = try #require(description.defaultDataset.first?.namedGraph.first)
        #expect(namedGraph.entailmentRegime.count == 1)
        #expect(namedGraph.entailmentRegime.first === EntailmentRegimes.`OWL-Direct`)
        #expect(description.entailmentRegimes.count == 1)
        #expect(description.supportsEntailment(EntailmentRegimes.`OWL-Direct`))
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
        let decoded = try SPARQLServiceDescriptionDecoder().decode(turtle).resultFormat
        // The formats the translated vocabulary holds: the decoder must know
        // each of them, so the vocabulary and the decoder cannot drift.
        let declared = individuals(Formats.ontology, (any Formats.Format).self)

        #expect(declared.count == 23)
        #expect(decoded.count == 23)
        #expect(declared.allSatisfy { format in decoded.contains { $0 === format } })
        #expect(decoded.contains { $0 === Formats.RDFa })
    }

    @Test("Every entailment regime of SPARQL 1.2 Entailment Regimes decodes into its individual", .tags(.vocabulary))
    func decodesEveryDeclaredRegime() throws {
        let turtle = """
            @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
            @prefix ent: <http://www.w3.org/ns/entailment/> .
            <https://example.org/sparql> a sd:Service ;
              sd:defaultEntailmentRegime ent:RDFS , ent:D , ent:OWL-RDF-Based , ent:OWL-Direct , ent:RIF , ent:Simple .
            """
        let decoded = try SPARQLServiceDescriptionDecoder().decode(turtle).defaultEntailmentRegime
        let declared = individuals(EntailmentRegimes.ontology, (any ServiceDescription.EntailmentRegime).self)
        let regimes: [any ServiceDescription.EntailmentRegime] = [
            EntailmentRegimes.RDFS, EntailmentRegimes.D, EntailmentRegimes.`OWL-RDF-Based`,
            EntailmentRegimes.`OWL-Direct`, EntailmentRegimes.RIF
        ]

        // ent:Simple is an ent:Entailment, but SPARQL 1.2 Entailment Regimes
        // defines no regime for it, so it is no sd:EntailmentRegime.
        #expect(declared.count == regimes.count)
        #expect(decoded.count == regimes.count)
        #expect(zip(decoded, regimes).allSatisfy { $0 === $1 })
        #expect(!(EntailmentRegimes.Simple is any ServiceDescription.EntailmentRegime))
    }

    @Test("Every language and feature the service description vocabulary declares decodes into its individual", .tags(.vocabulary))
    func decodesEveryDeclaredFeature() throws {
        let features = individuals(ServiceDescription.ontology, (any ServiceDescription.Feature).self)
        let languages = individuals(ServiceDescription.ontology, (any ServiceDescription.Language).self)
        let list = features.compactMap { $0.iri }.map { "<\($0.rawValue)>" }.joined(separator: " , ")
        let turtle = """
            @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
            <https://example.org/sparql> a sd:Service ;
              sd:feature \(list) ;
              sd:supportedLanguage \(list) .
            """
        let description = try SPARQLServiceDescriptionDecoder().decode(turtle)

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
        let binding: Binding = [
            "regime": .iri("http://www.w3.org/ns/entailment/OWL-Direct"),
            "other": .iri("http://www.w3.org/ns/entailment/Unknown")
        ]
        let regimes: [any ServiceDescription.EntailmentRegime] = [EntailmentRegimes.RDFS, EntailmentRegimes.`OWL-Direct`]
        #expect(binding.individual("regime", among: regimes) === EntailmentRegimes.`OWL-Direct`)
        #expect(binding.individual("other", among: regimes) == nil)
    }

    @Test("Every entailment regime is a feature by its type", .tags(.vocabulary))
    func regimesAreFeatures() {
        let regimes = individuals(EntailmentRegimes.ontology, (any ServiceDescription.EntailmentRegime).self)
        // sd:EntailmentRegime is a subclass of sd:Feature, so each regime is
        // a feature by its type: this upcast compiles only if that holds.
        let features: [any ServiceDescription.Feature] = regimes.map { $0 }
        #expect(features.count == regimes.count)
        #expect(service(regimes: regimes).supportsEntailment(EntailmentRegimes.RIF))
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
        #expect(!(Formats.Turtle is any ServiceDescription.EntailmentRegime))
        #expect(!(ServiceDescription.SPARQLQuery is any ServiceDescription.EntailmentRegime))
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
