import Foundation

/// Represents all possible values that can exist in the ZIL/Z-Machine environment.
///
/// `ZValue` is a comprehensive enum that encapsulates every type of value that can
/// be manipulated within ZIL programs and the Z-Machine virtual machine. This includes
/// primitive types like numbers and strings, as well as Z-Machine specific types
/// like objects, routines, and properties.
///
/// ## Truth Values
/// ZIL follows Lisp-like truth semantics where:
/// - `null` and the number `0` are false
/// - All other values are true
///
/// ## Usage Example
/// ```swift
/// let number = ZValue.number(42)
/// let text = ZValue.string("Hello, World!")
/// let obj = ZValue.object(ObjectID(1))
///
/// if number.isTrue {
///     print("Number is truthy")
/// }
/// ```
public enum ZValue: Sendable {
    /// A 16-bit signed integer value
    case number(Int16)

    /// A string value
    case string(String)

    /// An atomic symbol (identifier)
    case atom(String)

    /// A reference to a Z-Machine object
    case object(ObjectID)

    /// A reference to a Z-Machine routine
    case routine(RoutineID)

    /// A reference to an object property
    case property(PropertyID)

    /// A reference to an object flag/attribute
    case flag(FlagID)

    /// A movement direction
    case direction(Direction)

    /// A dictionary word
    case word(WordID)

    /// A table or array
    case table(TableID)

    /// The null/nil value
    case null

    /// Determines if this value is considered "true" in ZIL semantics.
    ///
    /// - Returns: `false` for `null` and `number(0)`, `true` for all other values
    public var isTrue: Bool {
        switch self {
        case .null:
            return false
        case .number(let n):
            return n != 0
        default:
            return true
        }
    }

    /// Attempts to extract a number value.
    ///
    /// - Returns: The numeric value if this is a `.number`, otherwise `nil`
    public var asNumber: Int16? {
        if case .number(let n) = self {
            return n
        }
        return nil
    }

    /// Attempts to extract a string value.
    ///
    /// - Returns: The string value if this is a `.string`, otherwise `nil`
    public var asString: String? {
        if case .string(let s) = self {
            return s
        }
        return nil
    }

    /// Attempts to extract an atom value.
    ///
    /// - Returns: The atom string if this is an `.atom`, otherwise `nil`
    public var asAtom: String? {
        if case .atom(let a) = self {
            return a
        }
        return nil
    }
}

/// Represents a unique identifier for Z-Machine objects.
///
/// Objects in the Z-Machine are fundamental entities that represent game items,
/// rooms, characters, and other interactive elements. Each object has a unique
/// numeric identifier.
///
/// ## Object Numbering
/// - Object ID 0 is reserved and represents "no object"
/// - Valid object IDs typically start from 1
/// - Maximum object ID depends on Z-Machine version (255 for v3, 65535 for v4+)
///
/// ## Usage Example
/// ```swift
/// let lantern = ObjectID(42)
/// let room = ObjectID(1)
/// let nothing = ObjectID.none
/// ```
public struct ObjectID: Hashable, Sendable {
    /// The numeric object identifier
    public let id: UInt16

    /// Creates an object ID from a 16-bit unsigned integer.
    ///
    /// - Parameter id: The object identifier value
    public init(_ id: UInt16) {
        self.id = id
    }

    /// Creates an object ID from a signed integer.
    ///
    /// - Parameter id: The object identifier value (converted to UInt16)
    public init(_ id: Int) {
        self.id = UInt16(id)
    }

    /// Represents the absence of an object (ID 0)
    public static let none = ObjectID(0)
}

/// Represents a unique identifier for Z-Machine routines (functions).
///
/// Routines in the Z-Machine are executable code blocks that implement game logic,
/// object actions, and other behavioral elements.
public struct RoutineID: Hashable, Sendable {
    /// The numeric routine identifier
    public let id: UInt16

    /// Creates a routine ID from a 16-bit unsigned integer.
    ///
    /// - Parameter id: The routine identifier value
    public init(_ id: UInt16) {
        self.id = id
    }

    /// Creates a routine ID from a signed integer.
    ///
    /// - Parameter id: The routine identifier value (converted to UInt16)
    public init(_ id: Int) {
        self.id = UInt16(id)
    }

    /// Represents the absence of a routine (ID 0)
    public static let none = RoutineID(0)
}

