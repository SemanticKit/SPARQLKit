import Foundation
import RDFCore

public struct SPARQLDelimitedResultsDecoder: Sendable {
    public init() {}

    public func decodeCSV(_ data: Data, normalizeTerms: Bool = false) throws -> SPARQLResultSet {
        guard let content = String(data: data, encoding: .utf8) else {
            throw SPARQLError.decodingFailure("CSV content is not UTF-8.")
        }
        let rows = try parseCSV(content)
        return try decodeRows(rows, normalizeCSVTerms: normalizeTerms)
    }

    public func decodeTSV(_ data: Data) throws -> SPARQLResultSet {
        guard let content = String(data: data, encoding: .utf8) else {
            throw SPARQLError.decodingFailure("TSV content is not UTF-8.")
        }

        let lines = content
            .split(whereSeparator: \ .isNewline)
            .map(String.init)

        let rows = lines.map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
        return try decodeRows(rows, tsvMode: true)
    }

    private func decodeRows(
        _ rows: [[String]],
        tsvMode: Bool = false,
        normalizeCSVTerms: Bool = false
    ) throws -> SPARQLResultSet {
        guard let header = rows.first, !header.isEmpty else {
            throw SPARQLError.decodingFailure("Missing header row.")
        }

        let variables = header.map { Variable(rawValue: $0) }
        var bindings: [Binding] = []

        for row in rows.dropFirst() where !row.allSatisfy(\.isEmpty) {
            var binding: Binding = [:]
            for (index, variable) in variables.enumerated() {
                guard index < row.count else {
                    continue
                }
                let value = row[index]
                guard !value.isEmpty else {
                    continue
                }

                if tsvMode {
                    binding[variable] = try decodeTerm(value, tsvMode: true)
                } else if normalizeCSVTerms {
                    binding[variable] = try decodeTerm(value, tsvMode: false)
                } else {
                    binding[variable] = try ObjectTerm(literal: value)
                }
            }
            bindings.append(binding)
        }

        return SPARQLResultSet(variables: variables, bindings: bindings)
    }

    private func decodeTerm(_ token: String, tsvMode: Bool) throws -> ObjectTerm {
        if token == "UNDEF" {
            return try ObjectTerm(literal: token)
        }

        if token.hasPrefix("<<("), token.hasSuffix(")>>") {
            return try decodeTripleTerm(token, tsvMode: tsvMode)
        }

        if token.hasPrefix("<"), token.hasSuffix(">") {
            return try ObjectTerm(iri: String(token.dropFirst().dropLast()))
        }
        if token.hasPrefix("_:") {
            return try ObjectTerm(blankNodeLabel: String(token.dropFirst(2)))
        }
        if token.hasPrefix("\"") {
            if let languageRange = token.range(of: "\"@", options: .backwards),
               token.starts(with: "\""),
               languageRange.lowerBound > token.startIndex
            {
                let lexical = String(token[token.index(after: token.startIndex) ..< languageRange.lowerBound])
                let languageToken = String(token[languageRange.upperBound...])
                let (language, direction) = try splitLanguageAndDirection(languageToken)
                return try ObjectTerm(
                    literal: tsvMode ? unescapeTSVLiteral(lexical) : lexical,
                    language: language,
                    direction: direction
                )
            }

            if let datatypeRange = token.range(of: "\"^^<", options: .backwards),
               token.hasSuffix(">"),
               datatypeRange.lowerBound > token.startIndex
            {
                let lexical = String(token[token.index(after: token.startIndex) ..< datatypeRange.lowerBound])
                let datatypeStart = datatypeRange.upperBound
                let datatypeEnd = token.index(before: token.endIndex)
                let datatype = String(token[datatypeStart ..< datatypeEnd])
                let normalizedLexical = tsvMode ? unescapeTSVLiteral(lexical) : lexical
                return try ObjectTerm(literal: normalizedLexical, datatype: datatype)
            }

            if token.hasSuffix("\""), token.count >= 2 {
                let lexical = String(token.dropFirst().dropLast())
                let normalizedLexical = tsvMode ? unescapeTSVLiteral(lexical) : lexical
                return try ObjectTerm(literal: normalizedLexical)
            }
        }
        return try ObjectTerm(literal: token)
    }

