/// The character classes of the SPARQL 1.2 grammar that variable names and
/// blank node labels are made of (SPARQL 1.2 Query Language §19.8,
/// productions `PN_CHARS_BASE`, `PN_CHARS_U`, `VARNAME` and `PN_CHARS`).
extension Unicode.Scalar {
    /// `PN_CHARS_BASE`
    var isSPARQLNameBase: Bool {
        switch value {
        case 0x41 ... 0x5A, 0x61 ... 0x7A,
             0x00C0 ... 0x00D6, 0x00D8 ... 0x00F6, 0x00F8 ... 0x02FF,
             0x0370 ... 0x037D, 0x037F ... 0x1FFF, 0x200C ... 0x200D,
             0x2070 ... 0x218F, 0x2C00 ... 0x2FEF, 0x3001 ... 0xD7FF,
             0xF900 ... 0xFDCF, 0xFDF0 ... 0xFFFD, 0x10000 ... 0xEFFFF:
            true
        default:
            false
        }
    }

    /// `PN_CHARS_U`
    var isSPARQLNameStart: Bool {
        isSPARQLNameBase || self == "_"
    }

    /// `[0-9]`
    var isSPARQLDigit: Bool {
        ("0" ... "9").contains(self)
    }

    /// `#x00B7 | [#x0300-#x036F] | [#x203F-#x2040]`, which `VARNAME` and
    /// `PN_CHARS` allow after the first character.
    var isSPARQLNameCombining: Bool {
        switch value {
        case 0x00B7, 0x0300 ... 0x036F, 0x203F ... 0x2040: true
        default: false
        }
    }

    /// A character `VARNAME` allows after the first.
    var isSPARQLVarNameCharacter: Bool {
        isSPARQLNameStart || isSPARQLDigit || isSPARQLNameCombining
    }

    /// `PN_CHARS`
    var isSPARQLNameCharacter: Bool {
        isSPARQLVarNameCharacter || self == "-"
    }
}
