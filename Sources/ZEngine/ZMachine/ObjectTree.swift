/// Z-Machine Object Tree - Manages the hierarchical object system
import Foundation

/// Manages the Z-Machine object tree and property system
///
/// The object tree represents the game world's object hierarchy,
/// including rooms, items, and their relationships. Each object
/// has attributes (flags), properties, and parent/child/sibling
/// relationships that form a tree structure.
public class ObjectTree {

    /// Object entries indexed by object number
    private var objects: [UInt16: ObjectEntry] = [:]

    /// Property default values (properties 1-31)
    private var propertyDefaults: [UInt8: UInt16] = [:]

    /// Version-specific object structure
    private var version: ZMachineVersion = .v3

    public init() {}

    /// Load object tree from Z-Machine memory
    ///
    /// - Parameters:
    ///   - data: Static memory data containing object table
    ///   - version: Z-Machine version for structure layout
    ///   - objectTableAddress: Byte offset of object table within the provided data (not absolute story file address)
    ///   - staticMemoryBase: Absolute address of static memory base (for converting property table addresses)
    /// - Throws: RuntimeError for corrupted object table
    public func load(from data: Data, version: ZMachineVersion, objectTableAddress: UInt32, staticMemoryBase: UInt32) throws {
        self.version = version
        objects.removeAll()
        propertyDefaults.removeAll()

        var offset = Int(objectTableAddress)

        // Load property default table (31 words)
        for propertyNum in 1...31 {
            guard offset + 2 <= data.count else {
                throw RuntimeError.corruptedStoryFile("Property defaults table truncated", location: SourceLocation.unknown)
            }

            let value = (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
            propertyDefaults[UInt8(propertyNum)] = value
            offset += 2
        }

        // Load object entries
        var objectNumber: UInt16 = 1
        let objectSize = version.rawValue >= 4 ? 14 : 9

        while offset + objectSize <= data.count {
            // Check if we've reached the end of objects (all zero attributes)
            let attributesStart = offset
            var hasNonZeroAttributes = false
            for i in 0..<4 {
                if data[attributesStart + i] != 0 {
                    hasNonZeroAttributes = true
                    break
                }
            }

            // If no attributes and no relationships, we've likely reached the end
            if !hasNonZeroAttributes {
                var hasRelationships = false
                let relationshipStart = offset + 4
                let relationshipCount = version.rawValue >= 4 ? 6 : 3

                for i in 0..<relationshipCount {
                    if data[relationshipStart + i] != 0 {
                        hasRelationships = true
                        break
                    }
                }

                if !hasRelationships {
                    break
                }
            }

            let entry = try ObjectEntry(from: data, at: offset, objectNumber: objectNumber, version: version, staticMemoryBase: staticMemoryBase)
            objects[objectNumber] = entry

            offset += objectSize
            objectNumber += 1

            // Sanity check: don't load more than 65535 objects
            if objectNumber > 65535 {
                break
            }
        }
    }

    /// Get an object by number
    ///
    /// - Parameter objectNumber: Object number (1-based)
    /// - Returns: Object entry or nil if not found
    public func getObject(_ objectNumber: UInt16) -> ObjectEntry? {
        return objects[objectNumber]
    }

    /// Get object attribute (flag)
    ///
    /// - Parameters:
    ///   - objectNumber: Object number
    ///   - attribute: Attribute number (0-31 for v3, 0-47 for v4+)
    /// - Returns: True if attribute is set
    public func getAttribute(_ objectNumber: UInt16, attribute: UInt8) -> Bool {
        guard let object = objects[objectNumber] else { return false }
        return object.hasAttribute(attribute)
    }

    /// Set object attribute (flag)
    ///
    /// - Parameters:
    ///   - objectNumber: Object number
    ///   - attribute: Attribute number
    ///   - value: True to set, false to clear
    public func setAttribute(_ objectNumber: UInt16, attribute: UInt8, value: Bool) {
        guard var object = objects[objectNumber] else { return }
        object.setAttribute(attribute, value: value)
        objects[objectNumber] = object
    }

    /// Get object property value
    ///
    /// - Parameters:
    ///   - objectNumber: Object number
    ///   - property: Property number (1-31)
    /// - Returns: Property value or default if not found
    public func getProperty(_ objectNumber: UInt16, property: UInt8) -> UInt16 {
        guard let object = objects[objectNumber] else {
            return propertyDefaults[property] ?? 0
        }

        return object.getProperty(property) ?? propertyDefaults[property] ?? 0
    }

    /// Set object property value
    ///
    /// - Parameters:
    ///   - objectNumber: Object number
    ///   - property: Property number
    ///   - value: New property value
    public func setProperty(_ objectNumber: UInt16, property: UInt8, value: UInt16) {
        guard var object = objects[objectNumber] else { return }
        object.setProperty(property, value: value)
        objects[objectNumber] = object
    }

    /// Move object to new parent
    ///
    /// - Parameters:
    ///   - objectNumber: Object to move
    ///   - newParent: New parent object (0 for no parent)
    public func moveObject(_ objectNumber: UInt16, toParent newParent: UInt16) {
        guard var object = objects[objectNumber] else { return }

        // Remove from current parent
        removeFromParent(objectNumber)

        // Set new parent
        object.parent = newParent
        objects[objectNumber] = object

        // Add to new parent's children if parent exists
        if newParent != 0, var parentObject = objects[newParent] {
            object.sibling = parentObject.child
            parentObject.child = objectNumber
            objects[newParent] = parentObject
            objects[objectNumber] = object
        }
    }

    private func removeFromParent(_ objectNumber: UInt16) {
        guard let object = objects[objectNumber], object.parent != 0 else { return }

        var parentObject = objects[object.parent]!

        if parentObject.child == objectNumber {
            // Object is first child
            parentObject.child = object.sibling
        } else {
            // Find object in sibling chain
            var siblingNumber = parentObject.child
            while siblingNumber != 0 {
                var sibling = objects[siblingNumber]!
                if sibling.sibling == objectNumber {
                    sibling.sibling = object.sibling
                    objects[siblingNumber] = sibling
                    break
                }
                siblingNumber = sibling.sibling
            }
        }

        objects[object.parent] = parentObject

        // Clear object's parent and sibling
        var updatedObject = object
        updatedObject.parent = 0
        updatedObject.sibling = 0
        objects[objectNumber] = updatedObject
    }
}

/// Individual object entry in the object tree
public struct ObjectEntry {
    public let objectNumber: UInt16
    public var attributes: UInt64 // Attribute flags (32 bits for v3, 48 bits for v4+)
    public var parent: UInt16
    public var sibling: UInt16
    public var child: UInt16
    public var propertyTableAddress: UInt16
    private var properties: [UInt8: UInt16] = [:]
    private let version: ZMachineVersion

