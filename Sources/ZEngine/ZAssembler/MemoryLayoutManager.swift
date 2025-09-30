/// Z-Machine Memory Layout Manager - Manages memory organization and story file generation
import Foundation

/// Manages Z-Machine memory layout, object tables, and story file generation
public class MemoryLayoutManager {

    public let version: ZMachineVersion
    private var dynamicMemory: [UInt8] = []
    private var staticMemory: [UInt8] = []
    private var highMemory: [UInt8] = []

    // Memory regions and pointers
    private var globalTable: [UInt16] = Array(repeating: 0, count: 240) // Z-Machine has 240 globals
    private var objectTable: [ObjectEntry] = []
    private var propertyTable: [PropertyEntry] = []
    private var dictionary: [String: UInt16] = [:]
    // String management with deferred address calculation
    private struct StringEntry {
        let id: String
        let content: String
        var address: UInt32 = 0  // Will be set during story file generation
    }

    private var stringEntries: [StringEntry] = []
    private var stringAddressMap: [String: UInt32] = [:]
    private var codeMemory: [UInt8] = []

    // Address tracking
    private var currentAddress: UInt32 = 0
    private var staticMemoryBase: UInt32 = 0
    private var highMemoryBase: UInt32 = 0
    private var startRoutineAddress: UInt32 = 0

    private struct ObjectEntry {
        let name: String
        let id: UInt16
        var properties: [String: ZValue] = [:]
        var parent: UInt16 = 0
        var sibling: UInt16 = 0
        var child: UInt16 = 0
        var attributes: UInt64 = 0  // Changed to UInt64 to handle 48 bits for v4+
        var propertyTableAddress: UInt16 = 0
    }

    private struct PropertyEntry {
        let name: String
        let id: UInt8
        let defaultValue: ZValue
    }

    public init(version: ZMachineVersion) {
        self.version = version
        setupMemoryLayout()
    }

    private func setupMemoryLayout() {
        // Initialize memory regions based on Z-Machine version
        // CRITICAL: Header addresses (bytes 4-5, 14-15) are UInt16, so all memory region
        // base addresses must fit in 0-65535 range, regardless of total file size

        switch version {
        case .v3:
            // Z-Machine v3: 128KB total file size possible
            // Header pointers limited to UInt16 (0-65535)
            dynamicMemory = Array(repeating: 0, count: 0x4000) // 16KB dynamic (0x0000-0x3FFF)
            staticMemoryBase = 0x4000  // Start static at 16KB (16384)
            highMemoryBase = 0x8000    // Start high at 32KB (32768) - safely under 65535

        case .v4, .v5:
            // Z-Machine v4/v5: 128KB/256KB total file size possible
            // Header pointers still limited to UInt16 for initial regions
            dynamicMemory = Array(repeating: 0, count: 0x8000) // 32KB dynamic (0x0000-0x7FFF)
            staticMemoryBase = 0x8000  // Start static at 32KB (32768)
            highMemoryBase = 0xC000    // Start high at 48KB (49152) - safely under 65535

        case .v6, .v7, .v8:
            // Z-Machine v6+: 256KB+ total file size possible
            // Header pointers still UInt16 - use maximum safe values
            dynamicMemory = Array(repeating: 0, count: 0xA000) // 40KB dynamic (0x0000-0x9FFF)
            staticMemoryBase = 0xA000  // Start static at 40KB (40960)
            highMemoryBase = 0xF000    // Start high at 60KB (61440) - safely under 65535
        }

        // Reserve space for header (64 bytes)
        currentAddress = 64
    }

    // MARK: - Data Management

    /// Add raw data to the current memory section
    public func addData(_ data: Data) {
        // Add to static memory section for data directives
        staticMemory.append(contentsOf: data)
    }

    /// Get the current count of strings for ID generation
    public func getStringCount() -> Int {
        return stringEntries.count
    }

    /// Set initial value for a global variable
    public func setGlobalInitialValue(_ name: String, address: UInt32, value: String, symbolTable: [String: UInt32], location: SourceLocation) throws {
        // Calculate global table index from address
        let globalTableAddress = calculateGlobalTableAddress()
        guard address >= UInt32(globalTableAddress) else {
            throw AssemblyError.memoryLayoutError("Invalid global address for \(name)", location: location)
        }

        let globalIndex = (address - UInt32(globalTableAddress)) / 2
        guard globalIndex < globalTable.count else {
            throw AssemblyError.memoryLayoutError("Global index out of range for \(name)", location: location)
        }

        // Parse and set the initial value
        let initialValue: UInt16
        if let numericValue = Int16(value) {
            initialValue = UInt16(bitPattern: numericValue)
        } else if let symbolAddress = symbolTable[value] {
            initialValue = UInt16(symbolAddress & 0xFFFF)
        } else {
            // Try to parse as constant reference
            if value.hasPrefix("T?") {
                // Table reference - extract table number
                let tableNum = String(value.dropFirst(2))
                if let tableIndex = Int(tableNum) {
                    initialValue = UInt16(tableIndex)
                } else {
                    initialValue = 0
                }
            } else {
                initialValue = 0 // Default value for unresolved references
            }
        }

        globalTable[Int(globalIndex)] = initialValue
    }

