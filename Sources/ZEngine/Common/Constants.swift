import Foundation

/// Constants used throughout the ZIL toolset
public enum ZConstants {

    // MARK: - Z-Machine Limits

    /// Maximum number of locals per routine
    public static let maxLocals = 15

    /// Maximum call stack depth
    public static let maxCallStack = 1024

    /// Maximum evaluation stack size
    public static let maxEvalStack = 1024

    /// Size of Z-Machine header
    public static let headerSize = 64

    // MARK: - Standard Property Numbers

    public enum StandardProperty: UInt8 {
        case parent = 1
        case child = 2
        case sibling = 3
        case name = 4
        case description = 5
        case action = 6
        case flags = 7
        case value = 8
        case capacity = 9
        case size = 10
        case article = 11
        case adjective = 12
        case preposition = 13
        case synonym = 14
        case global = 15
        case vtype = 16
        case strength = 17
        case things = 18
        case descfcn = 19
        case fdesc = 20
        case ldesc = 21
        case text = 22
        case conts = 23
        case pseudo = 24
        case exits = 25
        case north = 26
        case south = 27
        case east = 28
        case west = 29
        case northeast = 30
        case northwest = 31
    }

    // MARK: - Standard Flags/Attributes

    public enum StandardFlag: UInt8 {
        case invisible = 0
        case takebit = 1
        case containerbit = 2
        case wearbit = 3
        case lightbit = 4
        case burnbit = 5
        case onbit = 6
        case doorbit = 7
        case touchbit = 8
        case searchbit = 9
        case sacredbit = 10
        case treebit = 11
        case nallbit = 12
        case overbit = 13
        case trytakebit = 14
        case vowelbit = 15
        case toolbit = 16
        case transbit = 17
        case foodbit = 18
        case vehbit = 19
        case weaponbit = 20
        case readbit = 21
        case surfacebit = 22
        case climbbit = 23
        case integralbit = 24
        case fightbit = 25
        case staggered = 26
        case kludgebit = 27
        case person = 28
        case narrated = 29
        case openbit = 30
        case ndescbit = 31
    }

    // MARK: - Built-in Global Variables

    public enum GlobalVariable: UInt8 {
        case here = 0
        case winner = 1
        case prsa = 2      // Parser action
        case prsi = 3      // Parser indirect object
        case prso = 4      // Parser direct object
        case it = 5
        case them = 6
        case score = 7
        case moves = 8
        case deaths = 9
        case max_score = 10
        case player = 11
        case rooms = 12
        case actions = 13
        case adjectives = 14
        case directions = 15
        case prepositions = 16
        case buzzwords = 17
        case parser = 18
        case not_here_object = 19
        case pure_length = 20
    }

    // MARK: - File Format Constants

    /// Z-code file magic numbers (first bytes)
    public static let zcodeMagic: [UInt8: String] = [
        3: "Z3",
        4: "Z4",
        5: "Z5",
        6: "Z6",
        7: "Z7",
        8: "Z8"
    ]

    /// Default file extensions by version
    public static let fileExtensions: [UInt8: String] = [
        3: ".z3",
        4: ".z4",
        5: ".z5",
        6: ".z6",
        7: ".z7",
        8: ".z8"
    ]

    // MARK: - Text Processing

    /// ZSCII character set constants
    public static let zsciiSpace: UInt8 = 32
    public static let zsciiNewline: UInt8 = 13
    public static let zsciiNull: UInt8 = 0

    /// Text encoding alphabets (Z-Machine standard)
    public static let alphabet0 = "abcdefghijklmnopqrstuvwxyz"
    public static let alphabet1 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    public static let alphabet2 = " \n0123456789.,!?_#'\"/\\-:()"

    // MARK: - Opcodes and Instructions

    /// Variable argument types
    public enum ArgumentType: UInt8 {
        case large = 0     // 16-bit constant
        case small = 1     // 8-bit constant
        case variable = 2  // Variable reference
        case omitted = 3   // Not provided
    }

    /// Instruction form types
    public enum InstructionForm {
        case short      // 0-1 operands
        case long       // 2 operands
        case variable   // 0-4 operands (VAR form)
        case extended   // Extended form (v5+)
    }

