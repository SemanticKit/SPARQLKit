import EntailmentRegimes
import Foundation
import ServiceDescription

/// A decoded service description document (SPARQL 1.2 Service Description
/// §3): the translated `sd:Service` it describes, and what the document says
/// about it that is not a translated `sd:` individual.
public struct SPARQLServiceDescription: Sendable {
    /// The service, whose languages, features and formats are the translated
    /// individuals of the vocabularies, compared with `===`.
    public let service: any ServiceDescription.Service

    /// The URLs of the service's endpoints (`sd:endpoint`), where a client
    /// sends its requests: the IRIs the HTTP layer dereferences.
    public let endpointURLs: [URL]

    /// The entailment regimes the service uses for basic graph pattern
    /// matching: its `sd:defaultEntailmentRegime`, and the
    /// `sd:entailmentRegime` of each named graph of its default dataset and
    /// of the graphs it makes available, as the translated `ent:Entailment`
    /// individuals the published entailment documents describe.
    public let entailmentRegimes: [any EntailmentRegimes.Entailment]

    public init(
        service: any ServiceDescription.Service,
        endpointURLs: [URL] = [],
        entailmentRegimes: [any EntailmentRegimes.Entailment] = []
    ) {
        self.service = service
        self.endpointURLs = endpointURLs
        self.entailmentRegimes = entailmentRegimes
    }

    /// Whether the service uses this entailment regime. A description that
    /// names no regime restricts none.
    public func supportsEntailment(_ regime: any EntailmentRegimes.Entailment) -> Bool {
        entailmentRegimes.isEmpty || entailmentRegimes.contains { $0 === regime }
    }
}
