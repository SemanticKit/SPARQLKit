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
        #expect(!description.supports(SPARQLGraphAccept.ntriples))
        #expect(SPARQLServiceDescription().supports(SPARQLAccept.tsv))
    }

    @Test("Vocabulary IRIs decode back to their individuals", .tags(.vocabulary))
    func vocabularyIRIsDecode() throws {
        let description = try SPARQLServiceDescriptionDecoder().decode("""
            @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
            @prefix formats: <http://www.w3.org/ns/formats/> .
            @prefix entailment: <http://www.w3.org/ns/entailment/> .
            <https://example.org/sparql> a sd:Service ;
              sd:supportedLanguage sd:SPARQL11Update ;
              sd:feature sd:SPARQL12Query ;
              sd:resultFormat formats:N-Triples ;
              sd:entailmentRegime entailment:OWL-Direct , entailment:Unknown .
            """)
        #expect(description.supportedLanguages.count == 1)
        #expect(description.supportedLanguages.first === ServiceDescription.SPARQL11Update)
        #expect(description.features.count == 1)
        #expect(description.features.first === ServiceDescription.SPARQL12Query)
        #expect(description.resultFormats.count == 1)
        #expect(description.resultFormats.first === Formats.N_Triples)
        #expect(description.entailmentRegimes.count == 1)
        #expect(description.entailmentRegimes.first === Entailment.OWL_Direct)
    }

    @Test("Every format of the W3C formats vocabulary decodes into its declared individual", .tags(.vocabulary))
    func decodesEveryDeclaredFormat() throws {
        // Every individual of http://www.w3.org/ns/formats/, as the W3C
        // Unique URIs for File Formats vocabulary defines them.
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
        let decoded = try SPARQLServiceDescriptionDecoder().decode(turtle).resultFormats
        let decodedNames = decoded.map { type(of: $0 as any RDFCore.Entity).metadata.name }
        // The individuals the Formats ontology declares: the decoder must
        // know each of them, so the vocabulary and the decoder cannot drift.
        let declaredNames = Formats().entities.compactMap { ($0 as? RDFCore.Individual)?.localName }

        #expect(decoded.count == 23)
        #expect(Set(decodedNames) == Set(declaredNames))
        #expect(decodedNames.count == declaredNames.count)
        #expect(decoded.contains { $0 === Formats.RDFa })
    }

    @Test("Every entailment regime the Entailment vocabulary declares decodes into its individual", .tags(.vocabulary))
    func decodesEveryDeclaredRegime() throws {
        // The individuals the Entailment ontology declares: the decoder must
        // know each of them, so the vocabulary and the decoder cannot drift.
        let declaredNames = Entailment().entities.compactMap { ($0 as? RDFCore.Individual)?.localName }
        let turtle = """
            @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
            @prefix ent: <http://www.w3.org/ns/entailment/> .
            <https://example.org/sparql> a sd:Service ;
              sd:entailmentRegime \(declaredNames.map { "ent:" + $0 }.joined(separator: " , ")) .
            """
        let decoded = try SPARQLServiceDescriptionDecoder().decode(turtle).entailmentRegimes

        #expect(declaredNames.count == 7)
        #expect(decoded.map { type(of: $0 as any RDFCore.Entity).metadata.name } == declaredNames)
    }

    @Test("Every language and feature the service description vocabulary declares decodes into its individual", .tags(.vocabulary))
    func decodesEveryDeclaredFeature() throws {
        // Every individual sd declares is a feature (sd:Language is a
        // subclass of sd:Feature), and its languages are those whose names
        // the decoder reads as sd:supportedLanguage.
        let declaredNames = ServiceDescription().entities.compactMap { ($0 as? RDFCore.Individual)?.localName }
        let list = declaredNames.map { "sd:" + $0 }.joined(separator: " , ")
        let turtle = """
            @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
            <https://example.org/sparql> a sd:Service ;
              sd:feature \(list) ;
              sd:supportedLanguage \(list) .
            """
        let description = try SPARQLServiceDescriptionDecoder().decode(turtle)
        let featureNames = description.features.map { type(of: $0 as any RDFCore.Entity).metadata.name }
        let languageNames = description.supportedLanguages.map { type(of: $0 as any RDFCore.Entity).metadata.name }

        #expect(declaredNames.count == 10)
        #expect(Set(featureNames) == Set(declaredNames))
        #expect(featureNames.count == declaredNames.count)
        #expect(Set(languageNames) == ["SPARQL10Query", "SPARQL11Query", "SPARQL11Update", "SPARQL12Query", "SPARQL12Update"])
    }

    @Test("An IRI names the declared individual whose type carries it", .tags(.vocabulary))
    func iriNamesDeclaredIndividual() {
        let regimes: [any ServiceDescription.EntailmentRegime] = [Entailment.RDFS, Entailment.OWL_Direct]
        #expect(regimes.individual(named: "http://www.w3.org/ns/entailment/OWL-Direct") === Entailment.OWL_Direct)
        #expect(regimes.individual(named: "http://www.w3.org/ns/entailment/Unknown") == nil)
    }

    @Test("Every entailment regime is an individual of sd:EntailmentRegime", .tags(.vocabulary))
    func regimesAreEntailmentRegimes() {
        let regimes: [any ServiceDescription.EntailmentRegime] = [
            Entailment.Simple, Entailment.RDF, Entailment.RDFS, Entailment.D,
            Entailment.OWL_Direct, Entailment.OWL_RDF_Based, Entailment.RIF
        ]
        // sd:EntailmentRegime is a subclass of sd:Feature, so each regime is
        // a feature by its type: this upcast compiles only if that holds.
        let features: [any ServiceDescription.Feature] = regimes.map { $0 }
        #expect(features.count == regimes.count)
        #expect(SPARQLServiceDescription(entailmentRegimes: regimes).supportsEntailment(Entailment.RIF))
    }

    @Test("An individual that is not an entailment regime does not decode as one", .tags(.vocabulary))
    func nonRegimesDoNotDecodeAsRegimes() throws {
        let turtle = """
            @prefix sd: <http://www.w3.org/ns/sparql-service-description#> .
            @prefix formats: <http://www.w3.org/ns/formats/> .
            <https://example.org/sparql> a sd:Service ;
              sd:defaultEntailmentRegime formats:Turtle , sd:SPARQL12Query .
            """
        #expect(try SPARQLServiceDescriptionDecoder().decode(turtle).entailmentRegimes.isEmpty)
        let regimes: [any ServiceDescription.EntailmentRegime] = [
            Entailment.Simple, Entailment.RDF, Entailment.RDFS, Entailment.D,
            Entailment.OWL_Direct, Entailment.OWL_RDF_Based, Entailment.RIF
        ]
        #expect(regimes.individual(named: type(of: Formats.Turtle).metadata.id) == nil)
        #expect(!(Formats.Turtle is any ServiceDescription.EntailmentRegime))
        #expect(!(ServiceDescription.SPARQL12Query is any ServiceDescription.EntailmentRegime))
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
    func refusesUnsupportedGraphFormat() async throws {
        let construct = try SPARQLConstructQuery(
            [SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o"))],
            where: [.triple(SPARQLTriplePattern(.variable("s"), .variable("p"), .variable("o")))]
        )
        let description = SPARQLServiceDescription(resultFormats: [Formats.Turtle])
        await #expect(throws: SPARQLError.invalidRequest("Endpoint service description does not support requested graph format.")) {
            _ = try await client(MockSession()).executeGraphQuery(construct, accept: .ntriples, serviceDescription: description)
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
