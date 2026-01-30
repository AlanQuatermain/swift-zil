/// PropertyDefManager: Manages property definitions and dynamic property number assignment
///
/// In ZIL, property numbers are assigned sequentially based on the order properties
/// are first used in object definitions. PROPDEF declarations establish default values
/// but don't determine property numbers.
///
/// Key Points:
/// - Property numbers start at 1 (property 0 is reserved as end-of-table marker)
/// - Numbers assigned sequentially based on FIRST USAGE in objects
/// - Z-Machine v3: 31 properties (1-31)
/// - Z-Machine v4+: 63 properties (1-63)
/// - PROPDEF can appear anywhere (forward references allowed)
/// - Properties MUST be stored in DESCENDING order in object property tables
///
/// Reference: OBJECT-SYSTEM-GUIDANCE.md, sections 2, 3, and 5

import Foundation

/// Represents a property value in ZIL
public enum PropertyValue: Equatable {
    /// Integer value (word-sized)
    case integer(Int16)

    /// String value (becomes ZSCII-encoded text)
    case string(String)

    /// Atom/symbol reference
    case atom(String)

    /// Routine reference
    case routine(String)

    /// Table reference
    case table(String)

    /// Object reference
    case object(String)

    /// False/empty/none
    case none

    /// List of values (for properties that can hold multiple items)
    case list([PropertyValue])
}

/// Represents how a property value will be encoded in the final binary
/// Compiler generates symbolic references; assembler resolves to addresses
public enum PropertyValueEncoding: Equatable {
    /// Immediate bytes (for integers, encoded objects, etc.)
    case bytes([UInt8])

    /// Symbolic reference to a routine (resolved by assembler to packed address)
    case routineReference(String)

    /// Symbolic reference to a string (resolved by assembler to packed address)
    case stringReference(String)

    /// Symbolic reference to a table (resolved by assembler to packed address)
    case tableReference(String)
}

/// Manages property definitions and assigns property numbers
public struct PropertyDefManager {

    // MARK: - Properties

    /// Maps property names to their assigned numbers
    private var propertyToNumber: [String: Int] = [:]

    /// Maps property numbers back to names (for debugging/diagnostics)
    private var numberToProperty: [Int: String] = [:]

    /// Maps property names to their default values (from PROPDEF)
    private var propertyDefaults: [String: PropertyValue] = [:]

    /// Next available property number (starts at 1, property 0 is reserved)
    private var nextPropertyNumber: Int = 1

    /// Maximum number of properties for this Z-Machine version
    private let maxProperties: Int

    /// Z-Machine version (affects property limit)
    private let zMachineVersion: Int

    // MARK: - Initialization

    /// Initialize the property manager for a specific Z-Machine version
    /// - Parameter zMachineVersion: Z-Machine version (3, 4, 5, 6, or 8)
    public init(zMachineVersion: Int) {
        self.zMachineVersion = zMachineVersion

        // v1-3: 31 properties (1-31, property 0 is reserved)
        // v4+:  63 properties (1-63, property 0 is reserved)
        self.maxProperties = (zMachineVersion >= 4) ? 63 : 31
    }

    // MARK: - Property Definition (PROPDEF)

    /// Define a property default value from a PROPDEF declaration
    /// - Parameters:
    ///   - name: The property name
    ///   - defaultValue: The default value for this property
    /// - Note: This does NOT assign a property number; that happens on first usage
    public mutating func definePropertyDefault(name: String, defaultValue: PropertyValue) {
        propertyDefaults[name] = defaultValue
    }

    // MARK: - Property Number Assignment

