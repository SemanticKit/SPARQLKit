/// Collects the lines of a rendered query or update, indented by nesting.
struct SPARQLLines {
    private(set) var lines: [String] = []
    private var depth = 0

    mutating func append(_ line: String) {
        lines.append(String(repeating: "  ", count: depth) + line)
    }

    mutating func block(_ opening: String, _ body: (inout SPARQLLines) -> Void) {
        append(opening.isEmpty ? "{" : opening + " {")
        depth += 1
        body(&self)
        depth -= 1
        append("}")
    }

    var text: String {
        lines.joined(separator: "\n")
    }
}
