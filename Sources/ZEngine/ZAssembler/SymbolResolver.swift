/// SymbolResolver: Protocol for resolving symbolic references during assembly
///
/// This protocol enables the assembler to resolve symbolic references in compiled
/// objects (routines, strings, tables) to actual packed addresses. It supports both:
/// - Compiler path: Full symbol table from ZIL compilation
/// - Assembler path: Incremental symbol table from ZAP directives
///
/// Reference: OBJECT-SYSTEM-GUIDANCE.md, section on assembler integration

import Foundation

/// Packed address representation for resolved symbols
/// Handles version-specific address packing for Z-Machine
///
/// Packing formulas per Z-Machine specification:
/// - v1-3: packed = byte_address ÷ 2
/// - v4-5: packed = byte_address ÷ 4
/// - v6-7: packed = (byte_address - offset) ÷ 4 (see limitation below)
/// - v8: packed = byte_address ÷ 8
///
/// **LIMITATION**: V6/V7 support is currently incomplete. These versions require
/// different offsets for routines (Routines Offset from header) vs strings (Strings
/// Offset from header). Current implementation does not distinguish between address
/// types and does not apply offsets. Full V6/V7 support requires:
/// - Distinguishing routine vs string vs static addresses
/// - Reading R_O and S_O from story file header
/// - Applying appropriate offsets before packing
///
/// For now, this implementation correctly supports **v1-5 and v8**.
public struct PackedAddress: Equatable {
    /// Raw address in memory
    public let address: UInt32

    /// Z-Machine version (affects packing calculation)
    public let version: Int

    public init(address: UInt32, version: Int) {
        self.address = address
        self.version = version
    }

    /// Convert to packed address bytes (big-endian)
    /// Packing formula varies by Z-Machine version:
    /// - v1-3: address ÷ 2
    /// - v4-5: address ÷ 4
    /// - v6-7: address ÷ 4 (with routine offset for routines)
    /// - v8: address ÷ 8
    public func toBytes() -> [UInt8] {
        let packed: UInt32
        switch version {
        case 1...3:
            packed = address / 2
        case 4...5:
            packed = address / 4
        case 6...7:
            packed = address / 4
        case 8:
            packed = address / 8
        default:
            packed = address
        }

        // Return as 2-byte big-endian value
        let word = UInt16(packed & 0xFFFF)
        return [UInt8(word >> 8), UInt8(word & 0xFF)]
    }
}

/// Protocol for resolving symbolic references during object property encoding
///
/// Implementations provide mapping from symbolic names/content to actual addresses:
/// - CompilerSymbolResolver: Uses full compilation context
/// - AssemblerSymbolResolver: Uses incremental ZAP assembly context
public protocol SymbolResolver {
    /// Resolve routine name to packed address
    /// - Parameter name: Routine name (e.g., "DOOR-FCN")
    /// - Returns: Packed address if routine is defined, nil otherwise
    func resolveRoutine(_ name: String) -> PackedAddress?

    /// Resolve string content to packed address
    /// - Parameter content: String content (e.g., "Welcome to Zork!")
    /// - Returns: Packed address if string exists in table, nil otherwise
    /// - Note: May trigger string table addition for new strings
    func resolveString(_ content: String) -> PackedAddress?

    /// Resolve table name to packed address
    /// - Parameter name: Table name (e.g., "CONTAINER-TABLE")
    /// - Returns: Packed address if table is defined, nil otherwise
    func resolveTable(_ name: String) -> PackedAddress?

    /// Get property number for property name
    /// - Parameter name: Property name (e.g., "DESC", "ACTION")
    /// - Returns: Property number (1-31 for v3, 1-63 for v4+), or nil if not defined
    /// - Note: Only used by compiler path; assembler may use hardcoded mappings
    func getPropertyNumber(_ name: String) -> Int?
}

/// Mock resolver for testing
public class MockSymbolResolver: SymbolResolver {
    private var routines: [String: PackedAddress] = [:]
    private var strings: [String: PackedAddress] = [:]
    private var tables: [String: PackedAddress] = [:]
    private var properties: [String: Int] = [:]

    public init() {}

    public func registerRoutine(_ name: String, address: PackedAddress) {
        routines[name] = address
    }

    public func registerString(_ content: String, address: PackedAddress) {
        strings[content] = address
    }

    public func registerTable(_ name: String, address: PackedAddress) {
        tables[name] = address
    }

    public func registerProperty(_ name: String, number: Int) {
        properties[name] = number
    }

    public func resolveRoutine(_ name: String) -> PackedAddress? {
        routines[name]
    }

    public func resolveString(_ content: String) -> PackedAddress? {
        strings[content]
    }

    public func resolveTable(_ name: String) -> PackedAddress? {
        tables[name]
    }

    public func getPropertyNumber(_ name: String) -> Int? {
        properties[name]
    }
}
