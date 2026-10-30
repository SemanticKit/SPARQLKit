/// A triple pattern (SPARQL 1.2 Query Language §4.1.5): a triple whose
/// positions may be variables, and whose predicate may be a property path.
public struct SPARQLTriplePattern: Hashable, Sendable {
    public let subject: SPARQLPatternTerm
    public let verb: SPARQLVerb
    public let object: SPARQLPatternTerm

    public init(_ subject: SPARQLPatternTerm, _ verb: SPARQLVerb, _ object: SPARQLPatternTerm) {
        self.subject = subject
        self.verb = verb
        self.object = object
    }

    /// The variables the pattern mentions.
    public var variables: Set<Variable> {
        subject.variables.union(verb.variables).union(object.variables)
    }

    func render() -> String {
        subject.render() + " " + verb.render() + " " + object.render() + " ."
    }
}