    private func decodeTripleTerm(_ token: String, tsvMode: Bool) throws -> ObjectTerm {
        let core = String(token.dropFirst(3).dropLast(3)).trimmingCharacters(in: .whitespaces)
        let components = try splitTripleComponents(core)
        guard components.count == 3 else {
            throw SPARQLError.decodingFailure("Invalid TSV triple term payload: expected 3 components.")
        }

        return try ObjectTerm(
            subject: decodeTerm(components[0], tsvMode: tsvMode),
            predicate: decodeTerm(components[1], tsvMode: tsvMode),
            object: decodeTerm(components[2], tsvMode: tsvMode)
        )
    }

    private func splitTripleComponents(_ raw: String) throws -> [String] {
        var components: [String] = []
        var current = ""
        var index = raw.startIndex

        var quoted = false
        var escaped = false
        var nestedTripleDepth = 0

        while index < raw.endIndex {
            if raw[index...].hasPrefix("<<(") {
                nestedTripleDepth += 1
                current.append(contentsOf: "<<(")
                index = raw.index(index, offsetBy: 3)
                continue
            }

            if raw[index...].hasPrefix(")>>"), nestedTripleDepth > 0 {
                nestedTripleDepth -= 1
                current.append(contentsOf: ")>>")
                index = raw.index(index, offsetBy: 3)
                continue
            }

            let char = raw[index]

            if quoted {
                current.append(char)
                if escaped {
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    quoted = false
                }
                index = raw.index(after: index)
                continue
            }

            if char == "\"" {
                quoted = true
                current.append(char)
                index = raw.index(after: index)
                continue
            }

            if nestedTripleDepth == 0 && char.isWhitespace {
                if !current.isEmpty {
                    components.append(current)
                    current = ""
                }
                while index < raw.endIndex, raw[index].isWhitespace {
                    index = raw.index(after: index)
                }
                continue
            }

            current.append(char)
            index = raw.index(after: index)
        }

        if !current.isEmpty {
            components.append(current)
        }

        if quoted || nestedTripleDepth != 0 {
            throw SPARQLError.decodingFailure("Invalid TSV triple term payload.")
        }

        return components
    }

    private func unescapeTSVLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\r")
    }

    /// Splits `LANGTAG` with an optional `--` base direction, as RDF 1.2
    /// N-Triples writes it after the `@`. A language tag has single `-`
    /// between subtags, so the direction follows the last `--`:
    /// `en-US--ltr` is `en-US` and `ltr`.
    private func splitLanguageAndDirection(_ token: String) throws -> (String, BaseDirection?) {
        guard let separator = token.range(of: "--", options: .backwards) else {
            return (token, nil)
        }
        let direction = try BaseDirection(resultsText: String(token[separator.upperBound...]))
        return (String(token[..<separator.lowerBound]), direction)
    }

    private func parseCSV(_ content: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var cell = ""
        var inQuotes = false
        var iterator = content.makeIterator()

        while let char = iterator.next() {
            switch char {
            case "\"":
                if inQuotes {
                    if let next = iterator.next() {
                        if next == "\"" {
                            cell.append("\"")
                        } else {
                            inQuotes = false
                            processCSVNonQuoteCharacter(next, row: &row, cell: &cell, rows: &rows)
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            default:
                if inQuotes {
                    cell.append(char)
                } else {
                    processCSVNonQuoteCharacter(char, row: &row, cell: &cell, rows: &rows)
                }
            }
        }

        if inQuotes {
            throw SPARQLError.decodingFailure("Unterminated quoted CSV value.")
        }

        if !cell.isEmpty || !row.isEmpty {
            row.append(cell)
            rows.append(row)
        }

        return rows
    }

    private func processCSVNonQuoteCharacter(
        _ char: Character,
        row: inout [String],
        cell: inout String,
        rows: inout [[String]]
    ) {
        switch char {
        case ",":
            row.append(cell)
            cell = ""
        case "\n", "\r\n":
            // SPARQL CSV ends rows with CRLF, which Swift reads as one Character.
            row.append(cell)
            rows.append(row)
            row = []
            cell = ""
        case "\r":
            break
        default:
            cell.append(char)
        }
    }
}
