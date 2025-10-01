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

    /// Memory data containing the object table and properties
    private var memoryData: Data = Data()

    /// Base address of static memory for address calculations
    private var staticMemoryBase: UInt32 = 0

    public init() {}

    /// Load object tree from Z-Machine memory
    ///
    /// - Parameters:
    ///   - data: Memory data containing object table (always in dynamic memory)
    ///   - version: Z-Machine version for structure layout
    ///   - objectTableAddress: Byte offset of object table within the provided data
    ///   - staticMemoryBase: Absolute address of static memory base
    ///   - dictionaryAddress: Optional absolute dictionary address to avoid reading past object table
    /// - Throws: RuntimeError for corrupted object table
    public func load(from data: Data, version: ZMachineVersion, objectTableAddress: UInt32, staticMemoryBase: UInt32, dictionaryAddress: UInt32? = nil) throws {
        self.version = version
        self.memoryData = data
        self.staticMemoryBase = staticMemoryBase
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

        // Determine object table size based on Object 1's property table address
        // This works for all versions - the property tables start where Object 1's property table is

        // First, we need to read Object 1 to get its property table address
        guard offset + objectSize <= data.count else {
            throw RuntimeError.corruptedStoryFile("Object table truncated", location: SourceLocation.unknown)
        }

        // Read Object 1's property table address (last 2 bytes of object entry)
        let object1PropertyTableOffset = offset + objectSize - 2
        let object1PropertyTable = (UInt32(data[object1PropertyTableOffset]) << 8) | UInt32(data[object1PropertyTableOffset + 1])
        let propertyTablesStart = Int(object1PropertyTable)

        // Calculate how many objects can fit before property tables start
        let availableBytes = propertyTablesStart - offset
        let maxObjects = availableBytes / objectSize

        // Load objects with validation
        while objectNumber <= maxObjects && offset + objectSize <= data.count && offset < propertyTablesStart {
            // For V1-V3, check if object slot is all zeros (unused object)
            if version.rawValue <= 3 {
                var allZeroBytes = true
                for i in 0..<objectSize {
                    if data[offset + i] != 0 {
                        allZeroBytes = false
                        break
                    }
                }

                if allZeroBytes {
                    // Skip unused object slot
                    offset += objectSize
                    objectNumber += 1
                    continue
                }
            }

            // Extract parent/child/sibling for validation
            let parent: UInt16
            let child: UInt16
            let sibling: UInt16
            let propertyTableAddr: UInt16

            if version.rawValue >= 4 {
                parent = (UInt16(data[offset + 6]) << 8) | UInt16(data[offset + 7])
                sibling = (UInt16(data[offset + 8]) << 8) | UInt16(data[offset + 9])
                child = (UInt16(data[offset + 10]) << 8) | UInt16(data[offset + 11])
                propertyTableAddr = (UInt16(data[offset + 12]) << 8) | UInt16(data[offset + 13])
            } else {
                parent = UInt16(data[offset + 4])
                sibling = UInt16(data[offset + 5])
                child = UInt16(data[offset + 6])
                propertyTableAddr = (UInt16(data[offset + 7]) << 8) | UInt16(data[offset + 8])
            }

            // Validate parent/child/sibling are within valid object range
            let maxValidObject = UInt16(maxObjects)
            if (parent != 0 && parent > maxValidObject) ||
               (child != 0 && child > maxValidObject) ||
               (sibling != 0 && sibling > maxValidObject) {
                break
            }

            // Validate property table address is reasonable
            if propertyTableAddr != 0 && (propertyTableAddr < propertyTablesStart || propertyTableAddr >= staticMemoryBase) {
                break
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
        guard let object = objects[objectNumber] else {
            return false
        }

        let result = object.hasAttribute(attribute)
        return result
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
            throw RuntimeError.unsupportedOperation("Attribute \(attribute) out of valid range 0-\(maxAttribute) for Z-Machine version \(version.rawValue)", location: SourceLocation.unknown)
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

        let result = object.getProperty(property) ?? propertyDefaults[property] ?? 0
        return result
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

    /// Get all properties for an object
    ///
    /// - Parameter objectNumber: Object number
    /// - Returns: Dictionary of property number to property value
    public func getAllProperties(_ objectNumber: UInt16) -> [UInt8: UInt16] {
        guard let object = objects[objectNumber] else { return [:] }
        return object.getAllProperties()
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

    /// Get the address of a property's data (not the size byte)
    ///
    /// - Parameters:
    ///   - objectNumber: Object number
    ///   - property: Property number (1-63)
    /// - Returns: Address of property data, or 0 if property doesn't exist
    public func getPropertyAddress(_ objectNumber: UInt16, property: UInt8) -> UInt16 {
        guard let object = objects[objectNumber] else {
            return 0
        }
        guard property > 0 else { return 0 }

        let tableAddress = Int(object.propertyTableAddress)
        guard tableAddress < memoryData.count else {
            return 0
        }

        let result = findPropertyAddress(property: property, tableAddress: tableAddress, objectNumber: objectNumber) ?? 0
        return result
    }

    /// Get the length of a property at a given address
    ///
    /// - Parameter address: Address pointing to property data
    /// - Returns: Length of property in bytes, or 0 if address is invalid
    public func getPropertyLength(at address: UInt16) -> UInt8 {
        guard address > 0 else { return 0 }

        // Find the size byte(s) that precede this address
        // We need to find which object this property belongs to and walk back to the size byte
        return calculatePropertyLengthAtAddress(address)
    }

    /// Get the next property number after the given property
    ///
    /// - Parameters:
    ///   - objectNumber: Object number
    ///   - currentProperty: Current property number (0 to get first property)
    /// - Returns: Next property number, or 0 if at end
    public func getNextProperty(_ objectNumber: UInt16, after currentProperty: UInt8) -> UInt8 {
        guard let object = objects[objectNumber] else { return 0 }

        let tableAddress = Int(object.propertyTableAddress)
        guard tableAddress < memoryData.count else { return 0 }

        return findNextProperty(tableAddress: tableAddress, after: currentProperty)
    }

    // MARK: - Private Helper Methods

    private func findPropertyAddress(property: UInt8, tableAddress: Int, objectNumber: UInt16) -> UInt16? {
        var offset = tableAddress

        // Skip object short name (text length byte + encoded text)
        guard offset < memoryData.count else { return nil }
        let textLength = memoryData[offset]
        offset += 1 + Int(textLength) * 2 // Skip length byte + text words (2 bytes each)

        // Walk through properties to find the one we want
        while offset < memoryData.count {
            let header = memoryData[offset]

            // Check for end marker
            if header == 0 {
                break
            }

            let (propertyNumber, propertySize, headerSize) = decodePropertyHeader(header, offset: offset)

            if propertyNumber == property {
                // Return address of property data (skip header bytes)
                let result = UInt16(offset + headerSize)
                return result
            }

            // Move to next property
            offset += headerSize + propertySize
        }

        return nil
    }

    private func calculatePropertyLengthAtAddress(_ address: UInt16) -> UInt8 {
        // This is complex - we need to find the size byte(s) that precede this address
        // For now, we'll search through all objects to find which property this address belongs to

        for object in objects.values {
            let tableAddress = Int(object.propertyTableAddress)
            guard tableAddress < memoryData.count else { continue }

            var offset = tableAddress

            // Skip object short name
            guard offset < memoryData.count else { continue }
            let textLength = memoryData[offset]
            offset += 1 + Int(textLength) * 2

            // Walk through properties
            while offset < memoryData.count {
                let header = memoryData[offset]

                // Check for end marker
                if header == 0 { break }

                let (_, propertySize, headerSize) = decodePropertyHeader(header, offset: offset)
                let dataAddress = offset + headerSize

                if UInt16(dataAddress) == address {
                    return UInt8(propertySize)
                }

                offset += headerSize + propertySize
            }
        }

        return 0
    }

    private func findNextProperty(tableAddress: Int, after currentProperty: UInt8) -> UInt8 {
        var offset = tableAddress

        // Skip object short name
        guard offset < memoryData.count else { return 0 }
        let textLength = memoryData[offset]
        offset += 1 + Int(textLength) * 2

        var foundCurrent = currentProperty == 0 // If 0, we want the first property

        // Walk through properties (they are in descending order)
        while offset < memoryData.count {
            let header = memoryData[offset]

            // Check for end marker
            if header == 0 { break }

            let (propertyNumber, propertySize, headerSize) = decodePropertyHeader(header, offset: offset)

            if foundCurrent {
                return propertyNumber
            }

            if propertyNumber == currentProperty {
                foundCurrent = true
            }

            offset += headerSize + propertySize
        }

        return 0
    }

    private func decodePropertyHeader(_ header: UInt8, offset: Int) -> (propertyNumber: UInt8, propertySize: Int, headerSize: Int) {
        if version.rawValue >= 4 {
            // Version 4+ property format
            if (header & 0x80) != 0 {
                // Long format: TWO header bytes
                let propertyNumber = header & 0x3F

                guard offset + 1 < memoryData.count else {
                    return (propertyNumber, 1, 2) // Fallback
                }
                let lengthByte = memoryData[offset + 1]
                let sizeField = lengthByte & 0x3F
                let propertySize = sizeField == 0 ? 64 : Int(sizeField)

                return (propertyNumber, propertySize, 2)
            } else {
                // Short format: ONE header byte
                let propertyNumber = header & 0x3F
                let lengthFlag = (header & 0x40) != 0
                let propertySize = lengthFlag ? 2 : 1

                return (propertyNumber, propertySize, 1)
            }
        } else {
            // Version 3 property format: LLLL PPPP
            let propertyNumber = header & 0x1F
            let sizeField = (header >> 5) & 0x07
            let propertySize = Int(sizeField) + 1

            return (propertyNumber, propertySize, 1)
        }
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

            // Load relationships (2 bytes each) - Safe big-endian word reading
            parent = UInt16(data[offset + 6]) << 8 | UInt16(data[offset + 7])
            sibling = UInt16(data[offset + 8]) << 8 | UInt16(data[offset + 9])
            child = UInt16(data[offset + 10]) << 8 | UInt16(data[offset + 11])
            let propertyTableAddress = UInt16(data[offset + 12]) << 8 | UInt16(data[offset + 13])
            // Property table addresses are already absolute (object table is in dynamic memory)
            self.propertyTableAddress = propertyTableAddress
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
            let propertyTableAddress = UInt16(data[offset + 7]) << 8 | UInt16(data[offset + 8])
            // Property table addresses are already absolute (object table is in dynamic memory)
            self.propertyTableAddress = propertyTableAddress
        }

        if propertyTableAddress > 0 && Int(propertyTableAddress) < data.count {
            try loadPropertiesFromTable(data: data)

            // Debug: Check object short name during loading (commented out to reduce output)
            if ZILLogger.vm.logLevel <= .debug {
                let tableAddress = Int(propertyTableAddress)
                if tableAddress < data.count {
                    let textLength = data[tableAddress]
                    ZILLogger.vm.debug("Object \(objectNumber) - text length: \(textLength) words, property table at offset 0x\(String(propertyTableAddress, radix: 16, uppercase: true))")

                    if textLength > 0 {
                        ZILLogger.vm.debug("Object \(objectNumber) HAS short description (\(textLength) words)")

                        // Show raw bytes at property table address
                        ZILLogger.vm.debug("Raw bytes at property table (offset 0x\(String(propertyTableAddress, radix: 16))):")
                        for i in 0..<min(12, data.count - tableAddress) {
                            let byte = data[tableAddress + i]
                            let charRep = (byte >= 32 && byte <= 126) ? " '\(Character(UnicodeScalar(byte)))'" : ""
                            ZILLogger.vm.debug("  +\(i): 0x\(String(byte, radix: 16, uppercase: true)) (\(byte))\(charRep)")
                        }

                        // Address stored for later decoding by ZMachine
                        ZILLogger.vm.debug("Object \(objectNumber) short name at address 0x\(String(UInt32(tableAddress + 1), radix: 16, uppercase: true))")
                    } else {
                        ZILLogger.vm.debug("Object \(objectNumber) has NO short description (empty)")
                    }
                }
            }
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

        guard tableAddress < data.count else {
            throw RuntimeError.corruptedStoryFile("Property table address out of bounds", location: SourceLocation.unknown)
        }

        var offset = tableAddress

        // Skip object short name (text length byte + encoded text)
        guard offset < data.count else {
            throw RuntimeError.corruptedStoryFile("Property table truncated at name length", location: SourceLocation.unknown)
        }
        let textLength = data[offset]
        offset += 1 + Int(textLength) * 2 // Skip length byte + text words (2 bytes each)

        // Track property order for validation (must be descending)
        var lastPropertyNumber: UInt8 = version.rawValue >= 4 ? 64 : 32

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
                    // Long format: TWO header bytes
                    // byte1: b0..b5 = property_number (1..63); b7 = 1
                    // byte2: b0..b5 = length in bytes (1..64; treat 0 as 64); b7 = 1
                    propertyNumber = header & 0x3F // Property number from first byte (bits 5-0)

                    guard offset < data.count else {
                        throw RuntimeError.corruptedStoryFile("Property table truncated at length byte", location: SourceLocation.unknown)
                    }
                    let lengthByte = data[offset] // Second byte is length
                    offset += 1

                    let sizeField = lengthByte & 0x3F // Bottom 6 bits for size
                    propertySize = sizeField == 0 ? 64 : Int(sizeField) // Size 0 means 64 bytes

                    // Validate size for long format (1-64 bytes)
                    guard propertySize >= 1 && propertySize <= 64 else {
                        throw RuntimeError.corruptedStoryFile("Long format property size \(propertySize) out of valid range 1-64", location: SourceLocation.unknown)
                    }
                } else {
                    // Short format: ONE header byte
                    // b0..b5 = property_number (1..63)
                    // b6 = length flag (0 ⇒ len=1, 1 ⇒ len=2)
                    // b7 = 0
                    propertyNumber = header & 0x3F // Bottom 6 bits for property number (1-63)
                    let lengthFlag = (header & 0x40) != 0 // Bit 6 for length flag
                    propertySize = lengthFlag ? 2 : 1 // 0 ⇒ len=1, 1 ⇒ len=2

                    // Validate size for short format (1-2 bytes)
                    guard propertySize >= 1 && propertySize <= 2 else {
                        throw RuntimeError.corruptedStoryFile("Short format property size \(propertySize) out of valid range 1-2", location: SourceLocation.unknown)
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

            // Validate property order (must be descending)
            guard propertyNumber < lastPropertyNumber else {
                throw RuntimeError.corruptedStoryFile("Properties not in descending order: found property \(propertyNumber) after \(lastPropertyNumber)", location: SourceLocation.unknown)
            }
            lastPropertyNumber = propertyNumber

            // Validate property number based on format for V4+
            if version.rawValue >= 4 {
                let maxProperty: UInt8 = (header & 0x80) != 0 ? 63 : 15 // Long format: 6 bits, Short format: 4 bits
                guard propertyNumber > 0 && propertyNumber <= maxProperty else {
                    throw RuntimeError.corruptedStoryFile("Invalid V4+ property number \(propertyNumber) for format (valid range: 1-\(maxProperty))", location: SourceLocation.unknown)
                }
            } else {
                // V3 property number validation
                guard propertyNumber > 0 && propertyNumber <= 31 else {
                    throw RuntimeError.corruptedStoryFile("Invalid V3 property number \(propertyNumber) (valid range: 1-31)", location: SourceLocation.unknown)
                }
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
                propertyValue = UInt16(propertyData[0]) << 8 | UInt16(propertyData[1])
            default:
                // For larger properties, store the first two bytes as the value
                // (Full property data handling would require more complex storage)
                if propertySize >= 2 {
                    propertyValue = UInt16(propertyData[0]) << 8 | UInt16(propertyData[1])
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

        // Z-Machine uses word-based bit ordering with big-endian word layout:
        // Word 0 (attributes 0-15) is at higher address positions in the UInt64
        // Word 1 (attributes 16-31) is at lower address positions in the UInt64
        // Word 2 (attributes 32-47) is at lowest address positions in the UInt64
        let wordIndex = Int(attribute / 16)
        let attributeInWord = attribute % 16
        let bitInWord = 15 - Int(attributeInWord)  // MSB-first within each word

        // For big-endian word layout: word 0 goes in high bits, word 1 in middle, word 2 in low
        let bitPosition: Int
        if version.rawValue >= 4 {
            // v4+: 3 words (48 bits), need to map to high 48 bits of UInt64
            bitPosition = (47 - (wordIndex * 16 + (15 - bitInWord)))
        } else {
            // v3: 2 words (32 bits), need to map to high 32 bits of UInt64
            bitPosition = (31 - (wordIndex * 16 + (15 - bitInWord)))
        }

        guard bitPosition >= 0 && bitPosition < 64 else { return false }
        return (attributes & (UInt64(1) << bitPosition)) != 0
    }

    /// Set or clear object attribute
    ///
    /// - Parameters:
    ///   - attribute: Attribute number
    ///   - value: True to set, false to clear
    public mutating func setAttribute(_ attribute: UInt8, value: Bool) {
        let maxAttribute = version.rawValue >= 4 ? 47 : 31
        guard attribute <= maxAttribute else { return }

        // Z-Machine uses word-based bit ordering with big-endian word layout:
        // Word 0 (attributes 0-15) is at higher address positions in the UInt64
        // Word 1 (attributes 16-31) is at lower address positions in the UInt64
        // Word 2 (attributes 32-47) is at lowest address positions in the UInt64
        let wordIndex = Int(attribute / 16)
        let attributeInWord = attribute % 16
        let bitInWord = 15 - Int(attributeInWord)  // MSB-first within each word

        // For big-endian word layout: word 0 goes in high bits, word 1 in middle, word 2 in low
        let bitPosition: Int
        if version.rawValue >= 4 {
            // v4+: 3 words (48 bits), need to map to high 48 bits of UInt64
            bitPosition = (47 - (wordIndex * 16 + (15 - bitInWord)))
        } else {
            // v3: 2 words (32 bits), need to map to high 32 bits of UInt64
            bitPosition = (31 - (wordIndex * 16 + (15 - bitInWord)))
        }

        guard bitPosition >= 0 && bitPosition < 64 else { return }

        if value {
            attributes |= (UInt64(1) << bitPosition)
        } else {
            attributes &= ~(UInt64(1) << bitPosition)
        }
    }

    /// Get property value
    ///
    /// - Parameter property: Property number
    /// - Returns: Property value or nil if not found
    public func getProperty(_ property: UInt8) -> UInt16? {
        return properties[property]
    }

    /// Get all properties for this object
    ///
    /// - Returns: Dictionary of property number to property value
    public func getAllProperties() -> [UInt8: UInt16] {
        return properties
    }

    /// Get the property table address (absolute address)
    ///
    /// - Returns: Absolute property table address
    public func getPropertyTableAddress() -> UInt16 {
        return propertyTableAddress
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
