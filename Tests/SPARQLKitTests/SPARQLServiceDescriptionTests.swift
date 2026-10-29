import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import RDFCore
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

    @Test("A Turtle description decodes into the generated individuals it names")
    func decodesIntoGeneratedIndividuals() throws {
        let turtle = try #require(String(data: try fixture("service_description.ttl"), encoding: .utf8))
        let description = try SPARQLServiceDescriptionDecoder().decode(turtle)

        #expect(description.endpoints == [URL(string: "https://example.org/sparql")!])
        #expect(description.supportsLanguage(ServiceDescription.SPARQL12Query))
        #expect(!description.supportsLanguage(ServiceDescription.SPARQL10Query))
        #expect(description.hasFeature(ServiceDescription.UnionDefaultGraph))
        #expect(description.supports(SPARQLAccept.jsonResults))
        #expect(!description.supports(SPARQLAccept.xmlResults))
        #expect(description.supports(SPARQLGraphAccept.turtle))
        #expect(description.supportsEntailment(Entailment.RDFS))
        #expect(!description.supportsEntailment(Entailment.Simple))
    }

    @Test("A term the vocabularies do not declare names nothing and is left out")
    func undeclaredTermsAreLeftOut() throws {
        let description = try SPARQLServiceDescriptionDecoder().decode("""
            @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
            <https://example.org/sparql> sd:feature <https://example.org/vendor#FullText> , sd:EmptyGraphs .
            """)
        #expect(description.features.count == 1)
        #expect(description.hasFeature(ServiceDescription.EmptyGraphs))
    }

    @Test("Each media type maps to the format individual a description names")
    func mediaTypesMapToFormats() {
        #expect(SPARQLAccept.csv.format === Formats.SPARQL_Results_CSV)
        #expect(SPARQLGraphAccept.ntriples.format === Formats.N_Triples)
        let description = SPARQLServiceDescription(resultFormats: [Formats.SPARQL_Results_JSON, Formats.Turtle])
        #expect(description.supports(SPARQLAccept.jsonResults))
        #expect(!description.supports(SPARQLGraphAccept.rdfXML))
        #expect(SPARQLServiceDescription().supports(SPARQLAccept.tsv))
    }

    @Test("Vocabulary IRIs decode back to their individuals", .tags(.vocabulary))
    func vocabularyIRIsDecode() {
        #expect(ServiceDescription.decodeLanguage("http://www.w3.org/ns/sparql-service-description#SPARQL11Update") === ServiceDescription.SPARQL11Update)
        #expect(ServiceDescription.decodeFeature("http://www.w3.org/ns/sparql-service-description#SPARQL12Query") === ServiceDescription.SPARQL12Query)
        #expect(Formats.decodeFormat("http://www.w3.org/ns/formats/N-Triples") === Formats.N_Triples)
        #expect(Entailment.decodeRegime("http://www.w3.org/ns/entailment/OWL-Direct") === Entailment.OWL_Direct)
        #expect(Entailment.decodeRegime("http://www.w3.org/ns/entailment/Unknown") == nil)
    }

    @Test("The client refuses a result format the endpoint does not offer", .tags(.protocol))
    func refusesUnsupportedResultFormat() async {
        let session = MockSession()
        let description = SPARQLServiceDescription(resultFormats: [Formats.SPARQL_Results_JSON])
        await #expect(throws: SPARQLError.invalidRequest("Endpoint service description does not support requested result format.")) {
            _ = try await client(session).executeQuery(select, accept: .xmlResults, serviceDescription: description)
        }
        #expect(session.requests.isEmpty)
    }

    @Test("The client refuses a graph format the endpoint does not offer", .tags(.protocol))
    func refusesUnsupportedGraphFormat() async {
        let construct = SPARQLConstructQuery(
            [SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o"))],
            where: [.triple(SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o")))]
        )
        let description = SPARQLServiceDescription(resultFormats: [Formats.Turtle])
        await #expect(throws: SPARQLError.invalidRequest("Endpoint service description does not support requested graph format.")) {
            _ = try await client(MockSession()).executeGraphQuery(construct, accept: .rdfXML, serviceDescription: description)
        }
    }

    @Test("The client gates the entailment regime on the description", .tags(.protocol))
    func gatesEntailment() async throws {
        let description = SPARQLServiceDescription(entailmentRegimes: [Entailment.RDFS])
        let ask = SPARQLAskQuery(where: [.triple(SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o")))])

        await #expect(throws: SPARQLError.invalidRequest("Endpoint service description does not support requested entailment regime.")) {
            _ = try await client(MockSession()).executeQuery(
                ask,
                options: SPARQLQueryRequestOptions(requiredEntailmentRegime: Entailment.OWL_Direct),
                serviceDescription: description
            )
        }

        let allowed = try await client(MockSession(body: #"{"boolean":true}"#)).executeQuery(
            ask,
            options: SPARQLQueryRequestOptions(requiredEntailmentRegime: Entailment.RDFS),
            serviceDescription: description
        )
        #expect(String(data: allowed, encoding: .utf8) == #"{"boolean":true}"#)

        let ungated = try await client(MockSession(body: #"{"boolean":true}"#)).executeAsk(
            ask,
            options: SPARQLQueryRequestOptions(requiredEntailmentRegime: Entailment.OWL_Direct)
        )
        #expect(ungated)
    }
}
