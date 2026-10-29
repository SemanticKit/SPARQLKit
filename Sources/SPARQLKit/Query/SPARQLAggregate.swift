/// A set function of an aggregate query (SPARQL 1.2 Query Language §18.5.1).
public enum SPARQLAggregate: Hashable, Sendable {
    case count
    case sum
    case min
    case max
    case avg
    case sample
    /// `GROUP_CONCAT`, with the separator it joins values with.
    case groupConcat(separator: String?)

    var keyword: String {
        switch self {
        case .count: "COUNT"
        case .sum: "SUM"
        case .min: "MIN"
        case .max: "MAX"
        case .avg: "AVG"
        case .sample: "SAMPLE"
        case .groupConcat: "GROUP_CONCAT"
        }
    }
}
