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
        let languages: [any ServiceDescription.Language] = [
            ServiceDescription.SPARQL10Query, ServiceDescription.SPARQL11Query, ServiceDescription.SPARQL11Update,
            ServiceDescription.SPARQL12Query, ServiceDescription.SPARQL12Update
        ]
        let features: [any ServiceDescription.Feature] = [
            ServiceDescription.DereferencesURIs, ServiceDescription.UnionDefaultGraph,
            ServiceDescription.RequiresDataset, ServiceDescription.EmptyGraphs,
            ServiceDescription.BasicFederatedQuery
        ] + languages.map { $0 as any ServiceDescription.Feature }
        let formats: [any Formats.Format] = [
            Formats.JSON_LD, Formats.N3, Formats.N_Triples, Formats.N_Quads, Formats.LD_Patch, Formats.microdata,
            Formats.OWL_XML, Formats.OWL_Functional, Formats.OWL_Manchester, Formats.POWDER, Formats.POWDER_S,
            Formats.PROV_N, Formats.PROV_XML, Formats.RDF_JSON, Formats.RDF_XML, Formats.RIF_XML,
            Formats.SPARQL_Results_XML, Formats.SPARQL_Results_JSON, Formats.SPARQL_Results_CSV,
            Formats.SPARQL_Results_TSV, Formats.Turtle, Formats.TriG
        ]
        let regimes: [any ServiceDescription.EntailmentRegime] = [
            Entailment.Simple, Entailment.RDF, Entailment.RDFS, Entailment.D,
            Entailment.OWL_Direct, Entailment.OWL_RDF_Based, Entailment.RIF
        ]
        return SPARQLServiceDescription(
            endpoints: objects(ServiceDescription.endpoint.metadata.id).compactMap { URL(string: $0.rawValue) },
            supportedLanguages: objects(ServiceDescription.supportedLanguage.metadata.id).compactMap(languages.individual(named:)),
            features: objects(ServiceDescription.feature.metadata.id).compactMap(features.individual(named:)),
            resultFormats: objects(ServiceDescription.resultFormat.metadata.id).compactMap(formats.individual(named:)),
            entailmentRegimes: (objects(ServiceDescription.defaultEntailmentRegime.metadata.id)
                + objects(ServiceDescription.entailmentRegime.metadata.id)).compactMap(regimes.individual(named:))
        )
    }
}