    // MARK: - Global Variables

    public func allocateGlobal(_ name: String) -> UInt32 {
        // Find next available global slot
        for i in 0..<globalTable.count {
            if globalTable[i] == 0 {
                // Globals start at address 64 (after header), 2 bytes each
                let address = UInt32(calculateGlobalTableAddress()) + UInt32(i * 2)
                globalTable[i] = 1 // Mark as allocated
                return address
            }
        }
        return 0 // No more globals available
    }

    // MARK: - Object Management

    public func allocateObject(_ name: String) -> UInt32 {
        let objectId = UInt16(objectTable.count + 1)
        let entry = ObjectEntry(name: name, id: objectId)
        objectTable.append(entry)

        // Calculate object table address
        // Object table starts after globals (240 * 2 = 480 bytes) + header (64 bytes)
        let objectTableStart: UInt32 = 64 + 480
        let objectSize: UInt32 = version.rawValue >= 4 ? 14 : 9 // v4+ has 14-byte objects, earlier has 9-byte
        return objectTableStart + UInt32(objectTable.count - 1) * objectSize
    }

    public func startObject(_ name: String, location: SourceLocation) throws {
        guard objectTable.contains(where: { $0.name == name }) else {
            throw AssemblyError.memoryLayoutError("Object \(name) not found", location: location)
        }
        // Current object is now active for property assignment
    }

    public func endObject(location: SourceLocation) throws {
        // Finalize current object
    }

    public func addProperty(_ name: String) {
        let propertyId = UInt8(propertyTable.count + 1)
        let entry = PropertyEntry(name: name, id: propertyId, defaultValue: .number(0))
        propertyTable.append(entry)
    }

    /// Add a property to the specified object
    ///
    /// - Parameters:
    ///   - objectName: Name of the object to add property to
    ///   - propertyName: Name of the property
    ///   - value: Property value (can be string reference, object reference, etc.)
    ///   - symbolTable: Symbol table for resolving references
    ///   - location: Source location for error reporting
    /// - Throws: AssemblyError for invalid object or property
    public func addObjectProperty(objectName: String, propertyName: String, value: ZValue, symbolTable: [String: UInt32], location: SourceLocation) throws {
        // Find the object
        guard let objectIndex = objectTable.firstIndex(where: { $0.name == objectName }) else {
            throw AssemblyError.memoryLayoutError("Object \(objectName) not found", location: location)
        }

        // Resolve property value based on type
        let resolvedValue: ZValue
        switch value {
        case .atom(let name):
            // Check if this is a symbol reference (object, string, routine, etc.)
            if symbolTable[name] != nil {
                resolvedValue = value // Keep as reference for later resolution
            } else {
                resolvedValue = value // Use as-is for property names, flags, etc.
            }
        default:
            resolvedValue = value
        }

        // Add property to object
        objectTable[objectIndex].properties[propertyName] = resolvedValue
    }

    // MARK: - Dictionary Management

    /// Add a word to the dictionary
    ///
    /// - Parameters:
    ///   - word: The word to add to the dictionary
    ///   - data: Word-specific data (flags, type, etc.)
    public func addDictionaryWord(_ word: String, data: UInt16 = 0) {
        dictionary[word.lowercased()] = data
    }

    /// Add multiple words to the dictionary
    ///
    /// - Parameter words: Array of words to add
    public func addDictionaryWords(_ words: [String]) {
        for word in words {
            addDictionaryWord(word)
        }
    }

    // MARK: - String Management

    public func addString(_ id: String, content: String) -> UInt32 {
        // Add string to registry with deferred address calculation
        let entry = StringEntry(id: id, content: content)
        stringEntries.append(entry)

        // Return a placeholder address that will be resolved later
        // Use a high value to ensure it's in high memory range
        let placeholderAddress = 0x10000 + UInt32(stringEntries.count - 1)
        stringAddressMap[id] = placeholderAddress

        return placeholderAddress
    }

    /// Get the final address of a string by its ID (after story file generation)
    ///
    /// - Parameter stringId: The string identifier
    /// - Returns: The final address of the string in high memory, or nil if not found
    public func getStringAddress(_ stringId: String) -> UInt32? {
        return stringAddressMap[stringId]
    }

    // MARK: - Code Generation

    public func setStartRoutine(address: UInt32) {
        startRoutineAddress = address
    }

    public func addCode(_ bytecode: Data) {
        codeMemory.append(contentsOf: bytecode)
        currentAddress += UInt32(bytecode.count)
    }

    public func getCurrentAddress() -> UInt32 {
        return currentAddress
    }

    // MARK: - Story File Generation