    /// Assign a property number to a property name (on first usage)
    /// - Parameter propertyName: The property name to assign a number to
    /// - Returns: The assigned property number (1-31 for v3, 1-63 for v4+)
    /// - Throws: ParseError if too many properties are defined
    public mutating func assignPropertyNumber(for propertyName: String) throws -> Int {
        // Check if already assigned
        if let existing = propertyToNumber[propertyName] {
            return existing
        }

        // Validate limit
        guard nextPropertyNumber <= maxProperties else {
            throw ParseError.invalidSyntax(
                "Too many properties defined: \(nextPropertyNumber) exceeds maximum of \(maxProperties) for Z-Machine version \(zMachineVersion)",
                location: .unknown
            )
        }

        // Assign next sequential number
        let propNum = nextPropertyNumber
        propertyToNumber[propertyName] = propNum
        numberToProperty[propNum] = propertyName
        nextPropertyNumber += 1

        return propNum
    }

    /// Get the property number for a property name (if already assigned)
    /// - Parameter propertyName: The property name to look up
    /// - Returns: The property number, or nil if not yet assigned
    public func getPropertyNumber(for propertyName: String) -> Int? {
        return propertyToNumber[propertyName]
    }

    /// Get the property name for a property number (reverse lookup)
    /// - Parameter propertyNumber: The property number to look up
    /// - Returns: The property name, or nil if not assigned
    public func getPropertyName(for propertyNumber: Int) -> String? {
        return numberToProperty[propertyNumber]
    }

    // MARK: - Default Values

    /// Get the default value for a property (from PROPDEF)
    /// - Parameter propertyName: The property name
    /// - Returns: The default value, or .none if no PROPDEF exists
    public func getDefaultValue(for propertyName: String) -> PropertyValue {
        return propertyDefaults[propertyName] ?? .none
    }

    /// Check if a property has a defined default value
    /// - Parameter propertyName: The property name
    /// - Returns: True if a PROPDEF exists for this property
    public func hasDefaultValue(for propertyName: String) -> Bool {
        return propertyDefaults[propertyName] != nil
    }

    // MARK: - Queries

    /// Get all assigned properties sorted by property number
    /// - Returns: Array of (name, number, defaultValue) tuples in ascending order
    public func getAllProperties() -> [(name: String, number: Int, defaultValue: PropertyValue)] {
        return propertyToNumber.map {
            ($0.key, $0.value, propertyDefaults[$0.key] ?? .none)
        }.sorted { $0.1 < $1.1 }
    }

    /// Get the total number of properties assigned
    public var propertyCount: Int {
        return nextPropertyNumber - 1  // Subtract 1 because we start at 1
    }

    /// Get the maximum number of properties for this version
    public var propertyLimit: Int {
        return maxProperties
    }

    /// Check if a property name has been assigned a number
    /// - Parameter propertyName: The property name to check
    /// - Returns: True if the property has been assigned a number
    public func hasProperty(_ propertyName: String) -> Bool {
        return propertyToNumber[propertyName] != nil
    }

    // MARK: - Diagnostics

    /// Generate a diagnostic report of all properties
    public func generateReport() -> String {
        let properties = getAllProperties()
        let count = propertyCount

        var report = "Property Manager Report\n"
        report += "=======================\n"
        report += "Z-Machine Version: \(zMachineVersion)\n"
        report += "Property Limit: \(maxProperties)\n"
        report += "Properties Assigned: \(count)\n\n"

        if count > 0 {
            report += "Assigned Properties:\n"
            for (name, number, defaultValue) in properties {
                let defaultStr = defaultValue == .none ? "" : " (default: \(defaultValue))"
                report += String(format: "  %2d: %@%@\n", number, name, defaultStr)
            }
        } else {
            report += "No properties assigned yet.\n"
        }

        // List PROPDEFs without assigned numbers
        let unassignedDefaults = propertyDefaults.filter { propertyToNumber[$0.key] == nil }
        if !unassignedDefaults.isEmpty {
            report += "\nProperty Defaults Not Yet Used:\n"
            for (name, value) in unassignedDefaults.sorted(by: { $0.key < $1.key }) {
                report += "  \(name): \(value)\n"
            }
        }

        return report
    }
}
