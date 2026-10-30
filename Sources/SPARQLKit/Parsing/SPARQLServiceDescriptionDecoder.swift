import Foundation
import IRIKit
import RDFCore
import RDFFormats

/// Decodes a Turtle service description into a ``SPARQLServiceDescription``.
///
/// The document is read by RDFFormats' ``TurtleDecoder``. Each IRI that names a
/// language, feature, format or entailment regime becomes the generated
/// individual it names as it is read; an IRI this vocabulary does not declare
/// names nothing SPARQLKit can act on, so it is left out.
public struct SPARQLServiceDescriptionDecoder: Sendable {
    public init() {}

    public func decode(_ turtle: String, base: IRI? = nil) throws -> SPARQLServiceDescription {
        let triples = try TurtleDecoder(base: base).decode(turtle)
        func objects(_ predicate: IRI) -> [IRI] {
            triples.compactMap { triple in
                guard triple.predicate == predicate, case .iri(let iri) = triple.object else { return nil }
                return iri
            }
        }
        return SPARQLServiceDescription(
            endpoints: objects(ServiceDescription.endpoint.metadata.id).compactMap { URL(string: $0.rawValue) },
            supportedLanguages: objects(ServiceDescription.supportedLanguage.metadata.id).compactMap(ServiceDescription.decodeLanguage),
            features: objects(ServiceDescription.feature.metadata.id).compactMap(ServiceDescription.decodeFeature),
            resultFormats: objects(ServiceDescription.resultFormat.metadata.id).compactMap(Formats.decodeFormat),
            entailmentRegimes: (objects(ServiceDescription.defaultEntailmentRegime.metadata.id)
                + objects(ServiceDescription.entailmentRegime.metadata.id)).compactMap(Entailment.decodeRegime)
        )
    }
}

extension ServiceDescription {
    /// The language an IRI names, decoded at the boundary.
    public static func decodeLanguage(_ iri: IRI) -> (any ServiceDescription.Language)? {
        SPARQLResultTermDecoder().individual(
            named: iri,
            among: [SPARQL10Query, SPARQL11Query, SPARQL11Update, SPARQL12Query, SPARQL12Update]
        )
    }

    /// The feature an IRI names, decoded at the boundary.
    public static func decodeFeature(_ iri: IRI) -> (any ServiceDescription.Feature)? {
        let features: [any ServiceDescription.Feature] = [
            DereferencesURIs, UnionDefaultGraph, RequiresDataset, EmptyGraphs, BasicFederatedQuery
        ]
        return SPARQLResultTermDecoder().individual(named: iri, among: features)
            ?? decodeLanguage(iri).map { $0 as any ServiceDescription.Feature }
    }
}

extension Formats {
    /// The format an IRI names, decoded at the boundary.
    public static func decodeFormat(_ iri: IRI) -> (any Formats.Format)? {
        SPARQLResultTermDecoder().individual(named: iri, among: [
            JSON_LD, N3, N_Triples, N_Quads, LD_Patch, microdata, OWL_XML, OWL_Functional,
            OWL_Manchester, POWDER, POWDER_S, PROV_N, PROV_XML, RDF_JSON, RDF_XML, RIF_XML,
            SPARQL_Results_XML, SPARQL_Results_JSON, SPARQL_Results_CSV, SPARQL_Results_TSV,
            Turtle, TriG
        ])
    }
}

extension Entailment {
    /// The entailment regime an IRI names, decoded at the boundary.
    public static func decodeRegime(_ iri: IRI) -> (any RDFCore.Resource)? {
        SPARQLResultTermDecoder().individual(named: iri, among: [Simple, RDF, RDFS, D, OWL_Direct, OWL_RDF_Based, RIF])
    }
}
