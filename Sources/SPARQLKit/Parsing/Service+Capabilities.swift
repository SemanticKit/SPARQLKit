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
