/// ObjectTreeBuilder: Builds the Z-Machine object tree from ZIL object definitions
///
/// This builder processes OBJECT declarations and constructs the binary object tree
/// required by the Z-Machine, including:
/// - Object attribute tables (flags)
/// - Parent/child/sibling relationships
/// - Property tables (in descending numerical order)
///
/// Implementation uses a two-pass approach:
/// - Pass 1: Collect all objects, assign IDs, extract flags/properties
/// - Pass 2: Resolve relationships, build sibling chains, generate binary tables
///
/// Reference: OBJECT-SYSTEM-GUIDANCE.md, sections on ObjectTreeBuilder

import Foundation

/// Represents an object during compilation (before binary generation)
public struct ObjectData {
    /// Object ID (sequential, starting from 1)
    let id: Int

    /// Object name (symbolic identifier)
    let name: String

    /// Parent object name (symbolic, resolved in pass 2)
    var parentName: String?

    /// Flag names for this object
    var flags: [String]

    /// Properties: name -> value
    var properties: [String: PropertyValue]

    /// Source location for error reporting
    let location: SourceLocation

    public init(
        id: Int,
        name: String,
        parentName: String? = nil,
        flags: [String] = [],
        properties: [String: PropertyValue] = [:],
        location: SourceLocation
    ) {
        self.id = id
        self.name = name
        self.parentName = parentName
        self.flags = flags
        self.properties = properties
        self.location = location
    }
}

/// Represents a compiled property with symbolic encoding
public struct CompiledProperty {
    /// Property number (1-31 for v3, 1-63 for v4+)
    let number: Int

    /// Property name (for debugging)
    let name: String

    /// Encoded property value (bytes or symbolic references)
    let encoding: PropertyValueEncoding
}

/// Represents a compiled object with resolved relationships
public struct CompiledObject {
    /// Object ID
    let id: Int

    /// Object name
    let name: String

    /// Parent object ID (0 if no parent)
    let parentID: Int

    /// Sibling object ID (0 if no sibling)
    let siblingID: Int

    /// Child object ID (0 if no child)
    let childID: Int

    /// Attribute bit array (flags)
    let attributes: [UInt8]

    /// Short name (Z-encoded with length prefix) for object description
    let shortName: [UInt8]

    /// Compiled properties (in DESCENDING order by property number)
    let properties: [CompiledProperty]

    /// Source location
    let location: SourceLocation

    /// Backwards-compatible property table accessor (for tests)
    /// TODO: Remove this once MemoryLayoutManager is updated
    var propertyTable: [UInt8] {
        var table: [UInt8] = []

        // 1. Add short name
        table.append(contentsOf: shortName)

        // 2. Add properties (already in descending order)
        for property in properties {
            // Encode property header and data
            // This is a simplified version - full implementation in MemoryLayoutManager
            switch property.encoding {
            case .bytes(let data):
                // Add property number and size header
                let size = data.count
                if size <= 8 {
                    let sizeField = UInt8(size - 1)
                    let header = (sizeField << 5) | UInt8(property.number)
                    table.append(header)
                    table.append(contentsOf: data)
                }
            default:
                // For symbolic references, add placeholder (will be resolved by assembler)
                // For now, encode as 2-byte zero value
                let header = (1 << 5) | UInt8(property.number)  // size=2
                table.append(header)
                table.append(0)
                table.append(0)
            }
        }

        // 3. Add terminator
        table.append(0)

        return table
    }
}

/// Builds the Z-Machine object tree from ZIL object definitions
public struct ObjectTreeBuilder {

    // MARK: - Properties

    /// Z-Machine version
    private let zMachineVersion: Int

    /// Flag manager for attribute number assignment
    private var flagManager: FlagManager

    /// Property manager for property number assignment
    private var propertyManager: PropertyDefManager

    /// Collected objects (by name)
    private var objects: [String: ObjectData] = [:]

    /// Object ID assignment order
    private var objectIDToName: [Int: String] = [:]

    /// Next object ID
    private var nextObjectID: Int = 1