/// Represents a unique identifier for object properties in the Z-Machine.
///
/// Properties are data associated with objects that define their characteristics,
/// behavior, and state. The Z-Machine defines standard properties (1-31) and
/// allows custom user-defined properties (32+).
///
/// ## Property Categories
/// - **Standard Properties (1-31)**: Predefined properties like DESC, ACTION, FLAGS
/// - **User Properties (32+)**: Custom properties defined by the game author
public struct PropertyID: Hashable, Sendable {
    /// The numeric property identifier
    public let id: UInt8

    /// Creates a property ID from an 8-bit unsigned integer.
    ///
    /// - Parameter id: The property identifier value
    public init(_ id: UInt8) {
        self.id = id
    }

    /// Creates a property ID from a signed integer.
    ///
    /// - Parameter id: The property identifier value (converted to UInt8)
    public init(_ id: Int) {
        self.id = UInt8(id)
    }

    /// Indicates whether this is a standard Z-Machine property.
    ///
    /// Standard properties have IDs from 1 to 31 and have predefined meanings
    /// in the Z-Machine specification.
    ///
    /// - Returns: `true` if this is a standard property (ID 1-31), `false` otherwise
    public var isStandard: Bool {
        return id >= 1 && id <= 31
    }
}

/// Represents a unique identifier for object flags (attributes) in the Z-Machine.
///
/// Flags are boolean properties that can be set or cleared on objects to indicate
/// various states like TAKEBIT (can be picked up), LIGHTBIT (provides light), etc.
/// The Z-Machine supports up to 32 flags per object (IDs 0-31).
public struct FlagID: Hashable, Sendable {
    /// The numeric flag identifier (0-31)
    public let id: UInt8

    /// Creates a flag ID from an 8-bit unsigned integer.
    ///
    /// - Parameter id: The flag identifier value (should be 0-31)
    public init(_ id: UInt8) {
        self.id = id
    }

    /// Creates a flag ID from a signed integer.
    ///
    /// - Parameter id: The flag identifier value (converted to UInt8)
    public init(_ id: Int) {
        self.id = UInt8(id)
    }
}

/// Represents a unique identifier for dictionary words in the Z-Machine.
///
/// The dictionary contains all recognized words for parsing player input.
/// Each word in the dictionary has a unique numeric identifier used by
/// the parser to recognize commands and object references.
public struct WordID: Hashable, Sendable {
    /// The numeric word identifier
    public let id: UInt16

    /// Creates a word ID from a 16-bit unsigned integer.
    ///
    /// - Parameter id: The word identifier value
    public init(_ id: UInt16) {
        self.id = id
    }

    /// Creates a word ID from a signed integer.
    ///
    /// - Parameter id: The word identifier value (converted to UInt16)
    public init(_ id: Int) {
        self.id = UInt16(id)
    }
}

/// Represents a unique identifier for tables and arrays in the Z-Machine.
///
/// Tables are data structures that store collections of values, including
/// arrays of numbers, strings, or other Z-Machine values.
public struct TableID: Hashable, Sendable {
    /// The numeric table identifier
    public let id: UInt16

    /// Creates a table ID from a 16-bit unsigned integer.
    ///
    /// - Parameter id: The table identifier value
    public init(_ id: UInt16) {
        self.id = id
    }

    /// Creates a table ID from a signed integer.
    ///
    /// - Parameter id: The table identifier value (converted to UInt16)
    public init(_ id: Int) {
        self.id = UInt16(id)
    }
}

/// Represents the standard movement directions in interactive fiction.
///
/// These directions are used for navigation between rooms and locations
/// in the game world. Each direction has its logical opposite for
/// bidirectional movement.
public enum Direction: String, CaseIterable, Sendable {
    /// Cardinal directions
    case north = "NORTH"
    case south = "SOUTH"
    case east = "EAST"
    case west = "WEST"

    /// Diagonal directions
    case northeast = "NE"
    case northwest = "NW"
    case southeast = "SE"
    case southwest = "SW"

    /// Vertical directions
    case up = "UP"
    case down = "DOWN"

    /// Spatial directions
    case `in` = "IN"
    case out = "OUT"

    /// Returns the opposite direction for bidirectional movement.
    ///
    /// This property is useful for implementing two-way passages between rooms
    /// where exits should be automatically created in both directions.
    ///
    /// - Returns: The logically opposite direction
    public var opposite: Direction {
        switch self {
        case .north: return .south
        case .south: return .north
        case .east: return .west
        case .west: return .east
        case .northeast: return .southwest
        case .northwest: return .southeast
        case .southeast: return .northwest
        case .southwest: return .northeast
        case .up: return .down
        case .down: return .up
        case .in: return .out
        case .out: return .in
        }
    }
}

