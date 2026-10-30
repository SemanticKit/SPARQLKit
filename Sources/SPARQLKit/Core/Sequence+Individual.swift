import IRIKit
import RDFCore
import RDFFormats

extension Sequence {
    /// The individual in this sequence that an IRI denotes.
    ///
    /// In RDF the IRI is the identity; in Swift the individual is. A decoder
    /// holding an IRI a document carries finds here the translated individual
    /// that IRI denotes, so what leaves the decoder is the individual itself
    /// and code compares it with `===`. IRIs are the same IRI when they are
    /// the same string (RDF 1.2 Concepts §3.2).
    ///
    ///     let format = Formats.ontology.compactMap { $0 as? any Formats.Format }.individual(denotedBy: iri)
    func individual(denotedBy iri: IRI) -> Element? {
        first { ($0 as? any RDFCore.Resource).flatMap(IRI.init(of:)) == iri }
    }

    /// The member of this sequence whose Swift class is the RDF class an IRI
    /// denotes: how a decoder turns an `rdf:type` IRI into the generated
    /// class it names.
    func member(ofClassDenotedBy iri: IRI) -> Element? {
        first { candidate in
            (candidate as? any RDFCore.ResourceClass).map { IRI(of: type(of: $0)) == iri } ?? false
        }
    }
}
