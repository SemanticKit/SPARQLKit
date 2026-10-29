import Foundation
import RDFCore

/// What a SPARQL endpoint says it implements, read from its service
/// description (SPARQL 1.2 Service Description §3).
///
/// Languages, features, formats and entailment regimes are the generated
/// individuals of ``ServiceDescription``, ``Formats`` and ``Entailment``; the
/// endpoints are the URLs a client sends requests to.
public struct SPARQLServiceDescription: Sendable {
    /// `sd:endpoint`
    public let endpoints: [URL]
    /// `sd:supportedLanguage`
    public let supportedLanguages: [any ServiceDescription.Language]
    /// `sd:feature`
    public let features: [any ServiceDescription.Feature]
    /// `sd:resultFormat`
    public let resultFormats: [any Formats.Format]
    /// `sd:defaultEntailmentRegime` and the `sd:entailmentRegime` of the
    /// described graphs.
    public let entailmentRegimes: [any RDFCore.Resource]

    public init(
        endpoints: [URL] = [],
        supportedLanguages: [any ServiceDescription.Language] = [],
        features: [any ServiceDescription.Feature] = [],
        resultFormats: [any Formats.Format] = [],
        entailmentRegimes: [any RDFCore.Resource] = []
    ) {
        self.endpoints = endpoints
        self.supportedLanguages = supportedLanguages
        self.features = features
        self.resultFormats = resultFormats
        self.entailmentRegimes = entailmentRegimes
    }

    /// Whether the endpoint returns query results in this media type. A
    /// description that names no result format restricts none.
    public func supports(_ accept: SPARQLAccept) -> Bool {
        resultFormats.isEmpty || resultFormats.contains { $0 === accept.format }
    }

    /// Whether the endpoint returns graphs in this media type. A description
    /// that names no result format restricts none.
    public func supports(_ accept: SPARQLGraphAccept) -> Bool {
        resultFormats.isEmpty || resultFormats.contains { $0 === accept.format }
    }

    /// Whether the endpoint uses this entailment regime. A description that
    /// names no regime restricts none.
    public func supportsEntailment(_ regime: any RDFCore.Resource) -> Bool {
        entailmentRegimes.isEmpty || entailmentRegimes.contains { $0 === regime }
    }

    /// Whether the endpoint implements this language.
    public func supportsLanguage(_ language: any ServiceDescription.Language) -> Bool {
        supportedLanguages.contains { $0 === language }
    }

    /// Whether the endpoint has this feature.
    public func hasFeature(_ feature: any ServiceDescription.Feature) -> Bool {
        features.contains { $0 === feature }
    }
}