    // MARK: - Initialization

    /// Initialize the object tree builder
    /// - Parameters:
    ///   - zMachineVersion: Z-Machine version (affects limits)
    ///   - flagManager: Flag manager for attribute assignment
    ///   - propertyManager: Property manager for property number assignment
    public init(
        zMachineVersion: Int,
        flagManager: FlagManager,
        propertyManager: PropertyDefManager
    ) {
        self.zMachineVersion = zMachineVersion
        self.flagManager = flagManager
        self.propertyManager = propertyManager
    }

    // MARK: - Pass 1: Object Collection

    /// Add an object definition (Pass 1)
    /// - Parameters:
    ///   - name: Object name
    ///   - parentName: Parent object name (symbolic)
    ///   - flags: List of flag names
    ///   - properties: Dictionary of property name -> value
    ///   - location: Source location
    /// - Throws: ParseError if object already exists or limits exceeded
    public mutating func addObject(
        name: String,
        parentName: String?,
        flags: [String],
        properties: [String: PropertyValue],
        location: SourceLocation
    ) throws {
        // Check for duplicate object names
        if objects[name] != nil {
            throw ParseError.invalidSyntax("Duplicate object definition: '\(name)'", location: location)
        }

        // Assign object ID
        let objectID = nextObjectID
        nextObjectID += 1

        // Validate object count limit
        let maxObjects = (zMachineVersion >= 4) ? 65535 : 255
        guard objectID <= maxObjects else {
            throw ParseError.invalidSyntax(
                "Too many objects: \(objectID) exceeds maximum of \(maxObjects) for Z-Machine version \(zMachineVersion)",
                location: location
            )
        }

        // Assign attribute numbers for all flags
        for flagName in flags {
            _ = try flagManager.assignAttributeNumber(for: flagName)
        }

        // Create object data (don't assign property numbers yet)
        let objectData = ObjectData(
            id: objectID,
            name: name,
            parentName: parentName,
            flags: flags,
            properties: properties,
            location: location
        )

        objects[name] = objectData
        objectIDToName[objectID] = name
    }

    // MARK: - Pass 2: Tree Building & Binary Generation

    /// Build the complete object tree (Pass 2)
    /// - Returns: Array of compiled objects in ID order
    /// - Throws: ParseError if relationships are invalid
    public mutating func build() throws -> [CompiledObject] {
        var compiled: [CompiledObject] = []

        // First pass: Assign property numbers based on usage order
        let sortedObjects = objects.values.sorted { $0.id < $1.id }
        for object in sortedObjects {
            for propertyName in object.properties.keys {
                _ = try propertyManager.assignPropertyNumber(for: propertyName)
            }
        }

        // Second pass: Build relationships and generate binary tables
        for object in sortedObjects {
            let compiledObject = try buildCompiledObject(object)
            compiled.append(compiledObject)
        }

        return compiled
    }

    /// Build a single compiled object with relationships resolved
    private func buildCompiledObject(_ object: ObjectData) throws -> CompiledObject {
        // Resolve parent ID
        let parentID: Int
        if let parentName = object.parentName {
            guard let parent = objects[parentName] else {
                throw ParseError.invalidSyntax(
                    "Undefined object '\(parentName)' referenced by '\(object.name)'",
                    location: object.location
                )
            }
            parentID = parent.id
        } else {
            parentID = 0
        }

        // Build sibling chain
        let siblingID = try calculateSiblingID(for: object)

        // Find first child
        let childID = try calculateChildID(for: object)

        // Generate attribute bit array
        let attributes = try generateAttributes(for: object)

        // Encode short name from DESC property
        let shortName = try encodeShortName(object)

        // Compile properties with symbolic encoding
        let properties = try compileProperties(for: object)

        return CompiledObject(
            id: object.id,
            name: object.name,
            parentID: parentID,
            siblingID: siblingID,
            childID: childID,
            attributes: attributes,
            shortName: shortName,
            properties: properties,
            location: object.location
        )
    }

