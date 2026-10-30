import RDFCore

extension Literal {
    /// This literal in SPARQL text: its lexical form as a
    /// `STRING_LITERAL_QUOTE`, with its language tag, base direction or
    /// datatype (SPARQL 1.2 Query Language §19.8).
    func render() -> String {
        var text = "\""
        for scalar in lexicalForm.unicodeScalars {
            switch scalar {
            case "\"": text += #"\""#
            case "\\": text += #"\\"#
            case "\n": text += #"\n"#
            case "\r": text += #"\r"#
            case "\t": text += #"\t"#
            case "\u{08}": text += #"\b"#
            case "\u{0C}": text += #"\f"#
            default: text.unicodeScalars.append(scalar)
            }
        }
        text += "\""
        if let languageTag {
            text += "@" + languageTag
            if let baseDirection {
                text += "--" + baseDirection.rawValue
            }
        } else if let datatype {
            text += "^^" + datatype.render()
        }
        return text
    }
}
