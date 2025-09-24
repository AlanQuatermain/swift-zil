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
    private var stringTable: [String] = []
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
        let dynamicSize = version.rawValue >= 5 ? 0x10000 : 0x8000 // 64KB for v5+, 32KB for earlier
        dynamicMemory = Array(repeating: 0, count: dynamicSize)

        // Reserve space for header (64 bytes)
        currentAddress = 64

        // Set up memory bases
        staticMemoryBase = UInt32(dynamicSize)
        highMemoryBase = staticMemoryBase + 0x8000 // Arbitrary offset for high memory
    }

    // MARK: - Global Variables

    public func allocateGlobal(_ name: String) -> UInt32 {
        // Find next available global slot
        for i in 0..<globalTable.count {
            if globalTable[i] == 0 {
                let address = 0x10 + UInt32(i * 2) // Globals start at 0x10, 2 bytes each
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

    // MARK: - String Management

    public func addString(_ id: String, content: String) -> UInt32 {
        stringTable.append(content)
        let stringIndex = stringTable.count - 1

        // Calculate string address in high memory
        // This is simplified - real implementation would pack strings properly
        let stringAddress = highMemoryBase + UInt32(stringIndex * 100) // Arbitrary spacing
        return stringAddress
    }

    // MARK: - Code Generation

    public func setStartRoutine(address: UInt32) {
        startRoutineAddress = address
    }

    public func addCode(_ bytecode: Data) {
        codeMemory.append(contentsOf: bytecode)
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

        // Generate static memory section
        let staticSection = try generateStaticMemory()
        storyData.append(staticSection)

        // Generate high memory section
        let highSection = try generateHighMemory()
        storyData.append(highSection)

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
        header[14] = UInt8((staticMemoryBase >> 8) & 0xFF)
        header[15] = UInt8(staticMemoryBase & 0xFF)

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
        // Object table starts after header and global variables
        return UInt16(64 + 240 * 2) // Header (64) + Globals (240 * 2 bytes)
    }

    private func calculateGlobalTableAddress() -> UInt16 {
        // Global table starts right after header
        return 64
    }

    private func calculateDictionaryAddress() -> UInt16 {
        // Dictionary goes in static memory after object tables
        let objectTableSize = calculateObjectTableSize()
        return UInt16(staticMemoryBase + objectTableSize)
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

    private func calculateTotalFileLength() -> UInt32 {
        // Simplified - in real implementation, calculate actual final size
        return 64 + UInt32(dynamicMemory.count) + 0x8000 + UInt32(codeMemory.count)
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

        // Add object table
        let objectTableData = try generateObjectTable()
        staticData.append(objectTableData)

        // Add property defaults
        let propertyDefaults = generatePropertyDefaults()
        staticData.append(propertyDefaults)

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
        // Property default values are included in object table
        return Data()
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

        // Number of entries (signed 16-bit, positive means sorted)
        let entryCount = Int16(dictionary.count)
        dictData.append(UInt8((entryCount >> 8) & 0xFF))
        dictData.append(UInt8(entryCount & 0xFF))

        // Dictionary entries (must be sorted alphabetically)
        let sortedWords = dictionary.keys.sorted()
        for word in sortedWords {
            let encodedWord = encodeWordForDictionary(word)
            dictData.append(encodedWord)

            // Word data (flags, etc.) - simplified for now
            let wordData: UInt32 = 0  // Word flags and data
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

        // Encode strings using Z-Machine text encoding
        for string in stringTable {
            let encodedString = try encodeZString(string)
            stringData.append(encodedString)
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
        var currentAddress = staticMemoryBase + calculateObjectTableSize()

        // Generate property table for each object
        for (objectIndex, object) in objectTable.enumerated() {
            let propertyTable = try generatePropertyTable(for: object)

            // Update object's property table address
            objectTable[objectIndex].propertyTableAddress = UInt16(currentAddress)

            propertyData.append(propertyTable)
            currentAddress += UInt32(propertyTable.count)

            // Ensure word alignment
            if propertyData.count % 2 != 0 {
                propertyData.append(0)
                currentAddress += 1
            }
        }

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