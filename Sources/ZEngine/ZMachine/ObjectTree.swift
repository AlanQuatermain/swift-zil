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
    ///   - dictionaryAddress: Optional absolute dictionary address to avoid reading past object table
    /// - Throws: RuntimeError for corrupted object table
    public func load(from data: Data, version: ZMachineVersion, objectTableAddress: UInt32, staticMemoryBase: UInt32, dictionaryAddress: UInt32? = nil) throws {
        print("           ObjectTree.load: data size=\(data.count), objectTableAddress=\(objectTableAddress)")
        self.version = version
        objects.removeAll()
        propertyDefaults.removeAll()

        var offset = Int(objectTableAddress)
        print("           Starting offset: \(offset)")

        // Load property default table (31 words)
        print("           Loading property defaults (need 62 bytes)...")
        for propertyNum in 1...31 {
            guard offset + 2 <= data.count else {
                print("           ❌ Property defaults truncated at property \(propertyNum), offset \(offset), data.count \(data.count)")
                throw RuntimeError.corruptedStoryFile("Property defaults table truncated", location: SourceLocation.unknown)
            }

            let value = (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
            propertyDefaults[UInt8(propertyNum)] = value
            offset += 2
        }
        print("           ✓ Property defaults loaded, new offset: \(offset)")

        // Load object entries
        var objectNumber: UInt16 = 1
        let objectSize = version.rawValue >= 4 ? 14 : 9
        print("           Loading objects (object size: \(objectSize) bytes)...")

        // Calculate the maximum offset for object loading
        let maxObjectOffset: Int
        if let dictAddr = dictionaryAddress {
            // If we know the dictionary address, don't read past it
            let dictOffset = Int(dictAddr - staticMemoryBase)
            maxObjectOffset = dictOffset
            print("           Dictionary starts at offset \(dictOffset), will stop object loading before that")
        } else {
            // Otherwise, use the full static memory size
            maxObjectOffset = data.count
            print("           No dictionary address provided, will scan to end of static memory")
        }

        // Check for end of objects more carefully - objects should immediately follow property defaults
        // If there's enough space for at least one object, check if it's all zeros (indicating end of object table)
        while offset + objectSize <= maxObjectOffset && offset + objectSize <= data.count {
            print("           Checking object \(objectNumber) at offset \(offset) (need \(objectSize) bytes, have \(data.count - offset), max offset: \(maxObjectOffset))")

            // Check if this is the end of the object table by looking for all zeros in the object slot
            var allZeroBytes = true
            for i in 0..<objectSize {
                if data[offset + i] != 0 {
                    allZeroBytes = false
                    break
                }
            }

            if allZeroBytes {
                print("           Found all-zero object slot, assuming end of object table at object \(objectNumber)")
                break
            }

            // Check if we've reached the end of objects (all zero attributes AND all zero relationships)
            let attributesStart = offset
            var hasNonZeroAttributes = false
            let attributeSize = version.rawValue >= 4 ? 6 : 4

            for i in 0..<attributeSize {
                if data[attributesStart + i] != 0 {
                    hasNonZeroAttributes = true
                    break
                }
            }

            // If no attributes and no relationships, we've likely reached the end
            if !hasNonZeroAttributes {
                var hasRelationships = false
                let relationshipStart = offset + attributeSize
                let relationshipCount = version.rawValue >= 4 ? 6 : 3

                for i in 0..<relationshipCount {
                    if data[relationshipStart + i] != 0 {
                        hasRelationships = true
                        break
                    }
                }

                if !hasRelationships {
                    print("           No attributes or relationships found, stopping at object \(objectNumber)")
                    break
                }
            }

            print("           Creating object \(objectNumber)...")
            let entry = try ObjectEntry(from: data, at: offset, objectNumber: objectNumber, version: version, staticMemoryBase: staticMemoryBase)
            objects[objectNumber] = entry
            print("           ✓ Object \(objectNumber) created")

            offset += objectSize
            objectNumber += 1

            // Sanity check: don't load more than 65535 objects
            if objectNumber > 65535 {
                break
            }
        }

        if offset >= maxObjectOffset {
            print("           Stopped object loading: reached dictionary boundary at offset \(maxObjectOffset)")
        }

        print("           ✓ Objects loaded: \(objects.count) objects")
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
    /// - Throws: RuntimeError for invalid object or attribute numbers
    public func setAttribute(_ objectNumber: UInt16, attribute: UInt8, value: Bool) throws {
        guard var object = objects[objectNumber] else {
            throw RuntimeError.invalidObjectAccess(Int(objectNumber), location: SourceLocation.unknown)
        }

        // Validate attribute number range
        let maxAttribute = version.rawValue >= 4 ? 47 : 31
        guard attribute <= maxAttribute else {
            throw RuntimeError.unsupportedOperation("Attribute \\(attribute) out of valid range 0-\\(maxAttribute) for Z-Machine version \\(version.rawValue)", location: SourceLocation.unknown)
        }

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
    /// - Throws: RuntimeError for invalid object or property numbers
    public func setProperty(_ objectNumber: UInt16, property: UInt8, value: UInt16) throws {
        guard var object = objects[objectNumber] else {
            throw RuntimeError.invalidObjectAccess(Int(objectNumber), location: SourceLocation.unknown)
        }

        // Validate property number range
        let maxProperty = version.rawValue >= 4 ? 63 : 31
        guard property > 0 && property <= maxProperty else {
            throw RuntimeError.invalidPropertyAccess(objectId: Int(objectNumber), property: Int(property), location: SourceLocation.unknown)
        }

        object.setProperty(property, value: value)
        objects[objectNumber] = object
    }

    /// Move object to new parent
    ///
    /// - Parameters:
    ///   - objectNumber: Object to move
    ///   - newParent: New parent object (0 for no parent)
    /// - Throws: RuntimeError for invalid object references
    public func moveObject(_ objectNumber: UInt16, toParent newParent: UInt16) throws {
        guard var object = objects[objectNumber] else {
            throw RuntimeError.invalidObjectAccess(Int(objectNumber), location: SourceLocation.unknown)
        }

        // Validate new parent exists if not 0
        if newParent != 0 {
            guard objects[newParent] != nil else {
                throw RuntimeError.invalidObjectAccess(Int(newParent), location: SourceLocation.unknown)
            }
        }

        // Remove from current parent
        try removeFromParent(objectNumber)

        // Set new parent
        object.parent = newParent
        objects[objectNumber] = object

        // Add to new parent's children if parent exists
        if newParent != 0 {
            guard var parentObject = objects[newParent] else {
                throw RuntimeError.invalidObjectAccess(Int(newParent), location: SourceLocation.unknown)
            }
            object.sibling = parentObject.child
            parentObject.child = objectNumber
            objects[newParent] = parentObject
            objects[objectNumber] = object
        }
    }

    private func removeFromParent(_ objectNumber: UInt16) throws {
        guard let object = objects[objectNumber], object.parent != 0 else { return }

        guard var parentObject = objects[object.parent] else {
            throw RuntimeError.invalidObjectAccess(Int(object.parent), location: SourceLocation.unknown)
        }

        if parentObject.child == objectNumber {
            // Object is first child
            parentObject.child = object.sibling
        } else {
            // Find object in sibling chain
            var siblingNumber = parentObject.child
            var foundSibling = false

            while siblingNumber != 0 {
                guard var sibling = objects[siblingNumber] else {
                    throw RuntimeError.invalidObjectAccess(Int(siblingNumber), location: SourceLocation.unknown)
                }

                if sibling.sibling == objectNumber {
                    sibling.sibling = object.sibling
                    objects[siblingNumber] = sibling
                    foundSibling = true
                    break
                }
                siblingNumber = sibling.sibling

                // Prevent infinite loops from circular references
                if siblingNumber == objectNumber {
                    throw RuntimeError.corruptedStoryFile("Circular reference detected in object tree starting from object \\(objectNumber)", location: SourceLocation.unknown)
                }
            }

            if !foundSibling {
                throw RuntimeError.corruptedStoryFile("Object \\(objectNumber) not found in parent \\(object.parent)'s child chain", location: SourceLocation.unknown)
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
        print("               ObjectEntry.init: object \(objectNumber), offset \(offset), version \(version.rawValue)")
        self.objectNumber = objectNumber
        self.version = version

        guard offset + (version.rawValue >= 4 ? 14 : 9) <= data.count else {
            throw RuntimeError.corruptedStoryFile("Object \(objectNumber) truncated", location: SourceLocation.unknown)
        }

        print("               Loading attributes...")
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
            if absolutePropertyTableAddress > 0 && absolutePropertyTableAddress >= UInt16(staticMemoryBase) {
                propertyTableAddress = absolutePropertyTableAddress - UInt16(staticMemoryBase)
            } else {
                propertyTableAddress = 0
            }
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
            if absolutePropertyTableAddress > 0 && absolutePropertyTableAddress >= UInt16(staticMemoryBase) {
                propertyTableAddress = absolutePropertyTableAddress - UInt16(staticMemoryBase)
            } else {
                propertyTableAddress = 0
            }
        }
        print("               ✓ Object data loaded - parent:\(parent), sibling:\(sibling), child:\(child), propAddr:\(propertyTableAddress)")

        print("               Loading properties...")
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
                    propertyNumber = header & 0x7F // Bottom 7 bits for property number
                    guard offset < data.count else {
                        throw RuntimeError.corruptedStoryFile("Property table truncated at size byte", location: SourceLocation.unknown)
                    }
                    let sizeField = data[offset]
                    offset += 1

                    // Validate size field to prevent excessive memory allocation
                    guard sizeField <= 64 else {
                        throw RuntimeError.corruptedStoryFile("Property size \\(sizeField) exceeds maximum of 64 bytes", location: SourceLocation.unknown)
                    }

                    // If size is 0, it means 64 bytes (special case)
                    propertySize = sizeField == 0 ? 64 : Int(sizeField)
                } else {
                    // Short format: 01LL PPPP (length-1 in bits 5-6, property# in bottom 4 bits)
                    propertyNumber = header & 0x0F // Bottom 4 bits for property number
                    let lengthField = (header >> 5) & 0x03
                    propertySize = Int(lengthField) + 1 // Length is stored as size-1

                    // Validate size for short format (max 4 bytes)
                    guard propertySize >= 1 && propertySize <= 4 else {
                        throw RuntimeError.corruptedStoryFile("Short format property size \\(propertySize) out of valid range 1-4", location: SourceLocation.unknown)
                    }
                }
            } else {
                // Version 3 property format: LLLL PPPP (size-1 in top 3 bits, property# in bottom 5 bits)
                propertyNumber = header & 0x1F // Bottom 5 bits
                let sizeField = (header >> 5) & 0x07 // Top 3 bits
                propertySize = Int(sizeField) + 1

                // Validate size for v3 format (max 8 bytes)
                guard propertySize >= 1 && propertySize <= 8 else {
                    throw RuntimeError.corruptedStoryFile("V3 property size \\(propertySize) out of valid range 1-8", location: SourceLocation.unknown)
                }
            }

            // Validate property number (1-31 for v3, 1-63 for v4+)
            let maxProperty = version.rawValue >= 4 ? 63 : 31
            guard propertyNumber > 0 && propertyNumber <= maxProperty else {
                throw RuntimeError.corruptedStoryFile("Invalid property number \\(propertyNumber) (valid range: 1-\\(maxProperty))", location: SourceLocation.unknown)
            }

            // Ensure we have enough data for the property content
            guard offset + propertySize <= data.count else {
                throw RuntimeError.corruptedStoryFile("Property data truncated: need \\(propertySize) bytes at offset \\(offset), but only \\(data.count - offset) bytes available", location: SourceLocation.unknown)
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