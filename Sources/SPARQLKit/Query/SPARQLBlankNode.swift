/// A blank node in a query pattern or an update template
/// (SPARQL 1.2 Query Language §4.1.4).
///
/// In a pattern a blank node acts as a variable that is not projected; in a
/// `CONSTRUCT` or `INSERT` template it stands for a fresh blank node per
/// solution. Its label must match the grammar's `BLANK_NODE_LABEL` (§19.8),
/// so it always renders as one token.
public struct SPARQLBlankNode: Hashable, Sendable {
    /// The label, without `_:`.
    public let label: String

    /// Creates a blank node from its label, dropping a leading `_:`.
    ///
    /// - Throws: ``SPARQLError/invalidRequest(_:)`` when the label is not a
    ///   `BLANK_NODE_LABEL`.
    public init(_ label: String) throws {
        let label = label.hasPrefix("_:") ? Substring(label.dropFirst(2)) : Substring(label)
        guard Self.isLabel(label) else {
            throw SPARQLError.invalidRequest("'\(label)' is not a SPARQL blank node label (BLANK_NODE_LABEL).")
        }
        self.label = String(label)
    }

    /// This blank node in SPARQL text, `_:label`.
    func render() -> String {
        "_:" + label
    }

    /// `BLANK_NODE_LABEL ::= '_:' ( PN_CHARS_U | [0-9] ) ((PN_CHARS|'.')* PN_CHARS)?`
    static func isLabel(_ label: Substring) -> Bool {
        let scalars = label.unicodeScalars
        guard let first = scalars.first, first.isSPARQLNameStart || first.isSPARQLDigit else { return false }
        guard let last = scalars.last, scalars.count == 1 || last.isSPARQLNameCharacter else { return false }
        return scalars.dropFirst().allSatisfy { $0.isSPARQLNameCharacter || $0 == "." }
    }
}
