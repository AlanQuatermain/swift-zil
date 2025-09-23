import Foundation

/// Central repository for constants used throughout the ZIL toolset.
///
/// `ZConstants` provides a comprehensive collection of constants that define
/// the behavior and limits of the Z-Machine virtual machine, standard property
/// and flag definitions, file format specifications, and other system-wide values.
///
/// ## Organization
/// Constants are organized into logical groups:
/// - Z-Machine runtime limits and constraints
/// - Standard property and flag definitions
/// - File format constants and magic numbers
/// - Text processing and character encoding
/// - Compilation and parsing limits
public enum ZConstants {

    // MARK: - Z-Machine Runtime Limits

    /// Maximum number of local variables allowed per routine
    public static let maxLocals = 15

    /// Maximum call stack depth to prevent infinite recursion
    public static let maxCallStack = 1024

    /// Maximum evaluation stack size for expression evaluation
    public static let maxEvalStack = 1024

    /// Size of the Z-Machine story file header in bytes
    public static let headerSize = 64

    // MARK: - Standard Property Definitions

    /// Standard object properties defined by the Z-Machine specification.
    ///
    /// These properties have predefined meanings and are used by the Z-Machine
    /// interpreter for object management, display, and behavior.
    public enum StandardProperty: UInt8 {
        /// Parent object in the object tree
        case parent = 1
        /// First child object in the object tree
        case child = 2
        /// Next sibling object in the object tree
        case sibling = 3
        /// Object's short name for display
        case name = 4
        /// Long description text
        case description = 5
        /// Action routine to handle interactions
        case action = 6
        /// Object attribute flags
        case flags = 7
        /// Numeric value associated with object
        case value = 8
        /// Container capacity (for containers)
        case capacity = 9
        /// Object size or weight
        case size = 10
        /// Article ("a", "an", "the") for descriptions
        case article = 11
        /// Adjective for object descriptions
        case adjective = 12
        /// Preposition for object relationships
        case preposition = 13
        /// Synonym words for parser recognition
        case synonym = 14
        /// Global variable reference
        case global = 15
        /// Variable type information
        case vtype = 16
        /// Object strength or durability
        case strength = 17
        /// Things contained within this object
        case things = 18
        /// Description function
        case descfcn = 19
        /// First description
        case fdesc = 20
        /// Long description
        case ldesc = 21
        /// Text content
        case text = 22
        /// Contents listing
        case conts = 23
        /// Pseudo-object definitions
        case pseudo = 24
        /// Exit definitions for rooms
        case exits = 25
        /// North exit
        case north = 26
        /// South exit
        case south = 27
        /// East exit
        case east = 28
        /// West exit
        case west = 29
        case northeast = 30
        case northwest = 31
    }

    // MARK: - Standard Flag/Attribute Definitions

    /// Standard object flags (attributes) defined by the Z-Machine specification.
    ///
    /// These flags are boolean properties that can be set on objects to indicate
    /// various states and capabilities. Each flag corresponds to a specific bit
    /// in the object's attribute table.
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

/// Utility functions for ZIL identifier validation and Z-Machine address manipulation.
///
/// `ZUtils` provides static helper functions for common operations needed throughout
/// the ZIL toolset, including identifier validation, address packing/unpacking,
/// and value range checking.
public enum ZUtils {

    /// Converts a string to a valid ZIL identifier.
    ///
    /// This function transforms arbitrary strings into valid ZIL identifiers by:
    /// - Converting to uppercase (ZIL convention)
    /// - Replacing spaces and underscores with hyphens
    /// - Removing invalid characters
    /// - Ensuring the identifier doesn't start with numbers or hyphens
    /// - Avoiding reserved words
    ///
    /// - Parameter string: The input string to convert
    /// - Returns: A valid ZIL identifier
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

    /// Packs a byte address into the compressed format used by a specific Z-Machine version.
    ///
    /// Different Z-Machine versions use different packing ratios to compress addresses
    /// for storage in story files.
    ///
    /// - Parameters:
    ///   - address: The byte address to pack
    ///   - version: The target Z-Machine version
    /// - Returns: The packed address value
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

    /// Unpacks a compressed address into a byte address for a specific Z-Machine version.
    ///
    /// This is the inverse of `packAddress`, converting stored packed addresses
    /// back into actual memory locations.
    ///
    /// - Parameters:
    ///   - packed: The packed address value
    ///   - version: The Z-Machine version used for packing
    /// - Returns: The unpacked byte address
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

    /// Checks if a value fits within the range of a signed 8-bit integer.
    ///
    /// - Parameter value: The value to check
    /// - Returns: `true` if the value fits in the range -128 to 127
    public static func fitsInByte(_ value: Int) -> Bool {
        return value >= -128 && value <= 127
    }

    /// Checks if a value fits within the range of an unsigned 8-bit integer.
    ///
    /// - Parameter value: The value to check
    /// - Returns: `true` if the value fits in the range 0 to 255
    public static func fitsInUnsignedByte(_ value: Int) -> Bool {
        return value >= 0 && value <= 255
    }

    /// Checks if a value fits within the range of a signed 16-bit integer.
    ///
    /// - Parameter value: The value to check
    /// - Returns: `true` if the value fits in the range -32768 to 32767
    public static func fitsInWord(_ value: Int) -> Bool {
        return value >= -32768 && value <= 32767
    }
}