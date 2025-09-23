import Foundation

/// ZIL value types - represents all possible values in ZIL/Z-Machine
public enum ZValue: Sendable {
    case number(Int16)
    case string(String)
    case atom(String)
    case object(ObjectID)
    case routine(RoutineID)
    case property(PropertyID)
    case flag(FlagID)
    case direction(Direction)
    case word(WordID)
    case table(TableID)
    case null

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

    public var asNumber: Int16? {
        if case .number(let n) = self {
            return n
        }
        return nil
    }

    public var asString: String? {
        if case .string(let s) = self {
            return s
        }
        return nil
    }

    public var asAtom: String? {
        if case .atom(let a) = self {
            return a
        }
        return nil
    }
}

/// Object identifier in the Z-Machine
public struct ObjectID: Hashable, Sendable {
    public let id: UInt16

    public init(_ id: UInt16) {
        self.id = id
    }

    public init(_ id: Int) {
        self.id = UInt16(id)
    }

    public static let none = ObjectID(0)
}

/// Routine identifier
public struct RoutineID: Hashable, Sendable {
    public let id: UInt16

    public init(_ id: UInt16) {
        self.id = id
    }

    public init(_ id: Int) {
        self.id = UInt16(id)
    }

    public static let none = RoutineID(0)
}

/// Property identifier (1-31 for standard properties, 32+ for user properties)
public struct PropertyID: Hashable, Sendable {
    public let id: UInt8

    public init(_ id: UInt8) {
        self.id = id
    }

    public init(_ id: Int) {
        self.id = UInt8(id)
    }

    public var isStandard: Bool {
        return id >= 1 && id <= 31
    }
}

/// Flag/Attribute identifier (0-31 for object flags)
public struct FlagID: Hashable, Sendable {
    public let id: UInt8

    public init(_ id: UInt8) {
        self.id = id
    }

    public init(_ id: Int) {
        self.id = UInt8(id)
    }
}

/// Dictionary word identifier
public struct WordID: Hashable, Sendable {
    public let id: UInt16

    public init(_ id: UInt16) {
        self.id = id
    }

    public init(_ id: Int) {
        self.id = UInt16(id)
    }
}

/// Table identifier for arrays and tables
public struct TableID: Hashable, Sendable {
    public let id: UInt16

    public init(_ id: UInt16) {
        self.id = id
    }

    public init(_ id: Int) {
        self.id = UInt16(id)
    }
}

/// Direction constants for movement
public enum Direction: String, CaseIterable, Sendable {
    case north = "NORTH"
    case south = "SOUTH"
    case east = "EAST"
    case west = "WEST"
    case northeast = "NE"
    case northwest = "NW"
    case southeast = "SE"
    case southwest = "SW"
    case up = "UP"
    case down = "DOWN"
    case `in` = "IN"
    case out = "OUT"

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

/// Z-Machine version information
public enum ZMachineVersion: UInt8, CaseIterable, Sendable, Comparable {
    case v3 = 3
    case v4 = 4
    case v5 = 5
    case v6 = 6
    case v7 = 7
    case v8 = 8

    public var maxMemory: Int {
        switch self {
        case .v3, .v4:
            return 128 * 1024  // 128KB
        case .v5, .v6, .v7, .v8:
            return 256 * 1024  // 256KB (v8 can be larger but 256KB is minimum)
        }
    }

    public var maxObjects: Int {
        switch self {
        case .v3:
            return 255
        case .v4, .v5, .v6, .v7, .v8:
            return 65535
        }
    }

    public var hasColor: Bool {
        return self >= .v5
    }

    public var hasSound: Bool {
        return self >= .v4
    }

    public var hasGraphics: Bool {
        return self == .v6
    }

    public var hasUnicode: Bool {
        return self >= .v5
    }

    public var hasExtendedInstructions: Bool {
        return self >= .v5
    }

    public static func < (lhs: ZMachineVersion, rhs: ZMachineVersion) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Memory address in Z-Machine (packed or unpacked)
public struct ZAddress: Hashable, Sendable {
    public let address: UInt32
    public let isPacked: Bool

    public init(_ address: UInt32, packed: Bool = false) {
        self.address = address
        self.isPacked = packed
    }

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