    public init(from data: Data, at offset: Int, objectNumber: UInt16, version: ZMachineVersion, staticMemoryBase: UInt32) throws {
        self.objectNumber = objectNumber
        self.version = version

        guard offset + (version.rawValue >= 4 ? 14 : 9) <= data.count else {
            throw RuntimeError.corruptedStoryFile("Object \(objectNumber) truncated", location: SourceLocation.unknown)
        }

        // Load attributes (4 bytes for v3, 6 bytes for v4+)
        if version.rawValue >= 4 {
            // 48-bit attributes for v4+
            attributes = 0
            for i in 0..<6 {
                attributes = (attributes << 8) | UInt64(data[offset + i])
            }

            // Load relationships (2 bytes each)
            parent = (UInt16(data[offset + 6]) << 8) | UInt16(data[offset + 7])
            sibling = (UInt16(data[offset + 8]) << 8) | UInt16(data[offset + 9])
            child = (UInt16(data[offset + 10]) << 8) | UInt16(data[offset + 11])
            let absolutePropertyTableAddress = (UInt16(data[offset + 12]) << 8) | UInt16(data[offset + 13])
            // Convert absolute address to relative offset within static memory
            propertyTableAddress = absolutePropertyTableAddress > 0 ? UInt16(absolutePropertyTableAddress - UInt16(staticMemoryBase)) : 0
        } else {
            // 32-bit attributes for v3
            attributes = 0
            for i in 0..<4 {
                attributes = (attributes << 8) | UInt64(data[offset + i])
            }

            // Load relationships (1 byte each for v3)
            parent = UInt16(data[offset + 4])
            sibling = UInt16(data[offset + 5])
            child = UInt16(data[offset + 6])
            let absolutePropertyTableAddress = (UInt16(data[offset + 7]) << 8) | UInt16(data[offset + 8])
            // Convert absolute address to relative offset within static memory
            propertyTableAddress = absolutePropertyTableAddress > 0 ? UInt16(absolutePropertyTableAddress - UInt16(staticMemoryBase)) : 0
        }

        // Load properties from property table if it exists
        if propertyTableAddress > 0 {
            try loadPropertiesFromTable(data: data)
        }
    }