    /// Calculate sibling ID for an object
    private func calculateSiblingID(for object: ObjectData) throws -> Int {
        guard let parentName = object.parentName else {
            return 0  // No parent, no sibling
        }

        // Find all children of the same parent
        let siblings = objects.values
            .filter { $0.parentName == parentName && $0.id != object.id }
            .sorted { $0.id < $1.id }

        // Find next sibling with higher ID
        if let nextSibling = siblings.first(where: { $0.id > object.id }) {
            return nextSibling.id
        }

        return 0  // No next sibling
    }

    /// Calculate first child ID for an object
    private func calculateChildID(for object: ObjectData) throws -> Int {
        // Find all children (objects whose parent is this object)
        let children = objects.values
            .filter { $0.parentName == object.name }
            .sorted { $0.id < $1.id }

        // Return first child (lowest ID)
        return children.first?.id ?? 0
    }

    /// Generate attribute bit array for an object
    private func generateAttributes(for object: ObjectData) throws -> [UInt8] {
        let attributeCount = (zMachineVersion >= 4) ? 48 : 32
        let byteCount = attributeCount / 8

        var attributes = [UInt8](repeating: 0, count: byteCount)

        for flagName in object.flags {
            guard let attrNum = flagManager.getAttributeNumber(for: flagName) else {
                throw ParseError.invalidSyntax(
                    "Undefined flag '\(flagName)' in object '\(object.name)'",
                    location: object.location
                )
            }

            // Defensive check: ensure attribute number is in valid range
            guard attrNum >= 0 && attrNum < attributeCount else {
                throw ParseError.invalidSyntax(
                    "Internal error: attribute number \(attrNum) out of range (0-\(attributeCount-1)) for flag '\(flagName)'",
                    location: object.location
                )
            }

            let byteIndex = attrNum / 8
            let bitIndex = 7 - (attrNum % 8)  // MSB first
            attributes[byteIndex] |= (1 << bitIndex)
        }

        return attributes
    }

    /// Encode object short name from DESC property
    /// Uses ZStringEncoder to create Z-encoded text with length prefix
    private func encodeShortName(_ object: ObjectData) throws -> [UInt8] {
        let descValue = object.properties["DESC"] ?? .none

        switch descValue {
        case .string(let text):
            // Use ZStringEncoder to encode the short name
            let encoder = ZStringEncoder(version: zMachineVersion)
            return encoder.encodeWithLengthPrefix(text)

        case .none:
            // Empty short name (length = 0)
            return [0]

        default:
            // DESC should be a string; if not, use empty name
            return [0]
        }
    }

    /// Compile properties for an object (creates CompiledProperty objects with symbolic encoding)
    private func compileProperties(for object: ObjectData) throws -> [CompiledProperty] {
        var compiled: [CompiledProperty] = []

        for (propName, propValue) in object.properties {
            // Skip special properties that don't go in property table
            if isSpecialProperty(propName) {
                continue
            }

            // Get assigned property number
            guard let propNum = propertyManager.getPropertyNumber(for: propName) else {
                throw ParseError.invalidSyntax(
                    "Undefined property '\(propName)' in object '\(object.name)'",
                    location: object.location
                )
            }

            // Compile the property value to symbolic encoding
            let encoding = try compilePropertyValue(propValue, propertyName: propName, object: object)

            compiled.append(CompiledProperty(
                number: propNum,
                name: propName,
                encoding: encoding
            ))
        }

        // Sort in DESCENDING order by property number (CRITICAL!)
        compiled.sort { $0.number > $1.number }

        return compiled
    }