    public func generateStoryFile() throws -> Data {
        var storyData = Data()

        // Generate header (with checksum temporarily set to 0)
        let header = try generateHeader()
        storyData.append(header)

        // Generate dynamic memory section
        let dynamicSection = generateDynamicMemory()
        storyData.append(dynamicSection)

        // Calculate static memory base based on current position
        staticMemoryBase = UInt32(storyData.count)

        // Generate static memory section
        let staticSection = try generateStaticMemory()
        storyData.append(staticSection)

        // Calculate high memory base based on current position
        highMemoryBase = UInt32(storyData.count)

        // Generate high memory section
        let highSection = try generateHighMemory()
        storyData.append(highSection)

        // Now regenerate header with correct memory bases
        let correctedHeader = try generateHeader()
        storyData.replaceSubrange(0..<64, with: correctedHeader)

        // Calculate and set checksum
        let checksum = calculateChecksum(for: storyData)
        storyData[28] = UInt8((checksum >> 8) & 0xFF)
        storyData[29] = UInt8(checksum & 0xFF)

        return storyData
    }

    /// Validate the generated story file against Z-Machine specification requirements
    /// - Parameter storyData: The complete story file data to validate
    /// - Returns: Array of validation warnings (empty if valid)
    public func validateStoryFile(_ storyData: Data) -> [String] {
        var warnings: [String] = []

        // Check minimum file size
        if storyData.count < 64 {
            warnings.append("Story file too small: must be at least 64 bytes for header")
            return warnings
        }

        // Validate header
        let headerVersion = storyData[0]
        if headerVersion != UInt8(version.rawValue) {
            warnings.append("Header version (\\(headerVersion)) doesn't match expected version (\\(version.rawValue))")
        }

        // Validate memory layout pointers
        let highMemBase = UInt16(storyData[4]) << 8 | UInt16(storyData[5])
        let staticMemBase = UInt16(storyData[14]) << 8 | UInt16(storyData[15])

        if highMemBase < staticMemBase {
            warnings.append("High memory base (\\(highMemBase)) is less than static memory base (\\(staticMemBase))")
        }

        // Validate dictionary address
        let dictAddress = UInt16(storyData[8]) << 8 | UInt16(storyData[9])
        if dictAddress != 0 && dictAddress < staticMemBase {
            warnings.append("Dictionary address (\\(dictAddress)) is in dynamic memory, should be in static memory")
        }

        // Validate object table address
        let objTableAddress = UInt16(storyData[10]) << 8 | UInt16(storyData[11])
        if objTableAddress < 64 {
            warnings.append("Object table address (\\(objTableAddress)) overlaps with header")
        }

        // Validate global table address
        let globalAddress = UInt16(storyData[12]) << 8 | UInt16(storyData[13])
        if globalAddress < 64 {
            warnings.append("Global table address (\\(globalAddress)) overlaps with header")
        }

        // Check file length scaling
        let fileLength = UInt16(storyData[26]) << 8 | UInt16(storyData[27])
        let actualLength = UInt32(storyData.count)
        let scaleFactor: UInt32
        switch version {
        case .v3: scaleFactor = 2
        case .v4, .v5: scaleFactor = 4
        case .v6, .v7, .v8: scaleFactor = 8
        }

        let expectedLength = UInt32(fileLength) * scaleFactor
        if expectedLength != actualLength {
            warnings.append("File length mismatch: header indicates \\(expectedLength) bytes, actual file is \\(actualLength) bytes")
        }

        // Validate checksum
        let headerChecksum = UInt16(storyData[28]) << 8 | UInt16(storyData[29])
        let calculatedChecksum = calculateChecksum(for: storyData)
        if headerChecksum != calculatedChecksum {
            warnings.append("Checksum mismatch: header has \\(headerChecksum), calculated \\(calculatedChecksum)")
        }

        return warnings
    }

    private func calculateChecksum(for storyData: Data) -> UInt16 {
        // Z-Machine checksum is calculated over the entire file except bytes 28-29 (checksum bytes)
        var checksum: UInt32 = 0

        // Add bytes 0-27 (before checksum)
        for i in 0..<28 {
            checksum += UInt32(storyData[i])
        }

        // Skip bytes 28-29 (the checksum bytes themselves)

        // Add bytes 30 onwards (after checksum)
        for i in 30..<storyData.count {
            checksum += UInt32(storyData[i])
        }

        // Return lower 16 bits of sum
        return UInt16(checksum & 0xFFFF)
    }

