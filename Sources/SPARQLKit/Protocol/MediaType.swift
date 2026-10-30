import Foundation

/// A media type as a `Content-Type` header writes it: `type/subtype`
/// followed by `;`-separated `name=value` parameters (RFC 9110 §8.3.1).
struct MediaType: Hashable, Sendable {
    /// The `type/subtype`, lowercased: media type names are case-insensitive.
    let essence: String
    /// The parameters in the order the header writes them, each name
    /// lowercased (parameter names are case-insensitive) and each quoted
    /// value without its quotes.
    let parameters: [Parameter]

    struct Parameter: Hashable, Sendable {
        let name: String
        let value: String
    }

    init(_ header: String) {
        var parts = header.split(separator: ";", omittingEmptySubsequences: false).makeIterator()
        essence = (parts.next().map(String.init) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var parameters: [Parameter] = []
        while let part = parts.next() {
            let pair = part.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { continue }
            var value = String(pair[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value.removeFirst()
                value.removeLast()
            }
            parameters.append(Parameter(name: String(pair[0]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), value: value))
        }
        self.parameters = parameters
    }

    /// The first non-empty value of the named parameter.
    subscript(parameter name: String) -> String? {
        let name = name.lowercased()
        return parameters.first { $0.name == name && !$0.value.isEmpty }?.value
    }
}