/// Represents different versions of the Z-Machine virtual machine.
///
/// Each Z-Machine version has different capabilities, memory limits, and feature sets.
/// The version determines which instructions are available, how memory is organized,
/// and what advanced features (like graphics or sound) are supported.
///
/// ## Version History
/// - **v3**: Original version used by early Infocom games (Zork I-III)
/// - **v4**: Added sound effects and more objects
/// - **v5**: Added color support, mouse input, and more memory
/// - **v6**: Added graphics and multiple windows
/// - **v7**: Rarely used variant of v5
/// - **v8**: Modern version with Unicode support
public enum ZMachineVersion: UInt8, CaseIterable, Sendable, Comparable {
    case v3 = 3
    case v4 = 4
    case v5 = 5
    case v6 = 6
    case v7 = 7
    case v8 = 8

    /// Maximum memory size supported by this Z-Machine version.
    ///
    /// - Returns: Memory limit in bytes
    public var maxMemory: Int {
        switch self {
        case .v3, .v4:
            return 128 * 1024  // 128KB
        case .v5, .v6, .v7, .v8:
            return 256 * 1024  // 256KB (v8 can be larger but 256KB is minimum)
        }
    }

    /// Maximum number of objects supported by this Z-Machine version.
    ///
    /// - Returns: Maximum object count
    public var maxObjects: Int {
        switch self {
        case .v3:
            return 255
        case .v4, .v5, .v6, .v7, .v8:
            return 65535
        }
    }

    /// Indicates whether this version supports color output.
    ///
    /// - Returns: `true` for version 5 and later
    public var hasColor: Bool {
        return self >= .v5
    }

    /// Indicates whether this version supports sound effects.
    ///
    /// - Returns: `true` for version 4 and later
    public var hasSound: Bool {
        return self >= .v4
    }

    /// Indicates whether this version supports graphics.
    ///
    /// - Returns: `true` only for version 6
    public var hasGraphics: Bool {
        return self == .v6
    }

    /// Indicates whether this version supports Unicode text.
    ///
    /// - Returns: `true` for version 5 and later
    public var hasUnicode: Bool {
        return self >= .v5
    }

    /// Indicates whether this version supports extended instructions.
    ///
    /// - Returns: `true` for version 5 and later
    public var hasExtendedInstructions: Bool {
        return self >= .v5
    }

    public static func < (lhs: ZMachineVersion, rhs: ZMachineVersion) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Represents a memory address in the Z-Machine, which can be packed or unpacked.
///
/// Z-Machine addresses can be stored in two forms:
/// - **Packed addresses**: Compressed form used in story files to save space
/// - **Unpacked addresses**: Actual byte addresses used by the virtual machine
///
/// The conversion between packed and unpacked addresses depends on the Z-Machine version,
/// with different multipliers for different versions to accommodate varying memory models.
///
/// ## Packing Ratios by Version
/// - **v3**: 2:1 (packed address × 2 = byte address)
/// - **v4-v7**: 4:1 (packed address × 4 = byte address)
/// - **v8**: 8:1 (packed address × 8 = byte address)
public struct ZAddress: Hashable, Sendable {
    /// The numeric address value
    public let address: UInt32

    /// Whether this address is in packed form
    public let isPacked: Bool

    /// Creates a new Z-Machine address.
    ///
    /// - Parameters:
    ///   - address: The address value
    ///   - packed: Whether the address is in packed form (default: false)
    public init(_ address: UInt32, packed: Bool = false) {
        self.address = address
        self.isPacked = packed
    }

    /// Returns the unpacked (byte) address for the specified Z-Machine version.
    ///
    /// If the address is already unpacked, returns it as-is. If it's packed,
    /// multiplies by the appropriate factor for the given Z-Machine version.
    ///
    /// - Parameter version: The Z-Machine version to use for unpacking
    /// - Returns: The unpacked byte address
    public func unpacked(for version: ZMachineVersion) -> UInt32 {
        if !isPacked {
            return address
        }

        switch version {
        case .v3:
            return address * 2
        case .v4, .v5:
            return address * 4
        case .v6, .v7:
            return address * 4  // Routines only
        case .v8:
            return address * 8
        }
    }
}