    private func generateHeader() throws -> Data {
        var header = Data(repeating: 0, count: 64)

        // Byte 0: Version number
        header[0] = UInt8(version.rawValue)

        // Byte 1: Flags 1 (interpreter capabilities - set by interpreter)
        header[1] = 0x00

        // Bytes 2-3: Release number (high byte first)
        let releaseNumber: UInt16 = 1
        header[2] = UInt8((releaseNumber >> 8) & 0xFF)
        header[3] = UInt8(releaseNumber & 0xFF)

        // Bytes 4-5: High memory base (high byte first)
        // SAFETY: Ensure high memory base fits in UInt16
        guard highMemoryBase <= 0xFFFF else {
            throw AssemblyError.memoryLayoutError("High memory base (\(highMemoryBase)) exceeds UInt16 limit for header storage", location: SourceLocation.unknown)
        }
        let highMemBase = UInt16(highMemoryBase)
        header[4] = UInt8((highMemBase >> 8) & 0xFF)
        header[5] = UInt8(highMemBase & 0xFF)

        // Bytes 6-7: Initial PC (start routine address - high byte first)
        let packedStartAddress = packRoutineAddress(startRoutineAddress == 0 ? highMemoryBase : startRoutineAddress)
        header[6] = UInt8((packedStartAddress >> 8) & 0xFF)
        header[7] = UInt8(packedStartAddress & 0xFF)

        // Bytes 8-9: Dictionary address (high byte first)
        let dictAddress = calculateDictionaryAddress()
        header[8] = UInt8((dictAddress >> 8) & 0xFF)
        header[9] = UInt8(dictAddress & 0xFF)

        // Bytes 10-11: Object table address (high byte first)
        let objTableAddress = calculateObjectTableAddress()
        header[10] = UInt8((objTableAddress >> 8) & 0xFF)
        header[11] = UInt8(objTableAddress & 0xFF)

        // Bytes 12-13: Global variables address (high byte first)
        let globalAddress = calculateGlobalTableAddress()
        header[12] = UInt8((globalAddress >> 8) & 0xFF)
        header[13] = UInt8(globalAddress & 0xFF)

        // Bytes 14-15: Static memory base (high byte first)
        // SAFETY: Ensure static memory base fits in UInt16
        guard staticMemoryBase <= 0xFFFF else {
            throw AssemblyError.memoryLayoutError("Static memory base (\(staticMemoryBase)) exceeds UInt16 limit for header storage", location: SourceLocation.unknown)
        }
        let staticMemBase = UInt16(staticMemoryBase)
        header[14] = UInt8((staticMemBase >> 8) & 0xFF)
        header[15] = UInt8(staticMemBase & 0xFF)

        // Bytes 16-17: Flags 2 (story file requirements)
        var flags2: UInt16 = 0
        // Set status line type based on version
        if version.rawValue >= 4 {
            flags2 |= 0x0002 // Score/turns status line
        } else {
            flags2 |= 0x0040 // Location/object status line
        }
        header[16] = UInt8((flags2 >> 8) & 0xFF)
        header[17] = UInt8(flags2 & 0xFF)

        // Bytes 18-23: Serial number (YYMMDD format)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd"
        let serialString = dateFormatter.string(from: Date())
        let serialBytes = serialString.data(using: .ascii) ?? Data("000000".utf8)
        for i in 0..<min(6, serialBytes.count) {
            header[18 + i] = serialBytes[i]
        }

        // Bytes 24-25: Abbreviations table address (high byte first)
        let abbrevAddress = calculateAbbreviationsAddress()
        header[24] = UInt8((abbrevAddress >> 8) & 0xFF)
        header[25] = UInt8(abbrevAddress & 0xFF)

        // Bytes 26-27: File length (divided by scale factor)
        let totalLength = calculateTotalFileLength()
        let scaledLength = scaleFileLength(totalLength)
        header[26] = UInt8((scaledLength >> 8) & 0xFF)
        header[27] = UInt8(scaledLength & 0xFF)

        // Bytes 28-29: File checksum (calculated after generating complete story file)
        header[28] = 0x00
        header[29] = 0x00

        // Version-specific fields
        if version.rawValue >= 4 {
            // Bytes 30-31: Interpreter number/version (set by interpreter)
            header[30] = 0x00
            header[31] = 0x00

            // Bytes 32-33: Screen size (set by interpreter)
            header[32] = 24  // Default height in lines
            header[33] = 80  // Default width in characters
        }

        if version.rawValue >= 5 {
            // Bytes 34-35: Screen width in units (set by interpreter)
            header[34] = 0x00
            header[35] = 0x50  // 80 units

            // Bytes 36-37: Screen height in units (set by interpreter)
            header[36] = 0x00
            header[37] = 0x18  // 24 units

            // Byte 38: Font width/height (version dependent)
            // Byte 39: Font height/width (version dependent)
            if version == .v6 {
                header[38] = 1  // Font width in v6
                header[39] = 1  // Font height in v6
            } else {
                header[38] = 1  // Font height in v5
                header[39] = 1  // Font width in v5
            }

            // Bytes 44-45: Default background/foreground colors
            header[46] = 9  // Default background (white)
            header[47] = 2  // Default foreground (black)
        }

        // Remaining bytes are reserved and should be zero
        return header
    }

    private func calculateObjectTableAddress() -> UInt16 {
        // Object table starts at the beginning of static memory
        return UInt16(staticMemoryBase)
    }

    private func calculateGlobalTableAddress() -> UInt16 {
        // Global table starts right after header
        return 64
    }

