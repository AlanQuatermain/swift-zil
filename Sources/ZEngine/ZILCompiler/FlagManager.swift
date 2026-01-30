/// FlagManager: Manages dynamic assignment of attribute numbers to flag names
///
/// In ZIL, flag names (like TAKEBIT, OPENBIT, etc.) are assigned sequential attribute numbers
/// by the compiler as they are encountered. This manager ensures consistent global numbering
/// across all objects in the game.
///
/// Key Points:
/// - Flag names are GLOBAL across the entire game
/// - Attribute numbers are assigned sequentially (0, 1, 2, ...)
/// - Z-Machine v3: 32 attributes (0-31)
/// - Z-Machine v4+: 48 attributes (0-47)
/// - The GLOBAL-OBJECTS pattern ensures standard flags get consistent low numbers
///
/// Reference: OBJECT-SYSTEM-GUIDANCE.md, sections 1 and 4

import Foundation

/// Manages dynamic assignment of Z-Machine attribute numbers to ZIL flag names
public struct FlagManager {

    // MARK: - Properties

    /// Maps flag names to their assigned attribute numbers
    private var flagToAttributeNumber: [String: Int] = [:]

    /// Maps attribute numbers back to flag names (for debugging/diagnostics)
    private var attributeNumberToFlag: [Int: String] = [:]

    /// Next available attribute number
    private var nextAttributeNumber: Int = 0

    /// Maximum number of attributes for this Z-Machine version
    private let maxAttributes: Int

    /// Z-Machine version (affects attribute limit)
    private let zMachineVersion: Int

    // MARK: - Initialization

    /// Initialize the flag manager for a specific Z-Machine version
    /// - Parameter zMachineVersion: Z-Machine version (3, 4, 5, 6, or 8)
    public init(zMachineVersion: Int) {
        self.zMachineVersion = zMachineVersion

        // v1-3: 32 attributes (0-31)
        // v4+:  48 attributes (0-47)
        self.maxAttributes = (zMachineVersion >= 4) ? 48 : 32
    }

    // MARK: - Public API

    /// Assign an attribute number to a flag name
    /// - Parameter flagName: The flag name (e.g., "TAKEBIT", "OPENBIT")
    /// - Returns: The assigned attribute number (0-31 for v3, 0-47 for v4+)
    /// - Throws: ParseError if too many flags are defined
    public mutating func assignAttributeNumber(for flagName: String) throws -> Int {
        // Check if already assigned
        if let existing = flagToAttributeNumber[flagName] {
            return existing
        }

        // Validate limit
        guard nextAttributeNumber < maxAttributes else {
            throw ParseError.invalidSyntax(
                "Too many flags defined: \(nextAttributeNumber + 1) exceeds maximum of \(maxAttributes) for Z-Machine version \(zMachineVersion)",
                location: .unknown
            )
        }

        // Assign next sequential number
        let attrNum = nextAttributeNumber
        flagToAttributeNumber[flagName] = attrNum
        attributeNumberToFlag[attrNum] = flagName
        nextAttributeNumber += 1

        return attrNum
    }

    /// Get the attribute number for a flag name (if already assigned)
    /// - Parameter flagName: The flag name to look up
    /// - Returns: The attribute number, or nil if not yet assigned
    public func getAttributeNumber(for flagName: String) -> Int? {
        return flagToAttributeNumber[flagName]
    }

    /// Get the flag name for an attribute number (reverse lookup)
    /// - Parameter attributeNumber: The attribute number to look up
    /// - Returns: The flag name, or nil if not assigned
    public func getFlagName(for attributeNumber: Int) -> String? {
        return attributeNumberToFlag[attributeNumber]
    }

    /// Get all assigned flags sorted by attribute number
    /// - Returns: Array of (name, number) tuples in ascending order
    public func getAllFlags() -> [(name: String, number: Int)] {
        return flagToAttributeNumber.map { ($0.key, $0.value) }
            .sorted { $0.1 < $1.1 }
    }

    /// Get the total number of flags assigned
    public var flagCount: Int {
        return nextAttributeNumber
    }

    /// Get the maximum number of attributes for this version
    public var attributeLimit: Int {
        return maxAttributes
    }

    /// Check if a flag name has been assigned
    /// - Parameter flagName: The flag name to check
    /// - Returns: True if the flag has been assigned an attribute number
    public func hasFlag(_ flagName: String) -> Bool {
        return flagToAttributeNumber[flagName] != nil
    }

    // MARK: - Diagnostics

    /// Generate a diagnostic report of all assigned flags
    public func generateReport() -> String {
        let flags = getAllFlags()
        let count = flagCount

        var report = "Flag Manager Report\n"
        report += "===================\n"
        report += "Z-Machine Version: \(zMachineVersion)\n"
        report += "Attribute Limit: \(maxAttributes)\n"
        report += "Flags Assigned: \(count)\n\n"

        if count > 0 {
            report += "Assigned Flags:\n"
            for (name, number) in flags {
                report += String(format: "  %2d: %@\n", number, name)
            }
        } else {
            report += "No flags assigned yet.\n"
        }

        return report
    }
}
