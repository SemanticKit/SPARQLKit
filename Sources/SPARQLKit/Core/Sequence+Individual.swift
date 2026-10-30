import IRIKit
import RDFCore

extension Sequence {
    /// The declared individual in this sequence that an IRI names: the one
    /// whose generated type's metadata carries that IRI. This is where a
    /// decoded IRI becomes the generated term it names.
    func individual(named iri: IRI) -> Element? {
        first { candidate in
            (candidate as? any RDFCore.Entity).map { type(of: $0).metadata.id == iri } ?? false
        }
    }
}