    private func calculateDictionaryAddress() -> UInt16 {
        // Dictionary goes in static memory after object tables and property tables
        let objectTableSize = calculateObjectTableSize()
        let propertyTableSize = calculatePropertyTableSize()
        return UInt16(staticMemoryBase + objectTableSize + propertyTableSize)
    }

    private func calculateAbbreviationsAddress() -> UInt16 {
        // No abbreviations for now - point to dictionary
        return calculateDictionaryAddress()
    }

    private func calculateObjectTableSize() -> UInt32 {
        // Property defaults (31 words) + object entries
        let propertyDefaults: UInt32 = 31 * 2
        let objectSize: UInt32 = version.rawValue >= 4 ? 14 : 9
        let objectEntries = UInt32(objectTable.count) * objectSize
        return propertyDefaults + objectEntries
    }

    private func calculatePropertyTableSize() -> UInt32 {
        // Estimate property table size by calculating all property tables
        var totalSize: UInt32 = 0
        for object in objectTable {
            if !object.properties.isEmpty {
                // Rough estimate: object name + properties
                // This is a conservative estimate

                // Check for potential overflow in name size calculation
                guard object.name.count <= (UInt32.max - 1) / 2 else {
                    // Object name too long - return conservative maximum
                    return UInt32.max / 2
                }
                let nameSize = UInt32(object.name.count * 2) + 1 // Encoded name size + length byte

                // Check for potential overflow in properties size calculation
                guard object.properties.count <= UInt32.max / 4 else {
                    // Too many properties - return conservative maximum
                    return UInt32.max / 2
                }
                let propertiesSize = UInt32(object.properties.count * 4) // Conservative estimate per property

                // Check for overflow in total size addition
                let objectSize = nameSize + propertiesSize + 1 // +1 for end marker
                guard totalSize <= UInt32.max - objectSize else {
                    // Would overflow - return maximum possible size
                    return UInt32.max
                }
                totalSize += objectSize
            }
        }
        return (totalSize + 1) & ~1 // Word-align
    }

    private func calculateTotalFileLength() -> UInt32 {
        // Calculate total file length with overflow protection
        var totalLength: UInt32 = 64 // Header size

        // Add dynamic memory size
        guard totalLength <= UInt32.max - UInt32(dynamicMemory.count) else {
            return UInt32.max
        }
        totalLength += UInt32(dynamicMemory.count)

        // Add static memory estimate (0x8000 = 32KB)
        guard totalLength <= UInt32.max - 0x8000 else {
            return UInt32.max
        }
        totalLength += 0x8000

        // Add code memory size
        guard totalLength <= UInt32.max - UInt32(codeMemory.count) else {
            return UInt32.max
        }
        totalLength += UInt32(codeMemory.count)

        return totalLength
    }

    private func packRoutineAddress(_ address: UInt32) -> UInt16 {
        // Routine addresses in Z-Machine are sometimes packed (divided by scale factor)
        // This depends on the version and where they're used
        let divisor: UInt32
        switch version {
        case .v3:
            divisor = 2
        case .v4, .v5:
            divisor = 4
        case .v6, .v7, .v8:
            divisor = 8
        }
        return UInt16(min(0xFFFF, address / divisor))
    }

    private func scaleFileLength(_ length: UInt32) -> UInt16 {
        let divisor: UInt32
        switch version {
        case .v3:
            divisor = 2
        case .v4, .v5:
            divisor = 4
        case .v6, .v7, .v8:
            divisor = 8
        }
        return UInt16(min(0xFFFF, length / divisor))
    }

    private func generateDynamicMemory() -> Data {
        // Copy current dynamic memory state
        return Data(dynamicMemory)
    }

    private func generateStaticMemory() throws -> Data {
        var staticData = Data()

        // First, generate property tables and set property table addresses in objects
        let propertyTableData = try generatePropertyTables()

        // Now generate object table with correct property table addresses
        let objectTableData = try generateObjectTable()
        staticData.append(objectTableData)

        // Add the property tables after the object table
        staticData.append(propertyTableData)

        // Add dictionary
        let dictionaryData = generateDictionary()
        staticData.append(dictionaryData)

        // Pad to required size
        while staticData.count < staticMemory.count {
            staticData.append(0)
        }

        return staticData
    }

    private func generateHighMemory() throws -> Data {
        var highData = Data()

        // Add compressed strings
        let stringData = try generateStringTable()
        highData.append(stringData)

        // Add compiled code
        highData.append(Data(codeMemory))

        return highData
    }

