import Foundation
import Formats
import RDFCore
import ServiceDescription

/// What a SPARQL service says it implements (SPARQL 1.2 Service
/// Description §3), read from the translated `sd:Service` a
/// ``SPARQLServiceDescriptionDecoder`` decodes.
///
/// The languages, features, formats and entailment regimes are the
/// translated individuals of the vocabularies, compared with `===`.
extension ServiceDescription.Service {
    /// The URLs of the service's endpoints (`sd:endpoint`), where a client
    /// sends its requests: the IRIs the HTTP layer dereferences.
    public var endpointURLs: [URL] {
        endpoint.compactMap { value in
            guard case .individual(let endpoint) = value, let iri = endpoint.iri else { return nil }
            return URL(string: iri.rawValue)
        }
    }

    /// Whether the service returns query results in this media type. A
    /// description that names no result format restricts none.
    public func supports(_ accept: SPARQLAccept) -> Bool {
        resultFormat.isEmpty || resultFormat.contains { $0 === accept.format }
    }

    /// Whether the service returns graphs in this media type. A description
    /// that names no result format restricts none.
    public func supports(_ accept: SPARQLGraphAccept) -> Bool {
        resultFormat.isEmpty || resultFormat.contains { $0 === accept.format }
    }

    /// The entailment regimes the service uses for basic graph pattern
    /// matching: its `sd:defaultEntailmentRegime`, and the
    /// `sd:entailmentRegime` of each named graph of its default dataset and
    /// of the graphs it makes available.
    public var entailmentRegimes: [any ServiceDescription.EntailmentRegime] {
        let collections: [any ServiceDescription.GraphCollection] = defaultDataset + availableGraphs
        return defaultEntailmentRegime + collections.flatMap(\.namedGraph).flatMap(\.entailmentRegime)
    }

    /// Whether the service uses this entailment regime. A description that
    /// names no regime restricts none.
    public func supportsEntailment(_ regime: any ServiceDescription.EntailmentRegime) -> Bool {
        let regimes = entailmentRegimes
        return regimes.isEmpty || regimes.contains { $0 === regime }
    }

    /// Whether the service implements this language (`sd:supportedLanguage`).
    public func supportsLanguage(_ language: any ServiceDescription.Language) -> Bool {
        supportedLanguage.contains { $0 === language }
    }

    /// The service's features: the values of `sd:feature` and of the
    /// properties sparql-service-description.ttl declares
    /// `rdfs:subPropertyOf sd:feature`, which entail `sd:feature` (RDF 1.2
    /// Semantics, rdfs7).
    public var features: [any ServiceDescription.Feature] {
        feature
            + supportedLanguage.map { $0 as any ServiceDescription.Feature }
            + defaultEntailmentRegime.map { $0 as any ServiceDescription.Feature }
            + defaultSupportedEntailmentProfile.map { $0 as any ServiceDescription.Feature }
            + extensionFunction.map { $0 as any ServiceDescription.Feature }
            + extensionAggregate.map { $0 as any ServiceDescription.Feature }
            + languageExtension
            + propertyFeature
    }

    /// Whether the service has this feature.
    public func hasFeature(_ feature: any ServiceDescription.Feature) -> Bool {
        features.contains { $0 === feature }
    }
}