    // MARK: - Error Messages

    public static let errorMessages: [String: String] = [
        "STACK_UNDERFLOW": "Stack underflow",
        "STACK_OVERFLOW": "Stack overflow",
        "INVALID_OPCODE": "Invalid opcode",
        "DIVISION_BY_ZERO": "Division by zero",
        "INVALID_OBJECT": "Invalid object number",
        "INVALID_PROPERTY": "Invalid property number",
        "MEMORY_ACCESS": "Invalid memory access",
        "CORRUPTED_FILE": "Corrupted story file",
        "VERSION_MISMATCH": "Z-Machine version mismatch"
    ]

    // MARK: - Compilation Constants

    /// Maximum symbol name length
    public static let maxSymbolLength = 255

    /// Maximum nesting depth for expressions
    public static let maxNestingDepth = 64

    /// Maximum number of includes per file
    public static let maxIncludes = 32

    /// ZIL reserved words that cannot be used as identifiers
    public static let reservedWords: Set<String> = [
        "ROUTINE", "OBJECT", "ROOM", "GLOBAL", "CONSTANT", "PROPERTY",
        "SYNTAX", "VERB", "ADJECTIVE", "PREPOSITION", "BUZZ-WORD",
        "DIRECTIONS", "IF", "COND", "AND", "OR", "NOT", "PROG", "REPEAT",
        "RETURN", "RTRUE", "RFALSE", "TELL", "PRINTI", "PRINTN", "PRINT",
        "CRLF", "MOVE", "REMOVE", "FSET", "FCLEAR", "FGET", "GET", "PUT",
        "GETB", "PUTB", "GETP", "PUTP", "FIRST", "NEXT", "PARENT", "CHILD",
        "SIBLING", "LOC", "IN?", "HELD?", "CARRIED?", "EQUAL?", "LESS?",
        "GREATER?", "ZERO?", "NEXT?", "VERB?", "PRSA?", "PRSO?", "PRSI?"
    ]
}

/// Common utility functions and extensions
public enum ZUtils {

    /// Convert a string to a valid ZIL identifier
    public static func makeValidIdentifier(_ string: String) -> String {
        let cleaned = string.uppercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")

        // Remove invalid characters
        let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-?"))
        let filtered = cleaned.unicodeScalars.filter { validChars.contains($0) }
        let result = String(String.UnicodeScalarView(filtered))

        // Ensure it doesn't start with a number or dash
        if result.first?.isNumber == true || result.first == "-" {
            return "Z-" + result
        }

        // Check for reserved words
        if ZConstants.reservedWords.contains(result) {
            return result + "-1"
        }

        return result.isEmpty ? "UNNAMED" : result
    }

    /// Pack a Z-Machine address for the given version
    public static func packAddress(_ address: UInt32, version: ZMachineVersion) -> UInt16 {
        let divisor: UInt32
        switch version {
        case .v3:
            divisor = 2
        case .v4, .v5:
            divisor = 4
        case .v6, .v7:
            divisor = 4
        case .v8:
            divisor = 8
        }
        return UInt16(address / divisor)
    }

    /// Unpack a Z-Machine address for the given version
    public static func unpackAddress(_ packed: UInt16, version: ZMachineVersion) -> UInt32 {
        let multiplier: UInt32
        switch version {
        case .v3:
            multiplier = 2
        case .v4, .v5:
            multiplier = 4
        case .v6, .v7:
            multiplier = 4
        case .v8:
            multiplier = 8
        }
        return UInt32(packed) * multiplier
    }

    /// Check if a value fits in a signed byte
    public static func fitsInByte(_ value: Int) -> Bool {
        return value >= -128 && value <= 127
    }

    /// Check if a value fits in an unsigned byte
    public static func fitsInUnsignedByte(_ value: Int) -> Bool {
        return value >= 0 && value <= 255
    }

    /// Check if a value fits in a signed word
    public static func fitsInWord(_ value: Int) -> Bool {
        return value >= -32768 && value <= 32767
    }
}