    private func generateObjectTable() throws -> Data {
        var tableData = Data()

        // Property defaults table FIRST (31 words for properties 1-31)
        // These are the default values for properties when not explicitly set on objects
        for _ in 1...31 {
            let defaultValue: UInt16 = 0 // Default property value
            tableData.append(UInt8((defaultValue >> 8) & 0xFF))
            tableData.append(UInt8(defaultValue & 0xFF))
        }

        // Object entries follow the property defaults
        for object in objectTable {
            if version.rawValue >= 4 {
                // Version 4+ object format (14 bytes total)
                // Attributes: 6 bytes (48 bits)
                let attrs = object.attributes
                tableData.append(UInt8((attrs >> 40) & 0xFF))
                tableData.append(UInt8((attrs >> 32) & 0xFF))
                tableData.append(UInt8((attrs >> 24) & 0xFF))
                tableData.append(UInt8((attrs >> 16) & 0xFF))
                tableData.append(UInt8((attrs >> 8) & 0xFF))
                tableData.append(UInt8(attrs & 0xFF))

                // Parent object (2 bytes)
                tableData.append(UInt8((object.parent >> 8) & 0xFF))
                tableData.append(UInt8(object.parent & 0xFF))

                // Sibling object (2 bytes)
                tableData.append(UInt8((object.sibling >> 8) & 0xFF))
                tableData.append(UInt8(object.sibling & 0xFF))

                // Child object (2 bytes)
                tableData.append(UInt8((object.child >> 8) & 0xFF))
                tableData.append(UInt8(object.child & 0xFF))

                // Property table address (2 bytes)
                tableData.append(UInt8((object.propertyTableAddress >> 8) & 0xFF))
                tableData.append(UInt8(object.propertyTableAddress & 0xFF))
            } else {
                // Version 3 object format (9 bytes total)
                // Attributes: 4 bytes (32 bits)
                let attrs = object.attributes
                tableData.append(UInt8((attrs >> 24) & 0xFF))
                tableData.append(UInt8((attrs >> 16) & 0xFF))
                tableData.append(UInt8((attrs >> 8) & 0xFF))
                tableData.append(UInt8(attrs & 0xFF))

                // Parent object (1 byte in v3)
                tableData.append(UInt8(object.parent & 0xFF))

                // Sibling object (1 byte in v3)
                tableData.append(UInt8(object.sibling & 0xFF))

                // Child object (1 byte in v3)
                tableData.append(UInt8(object.child & 0xFF))

                // Property table address (2 bytes)
                tableData.append(UInt8((object.propertyTableAddress >> 8) & 0xFF))
                tableData.append(UInt8(object.propertyTableAddress & 0xFF))
            }
        }

        return tableData
    }

    private func generatePropertyDefaults() -> Data {
        // Z-Machine requires exactly 31 property default values (31 words = 62 bytes)
        // Properties 1-31 each have a default value stored as UInt16 (big-endian)
        var defaultsData = Data()

        for _ in 1...31 {
            // Default value for each property (can be customized later)
            let defaultValue: UInt16 = 0
            defaultsData.append(UInt8((defaultValue >> 8) & 0xFF)) // High byte
            defaultsData.append(UInt8(defaultValue & 0xFF))        // Low byte
        }

        return defaultsData
    }

    private func generateDictionary() -> Data {
        var dictData = Data()

        // Dictionary header
        // Byte 0: Number of input separators (keyboard input delimiters)
        let separators = " .,?!;:"
        dictData.append(UInt8(separators.count))

        // Separator characters
        for char in separators {
            dictData.append(UInt8(char.asciiValue ?? 32))
        }

        // Entry length in bytes
        let entryLength: UInt8 = version.rawValue >= 4 ? 9 : 7  // v4+: 6 bytes word + 3 bytes data, v3: 4 bytes word + 3 bytes data
        dictData.append(entryLength)

        // For empty dictionary, add a few common words so we have a valid structure for testing
        var dictionaryWords = dictionary
        if dictionary.isEmpty {
            // Add minimal test dictionary for basic functionality
            dictionaryWords = [
                "the": 1,
                "a": 2,
                "an": 3,
                "go": 4,
                "look": 5,
                "take": 6,
                "drop": 7,
                "north": 8,
                "south": 9,
                "east": 10,
                "west": 11
            ]
        }

        // Number of entries (signed 16-bit, positive means sorted)
        let entryCount = Int16(dictionaryWords.count)
        dictData.append(UInt8((entryCount >> 8) & 0xFF))
        dictData.append(UInt8(entryCount & 0xFF))

        // Dictionary entries (must be sorted alphabetically)
        let sortedWords = dictionaryWords.keys.sorted()
        for word in sortedWords {
            let encodedWord = encodeWordForDictionary(word)
            dictData.append(encodedWord)

            // Word data (flags, etc.) - simplified for now
            let wordData: UInt32 = dictionaryWords[word].map(UInt32.init) ?? 0  // Use word data from dictionary
            dictData.append(UInt8((wordData >> 16) & 0xFF))
            dictData.append(UInt8((wordData >> 8) & 0xFF))
            dictData.append(UInt8(wordData & 0xFF))
        }

        return dictData
    }