    /// Load properties from the object's property table
    ///
    /// Implements Z-Machine property table parsing according to the specification.
    /// Property tables contain a short name followed by property entries in descending order.
    ///
    /// - Parameter data: The static memory data containing the property table
    /// - Throws: RuntimeError for corrupted property table
    private mutating func loadPropertiesFromTable(data: Data) throws {
        let tableAddress = Int(propertyTableAddress)

        // Debug output
        print("DEBUG: Loading properties for object \(objectNumber)")
        print("       Property table address: \(propertyTableAddress)")
        print("       Static memory data size: \(data.count)")
        print("       Table address as int: \(tableAddress)")

        guard tableAddress < data.count else {
            print("ERROR: Property table address \(tableAddress) >= data size \(data.count)")
            throw RuntimeError.corruptedStoryFile("Property table address out of bounds", location: SourceLocation.unknown)
        }

        var offset = tableAddress

        // Skip object short name (text length byte + encoded text)
        guard offset < data.count else {
            throw RuntimeError.corruptedStoryFile("Property table truncated at name length", location: SourceLocation.unknown)
        }
        let textLength = data[offset]
        offset += 1 + Int(textLength) * 2 // Skip length byte + text words (2 bytes each)

        // Parse property entries until we hit the end marker (property number 0)
        while offset < data.count {
            let header = data[offset]
            offset += 1

            // Check for end marker
            if header == 0 { break }

            let propertyNumber: UInt8
            let propertySize: Int

            if version.rawValue >= 4 {
                // Version 4+ property format
                if (header & 0x80) != 0 {
                    // Long format: 1PPP PPPP followed by LLLL LLLL (size byte)
                    propertyNumber = header & 0x3F // Bottom 6 bits (not 7 as incorrectly implemented before)
                    guard offset < data.count else {
                        throw RuntimeError.corruptedStoryFile("Property table truncated at size byte", location: SourceLocation.unknown)
                    }
                    let sizeField = data[offset]
                    offset += 1

                    // If size is 0, it means 64 bytes (special case)
                    propertySize = sizeField == 0 ? 64 : Int(sizeField)
                } else {
                    // Short format: 01LL PPPP (length-1 in bits 5-6, property# in bottom 4 bits)
                    propertyNumber = header & 0x1F // Bottom 5 bits
                    propertySize = Int((header >> 5) & 0x03) + 1 // Bits 5-6, then add 1
                }
            } else {
                // Version 3 property format: LLLL PPPP (size-1 in top 3 bits, property# in bottom 5 bits)
                propertyNumber = header & 0x1F // Bottom 5 bits
                let sizeField = (header >> 5) & 0x07 // Top 3 bits
                propertySize = Int(sizeField) + 1
            }

            // Validate property number (1-31 for v3, 1-63 for v4+)
            let maxProperty = version.rawValue >= 4 ? 63 : 31
            guard propertyNumber > 0 && propertyNumber <= maxProperty else {
                throw RuntimeError.corruptedStoryFile("Invalid property number \(propertyNumber)", location: SourceLocation.unknown)
            }

            // Read property data
            guard offset + propertySize <= data.count else {
                throw RuntimeError.corruptedStoryFile("Property data truncated", location: SourceLocation.unknown)
            }
            let propertyData = data.subdata(in: offset..<offset + propertySize)

            // Convert property data to UInt16 value (Z-Machine properties are typically 1-2 bytes)
            let propertyValue: UInt16
            switch propertySize {
            case 1:
                propertyValue = UInt16(propertyData[0])
            case 2:
                propertyValue = (UInt16(propertyData[0]) << 8) | UInt16(propertyData[1])
            default:
                // For larger properties, store the first two bytes as the value
                // (Full property data handling would require more complex storage)
                if propertySize >= 2 {
                    propertyValue = (UInt16(propertyData[0]) << 8) | UInt16(propertyData[1])
                } else {
                    propertyValue = 0
                }
            }

            properties[propertyNumber] = propertyValue
            offset += propertySize
        }
    }

    /// Check if object has specific attribute set
    ///
    /// - Parameter attribute: Attribute number (0-31 for v3, 0-47 for v4+)
    /// - Returns: True if attribute is set
    public func hasAttribute(_ attribute: UInt8) -> Bool {
        let maxAttribute = version.rawValue >= 4 ? 47 : 31
        guard attribute <= maxAttribute else { return false }

        let bitPosition = UInt64(attribute)
        return (attributes & (1 << bitPosition)) != 0
    }

    /// Set or clear object attribute
    ///
    /// - Parameters:
    ///   - attribute: Attribute number
    ///   - value: True to set, false to clear
    public mutating func setAttribute(_ attribute: UInt8, value: Bool) {
        let maxAttribute = version.rawValue >= 4 ? 47 : 31
        guard attribute <= maxAttribute else { return }

        let bitPosition = UInt64(attribute)
        if value {
            attributes |= (1 << bitPosition)
        } else {
            attributes &= ~(1 << bitPosition)
        }
    }

    /// Get property value
    ///
    /// - Parameter property: Property number
    /// - Returns: Property value or nil if not found
    public func getProperty(_ property: UInt8) -> UInt16? {
        return properties[property]
    }

    /// Set property value
    ///
    /// - Parameters:
    ///   - property: Property number
    ///   - value: New value
    public mutating func setProperty(_ property: UInt8, value: UInt16) {
        properties[property] = value
    }
}