    /// Compile a property value to its symbolic encoding
    /// Returns PropertyValueEncoding with either immediate bytes or symbolic references
    private func compilePropertyValue(
        _ value: PropertyValue,
        propertyName: String,
        object: ObjectData
    ) throws -> PropertyValueEncoding {
        switch value {
        case .integer(let val):
            // Encode as 2-byte word (big-endian)
            let high = UInt8((Int(val) >> 8) & 0xFF)
            let low = UInt8(Int(val) & 0xFF)
            return .bytes([high, low])

        case .none:
            // Zero value (2 bytes)
            return .bytes([0, 0])

        case .object(let objectName):
            // Encode object ID as bytes (version-specific)
            // v3: 1 byte, v4+: 2 bytes
            guard let referencedObject = objects[objectName] else {
                throw ParseError.invalidSyntax(
                    "Undefined object '\(objectName)' referenced in property '\(propertyName)' of object '\(object.name)'",
                    location: object.location
                )
            }

            let objectID = referencedObject.id
            if zMachineVersion <= 3 {
                // v3: 1-byte object ID
                guard objectID <= 255 else {
                    throw ParseError.invalidSyntax(
                        "Object ID \(objectID) exceeds v3 limit (255) in property '\(propertyName)' of object '\(object.name)'",
                        location: object.location
                    )
                }
                return .bytes([UInt8(objectID)])
            } else {
                // v4+: 2-byte object ID
                let high = UInt8((objectID >> 8) & 0xFF)
                let low = UInt8(objectID & 0xFF)
                return .bytes([high, low])
            }

        case .routine(let routineName):
            // Symbolic reference - assembler will resolve to packed address
            return .routineReference(routineName)

        case .string(let text):
            // Symbolic reference - assembler will resolve to packed address
            // Note: We could encode the string here, but for consistency with
            // routines and tables, we use symbolic references
            return .stringReference(text)

        case .table(let tableName):
            // Symbolic reference - assembler will resolve to packed address
            return .tableReference(tableName)

        case .atom(let atomName):
            // Atoms are context-dependent:
            // - Could be a constant (resolved to integer)
            // - Could be a routine name
            // - Could be a special value
            // For now, treat as routine reference (common case)
            // TODO: Add constant resolution system
            return .routineReference(atomName)

        case .list(let values):
            // Lists require table generation
            // For now, we'll encode the first value and ignore the rest
            // TODO: Implement proper list/table encoding
            if let firstValue = values.first {
                return try compilePropertyValue(firstValue, propertyName: propertyName, object: object)
            } else {
                return .bytes([0, 0])
            }
        }
    }

    /// Check if a property is special (doesn't go in property table)
    /// - DESC: Becomes the object short name
    /// - FLAGS: Encoded as attribute bits
    /// - IN: Determines parent/child relationships
    /// - SYNONYM/ADJECTIVE: Parser vocabulary (goes in dictionary, not property table)
    private func isSpecialProperty(_ name: String) -> Bool {
        ["FLAGS", "IN", "DESC", "SYNONYM", "ADJECTIVE"].contains(name)
    }

    // MARK: - Legacy Property Table Generation (for backwards compatibility)
    // TODO: Remove this once MemoryLayoutManager is updated to use CompiledProperty

    /// Generate property table for an object
    /// CRITICAL: Properties MUST be in DESCENDING numerical order
    private func generatePropertyTable(for object: ObjectData) throws -> [UInt8] {
        var table: [UInt8] = []

        // 1. Add object short name (text length + ZSCII text)
        let shortName = object.properties["DESC"] ?? .none
        let nameBytes = try encodeShortName(shortName)
        table.append(contentsOf: nameBytes)

        // 2. Get properties with their assigned numbers
        var propertyEntries: [(number: Int, name: String, value: PropertyValue)] = []
        for (propName, propValue) in object.properties {
            // Skip special properties that don't go in property table
            if isSpecialProperty(propName) {
                continue
            }

            guard let propNum = propertyManager.getPropertyNumber(for: propName) else {
                throw ParseError.invalidSyntax(
                    "Undefined property '\(propName)' in object '\(object.name)'",
                    location: object.location
                )
            }

            propertyEntries.append((propNum, propName, propValue))
        }

        // 3. Sort in DESCENDING order (CRITICAL!)
        propertyEntries.sort { $0.number > $1.number }

        // 4. Encode each property
        for (propNum, _, propValue) in propertyEntries {
            let propBytes = try encodeProperty(number: propNum, value: propValue)
            table.append(contentsOf: propBytes)
        }

        // 5. Add terminator (property 0)
        table.append(0)

        return table
    }