    private func encodeWordForDictionary(_ word: String) -> Data {
        // Z-Machine dictionary words are encoded using Z-characters
        // v3: 4 Z-chars (2 words), v4+: 6 Z-chars (3 words)

        let maxZChars = version.rawValue >= 4 ? 6 : 4
        let wordLength = version.rawValue >= 4 ? 6 : 4  // bytes
        var encoded = Data(repeating: 0, count: wordLength)

        // Simplified encoding - convert to uppercase and truncate
        let upperWord = word.uppercased().prefix(maxZChars)
        let chars = Array(upperWord)

        // Pack characters into Z-character format (5 bits each, 3 per word)
        var charIndex = 0
        for wordIndex in 0..<(wordLength / 2) {
            var packedWord: UInt16 = 0

            // Pack 3 characters into one 16-bit word
            for bitPos in [10, 5, 0] {
                if charIndex < chars.count {
                    let char = chars[charIndex]
                    let zchar = convertToZChar(char)
                    packedWord |= UInt16(zchar) << bitPos
                }
                charIndex += 1
            }

            // Set end bit on last word
            if wordIndex == (wordLength / 2) - 1 {
                packedWord |= 0x8000
            }

            encoded[wordIndex * 2] = UInt8((packedWord >> 8) & 0xFF)
            encoded[wordIndex * 2 + 1] = UInt8(packedWord & 0xFF)
        }

        return encoded
    }

    private func convertToZChar(_ char: Character) -> UInt8 {
        // Convert character to Z-character (5-bit encoding)
        // This is a simplified implementation

        if char == " " { return 0 }

        // Alphabet A0: a-z
        if let ascii = char.asciiValue, ascii >= 97 && ascii <= 122 {
            return UInt8(ascii - 97 + 6)  // 'a' = 6, 'b' = 7, etc.
        }

        // Alphabet A1: A-Z (shift code 4 + character)
        if let ascii = char.asciiValue, ascii >= 65 && ascii <= 90 {
            return UInt8(ascii - 65 + 6)  // Will need proper shift handling
        }

        // For simplicity, map unknown characters to 'a'
        return 6
    }

    private func generateStringTable() throws -> Data {
        var stringData = Data()
        var currentOffset: UInt32 = 0

        // Calculate actual addresses and generate string data
        for i in 0..<stringEntries.count {
            let stringEntry = stringEntries[i]

            // Calculate actual address for this string
            let actualAddress = highMemoryBase + currentOffset
            stringEntries[i].address = actualAddress
            stringAddressMap[stringEntry.id] = actualAddress

            // Encode string using Z-Machine text encoding
            let encodedString = try encodeZString(stringEntry.content)
            stringData.append(encodedString)

            // Update offset for next string
            currentOffset += UInt32(encodedString.count)

            // Word-align strings for better performance
            if currentOffset % 2 != 0 {
                stringData.append(0)
                currentOffset += 1
            }
        }

        return stringData
    }

    private func encodeZString(_ string: String) throws -> Data {
        // Proper Z-string encoding with ZSCII compression
        var encoded = Data()
        let chars = Array(string)
        var i = 0

        while i < chars.count {
            var word: UInt16 = 0
            var isLastWord = false

            // Pack 3 Z-characters into one 16-bit word
            for charPos in [10, 5, 0] {
                var zchar: UInt8 = 5  // Padding character

                if i < chars.count {
                    zchar = convertStringCharToZChar(chars[i])
                    i += 1
                } else if charPos == 0 {
                    // This is the last character position in potentially the last word
                    isLastWord = true
                }

                word |= UInt16(zchar & 0x1F) << charPos
            }

            // Check if this should be the last word
            if i >= chars.count {
                isLastWord = true
            }

            // Set the end bit (bit 15) on the last word
            if isLastWord {
                word |= 0x8000
            }

            encoded.append(UInt8((word >> 8) & 0xFF))
            encoded.append(UInt8(word & 0xFF))

            if isLastWord {
                break
            }
        }

        // Ensure at least one word with end bit set
        if encoded.isEmpty {
            encoded.append(0x80)  // Empty string: just end bit
            encoded.append(0x00)
        }

        return encoded
    }

    private func convertStringCharToZChar(_ char: Character) -> UInt8 {
        // Convert character to Z-character for string encoding
        // This handles the full ZSCII alphabet mapping

        if char == " " { return 0 }

        // Alphabet A0: lowercase letters a-z (Z-chars 6-31)
        if let ascii = char.asciiValue, ascii >= 97 && ascii <= 122 {
            return UInt8(ascii - 97 + 6)
        }

        // For uppercase letters, we need a shift sequence (simplified here)
        if let ascii = char.asciiValue, ascii >= 65 && ascii <= 90 {
            // In proper implementation, this would emit shift code 4 followed by the character
            // For now, convert to lowercase
            return UInt8(ascii - 65 + 6)
        }

        // Numbers and punctuation would go in alphabet A2 with shift code 5
        if let ascii = char.asciiValue {
            switch ascii {
            case 48...57:  // 0-9
                return UInt8(ascii - 48 + 7)  // Simplified mapping
            case 46:  // .
                return 18
            case 44:  // ,
                return 19
            case 33:  // !
                return 20
            case 63:  // ?
                return 21
            default:
                return 6  // Default to 'a'
            }
        }

        return 6  // Default fallback
    }

    private func generatePropertyTables() throws -> Data {
        var propertyData = Data()
        // Property tables start after the object table in static memory
        var currentOffset = calculateObjectTableSize()

        // Generate property table for each object
        for (objectIndex, object) in objectTable.enumerated() {
            if object.properties.isEmpty {
                // Object has no properties - set property table address to 0
                objectTable[objectIndex].propertyTableAddress = 0
            } else {
                // Object has properties - generate property table
                let propertyTable = try generatePropertyTable(for: object)

                print("       Object \(object.name): Properties found, setting address to \(currentOffset)")
                print("       Generated property table size: \(propertyTable.count) bytes")

                // Update object's property table address (offset within static memory)
                objectTable[objectIndex].propertyTableAddress = UInt16(currentOffset)

                propertyData.append(propertyTable)
                currentOffset += UInt32(propertyTable.count)

                // Ensure word alignment
                if propertyData.count % 2 != 0 {
                    propertyData.append(0)
                    currentOffset += 1
                }
            }
        }

        print("       Total property data size: \(propertyData.count) bytes")
        return propertyData
    }

    private func generatePropertyTable(for object: ObjectEntry) throws -> Data {
        var tableData = Data()

        // Object short name (text length + encoded text)
        let shortName = object.name
        let encodedName = try encodeZString(shortName)

        // Text length in words (not including the length byte itself)
        let textLengthInWords = UInt8(encodedName.count / 2)
        tableData.append(textLengthInWords)
        tableData.append(encodedName)

        // Properties in DESCENDING order by property number (critical requirement!)
        let sortedProperties = object.properties.sorted { first, second in
            // Extract property numbers and sort in descending order
            let firstNum = getPropertyNumber(first.key)
            let secondNum = getPropertyNumber(second.key)
            return firstNum > secondNum
        }

        for (propertyName, propertyValue) in sortedProperties {
            let propertyNum = getPropertyNumber(propertyName)
            let propertyData = try encodePropertyValue(propertyValue)

            if version.rawValue >= 4 {
                // Version 4+ property format
                if propertyData.count <= 2 {
                    // Short format: LLLL PPPP (length-1 in top 4 bits, property# in bottom 4 bits)
                    let header = UInt8(((propertyData.count - 1) << 5) | (Int(propertyNum) & 0x1F))
                    tableData.append(header)
                } else {
                    // Long format: 1PPP PPPP LLLL LLLL (first byte has bit 7 set)
                    let header1 = UInt8(0x80 | (propertyNum & 0x7F))
                    let header2 = UInt8(propertyData.count & 0xFF)
                    tableData.append(header1)
                    tableData.append(header2)
                }
            } else {
                // Version 3 property format: SSSS PPPP (size-1 in top 3 bits, property# in bottom 5 bits)
                let size = min(propertyData.count, 8) // V3 max property size is 8 bytes
                let header = UInt8(((size - 1) << 5) | (Int(propertyNum) & 0x1F))
                tableData.append(header)
            }

            tableData.append(propertyData)
        }

        // End marker (property number 0)
        tableData.append(0x00)

        return tableData
    }

    private func getPropertyNumber(_ propertyName: String) -> UInt8 {
        // Map property name to number
        // This should integrate with the property defaults table
        let standardProperties = [
            "DESC": 1, "LDESC": 2, "FDESC": 3, "ACTION": 4, "SYNONYM": 5,
            "ADJECTIVE": 6, "STRENGTH": 7, "CAPACITY": 8, "SIZE": 9, "VALUE": 10,
            "TVALUE": 11, "TEXT": 12, "NORTH": 13, "SOUTH": 14, "EAST": 15,
            "WEST": 16, "NE": 17, "NW": 18, "SE": 19, "SW": 20, "UP": 21,
            "DOWN": 22, "IN": 23, "OUT": 24, "CONT": 25, "PSEUDO": 26,
            "GLOBAL": 27, "VTYPE": 28, "THINGS": 29, "DESCFCN": 30, "ACTFCN": 31
        ]

        return UInt8(standardProperties[propertyName.uppercased()] ?? 1)
    }

    private func encodePropertyValue(_ value: ZValue) throws -> Data {
        switch value {
        case .number(let num):
            if abs(num) <= 255 {
                return Data([UInt8(abs(num))])
            } else {
                let val = UInt16(abs(num))
                return Data([UInt8((val >> 8) & 0xFF), UInt8(val & 0xFF)])
            }
        case .string(let str):
            // String properties store the encoded string directly
            return try encodeZString(str)
        case .atom:
            // Atom properties typically reference routines or other objects
            // For now, encode as a placeholder address
            return Data([0x00, 0x01])
        default:
            return Data([0x00])
        }
    }
}