    /// Encode object short name
    /// TODO: Full ZSCII text encoding not yet implemented
    /// This is a placeholder that returns an empty short name (text length = 0)
    /// For complete implementation, needs integration with string encoding system
    private func encodeShortName(_ value: PropertyValue) throws -> [UInt8] {
        // For now, return empty name (text length = 0)
        // Full ZSCII encoding will be implemented later
        [0]  // Text length = 0 words
    }

    /// Encode a single property
    private func encodeProperty(number: Int, value: PropertyValue) throws -> [UInt8] {
        // Encode property value to bytes
        let dataBytes = try encodePropertyValue(value)
        let size = dataBytes.count

        var bytes: [UInt8] = []

        if zMachineVersion <= 3 {
            // Version 3 format: SSSS PPPP
            guard number >= 1 && number <= 31 else {
                throw ParseError.invalidSyntax(
                    "Invalid property number \(number) (must be 1-31 for version \(zMachineVersion))",
                    location: .unknown
                )
            }
            guard size >= 1 && size <= 8 else {
                throw ParseError.invalidSyntax(
                    "Property data too large: \(size) bytes (maximum 8)",
                    location: .unknown
                )
            }

            let sizeField = UInt8(size - 1)  // 0 = 1 byte, 1 = 2 bytes, etc.
            let header = (sizeField << 5) | UInt8(number)
            bytes.append(header)
        } else {
            // Version 4+ format (Z-Machine Spec Section 12.4.2)
            guard number >= 1 && number <= 63 else {
                throw ParseError.invalidSyntax(
                    "Invalid property number \(number) (must be 1-63 for version \(zMachineVersion))",
                    location: .unknown
                )
            }

            if size <= 2 {
                // Short form: 0S PPPPPP
                // Bit 7 = 0 (indicates short form)
                // Bit 6 (S) = size bit: 0 = 1 byte, 1 = 2 bytes
                // Bits 0-5 = property number (1-63)
                let sizeBit: UInt8 = (size == 2) ? 0x40 : 0x00
                let header = sizeBit | UInt8(number)
                bytes.append(header)
            } else {
                // Long form: 10 PPPPPP + size byte
                // Byte 1: Bit 7 = 1, Bit 6 = 0, Bits 0-5 = property number
                // Byte 2: Actual size in bytes (NOT size-1)
                let header = 0x80 | UInt8(number)
                bytes.append(header)
                bytes.append(UInt8(size))  // Actual size, not size-1
            }
        }

        bytes.append(contentsOf: dataBytes)
        return bytes
    }

    /// Encode a property value to bytes
    /// TODO: Only .integer and .none are fully implemented
    /// Missing implementations for:
    /// - .string: Requires packed address of ZSCII-encoded string
    /// - .routine: Requires packed address of routine code
    /// - .object: Requires object ID reference
    /// - .atom: Context-dependent encoding (constant/global/etc.)
    /// - .table: Requires address of table data
    /// - .list: Requires encoding multiple values
    private func encodePropertyValue(_ value: PropertyValue) throws -> [UInt8] {
        switch value {
        case .integer(let val):
            // 2-byte word (big-endian)
            let high = UInt8((Int(val) >> 8) & 0xFF)
            let low = UInt8(Int(val) & 0xFF)
            return [high, low]

        case .none:
            // Zero value
            return [0, 0]

        case .string, .atom, .routine, .table, .object, .list:
            // TODO: Implement full encoding for these types
            // For now, return placeholder zero value
            // These require integration with:
            // - String encoding system (for .string)
            // - Symbol resolution (for .routine, .object, .atom)
            // - Table generation (for .table)
            return [0, 0]
        }
    }

    // MARK: - Accessors

    /// Get the current flag manager state
    public func getFlagManager() -> FlagManager {
        flagManager
    }

    /// Get the current property manager state
    public func getPropertyManager() -> PropertyDefManager {
        propertyManager
    }

    /// Get object count
    public var objectCount: Int {
        objects.count
    }
}
