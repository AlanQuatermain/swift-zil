/// Z-Machine Virtual Machine - Executes Z-Machine bytecode story files
import Foundation

/// Z-Machine Virtual Machine that executes story files
///
/// The Z-Machine VM loads and executes Z-Machine story files, providing
/// a complete interactive fiction runtime environment. It implements
/// the full Z-Machine instruction set and handles all version-specific
/// features and capabilities.
///
/// ## Key Features
/// - Support for all Z-Machine versions (3, 4, 5, 6, 8)
/// - Complete instruction set implementation
/// - Memory management with proper region isolation
/// - Save/restore functionality using Quetzal format
/// - Text I/O with ZSCII encoding
/// - Object and property system
/// - Parser integration for command processing
///
/// ## Usage Example
/// ```swift
/// let vm = ZMachine()
/// try vm.loadStoryFile(from: storyFileURL)
/// try vm.run() // Start interactive session
/// ```
public class ZMachine {

    // MARK: - Story File Information

    /// The loaded story file data
    private var storyData: Data = Data()

    /// Z-Machine version from story file header
    public private(set) var version: ZMachineVersion = .v3

    /// Story file header information
    public private(set) var header: StoryHeader = StoryHeader()

    // MARK: - Memory Management

    /// Dynamic memory region (read/write)
    private var dynamicMemory: Data = Data()

    /// Static memory region (read-only)
    private var staticMemory: Data = Data()

    /// High memory region (execute-only)
    private var highMemory: Data = Data()

    /// Memory region boundaries
    private var staticMemoryBase: UInt32 = 0
    private var highMemoryBase: UInt32 = 0

    // MARK: - Execution State

    /// Program counter (instruction pointer)
    internal var programCounter: UInt32 = 0

    /// Call stack for routine calls
    internal var callStack: [StackFrame] = []

    /// Evaluation stack for computations
    internal var evaluationStack: [Int16] = []

    /// Global variables (240 words)
    internal var globals: [UInt16] = Array(repeating: 0, count: 240)

    /// Local variables for current routine
    internal var locals: [UInt16] = []

    // MARK: - Game State

    /// Current object tree
    internal var objectTree: ObjectTree = ObjectTree()

    /// Dictionary for parser
    internal var dictionary: Dictionary = Dictionary()

    /// Abbreviation table for text decompression (96 entries: 32 each for A0, A1, A2)
    internal var abbreviationTable: [UInt32] = []

    /// Text output buffer
    private var outputBuffer: String = ""

    /// Input buffer for reading commands
    private var inputBuffer: String = ""

    /// VM execution state
    internal var isRunning: Bool = false
    internal var hasQuit: Bool = false

    // MARK: - I/O Delegates

    /// Text output delegate
    public weak var outputDelegate: TextOutputDelegate?

    /// Text input delegate
    public weak var inputDelegate: TextInputDelegate?

    // MARK: - Initialization

    public init() {
        // Initialize VM components
        setupInitialState()
    }

    private func setupInitialState() {
        callStack.removeAll()
        evaluationStack.removeAll()
        locals.removeAll()
        globals = Array(repeating: 0, count: 240)
        abbreviationTable.removeAll()
        programCounter = 0
        isRunning = false
        hasQuit = false
        outputBuffer = ""
        inputBuffer = ""
    }

    // MARK: - Story File Loading

    /// Load a Z-Machine story file
    ///
    /// - Parameter url: URL of the story file to load
    /// - Throws: RuntimeError for invalid or corrupted story files
    public func loadStoryFile(from url: URL) throws {
        storyData = try Data(contentsOf: url)

        guard storyData.count >= 64 else {
            throw RuntimeError.corruptedStoryFile("Story file too small (minimum 64 bytes required)", location: SourceLocation.unknown)
        }

        try parseHeader()
        try setupMemoryRegions()
        try loadGameData()

        // Reset VM state but preserve important header values
        setupInitialState()

        // Set initial PC from header AFTER memory setup - the PC may need unpacking
        programCounter = unpackRoutineAddress(header.initialPC)

        // Validate that the initial PC is within executable memory
        try validateProgramCounter()
    }

    /// Validate that the program counter is within valid executable memory
    private func validateProgramCounter() throws {
        // PC must be within high memory (executable region)
        let maxAddress = highMemoryBase + UInt32(highMemory.count)
        guard programCounter >= highMemoryBase && programCounter < maxAddress else {
            throw RuntimeError.corruptedStoryFile("Initial PC (\(programCounter)) not in executable memory range (\(highMemoryBase)-\(maxAddress))", location: SourceLocation.unknown)
        }
    }

    private func parseHeader() throws {
        header = try StoryHeader(from: storyData)
        version = header.version

        // Validate version support
        guard [3, 4, 5, 6, 8].contains(version.rawValue) else {
            throw RuntimeError.corruptedStoryFile("Unsupported Z-Machine version \(version.rawValue)", location: SourceLocation.unknown)
        }
    }

    private func setupMemoryRegions() throws {
        let dataSize = storyData.count

        // Validate memory region boundaries according to ZIP specification
        guard staticMemoryBase >= 64 else {
            throw RuntimeError.corruptedStoryFile("Static memory base (\(staticMemoryBase)) must be >= 64", location: SourceLocation.unknown)
        }

        guard staticMemoryBase <= highMemoryBase else {
            throw RuntimeError.corruptedStoryFile("Static memory base (\(staticMemoryBase)) must be <= high memory base (\(highMemoryBase))", location: SourceLocation.unknown)
        }

        // Dynamic memory: from start to static memory base
        // This region is read/write and contains globals, object tree changes, etc.
        let dynamicSize = Int(staticMemoryBase)
        guard dynamicSize <= dataSize else {
            throw RuntimeError.corruptedStoryFile("Dynamic memory size (\(dynamicSize)) exceeds file size (\(dataSize))", location: SourceLocation.unknown)
        }

        dynamicMemory = Data(storyData.subdata(in: 0..<dynamicSize))

        // Static memory: from static base to high memory base
        // This region is read-only and contains dictionary, object table, etc.
        let staticStart = Int(staticMemoryBase)
        let staticEnd = Int(highMemoryBase)

        guard staticStart <= staticEnd && staticEnd <= dataSize else {
            throw RuntimeError.corruptedStoryFile("Invalid static memory bounds: start=\(staticStart), end=\(staticEnd), file=\(dataSize)", location: SourceLocation.unknown)
        }

        staticMemory = storyData.subdata(in: staticStart..<staticEnd)

        // High memory: from high base to end of file
        // This region contains executable code and compressed strings
        let highStart = Int(highMemoryBase)
        guard highStart <= dataSize else {
            throw RuntimeError.corruptedStoryFile("High memory start (\(highStart)) exceeds file size (\(dataSize))", location: SourceLocation.unknown)
        }

        highMemory = storyData.subdata(in: highStart..<dataSize)

        // Validate version-specific memory constraints
        try validateMemoryLayout()
    }

    /// Validate memory layout according to ZIP specification
    private func validateMemoryLayout() throws {
        let totalSize = UInt32(storyData.count)
        let maxMemory = ZMachine.getMaxMemorySize(for: version)

        // Check total file size against version limits
        guard totalSize <= maxMemory else {
            throw RuntimeError.corruptedStoryFile("File size \(totalSize) exceeds v\(version.rawValue) limit of \(maxMemory) bytes", location: SourceLocation.unknown)
        }

        // Ensure critical constraint: first 64KB must contain all modifiable data
        let criticalBoundary: UInt32 = 65536
        guard staticMemoryBase <= criticalBoundary else {
            throw RuntimeError.corruptedStoryFile("Static memory base (\(staticMemoryBase)) exceeds 64KB boundary required by ZIP spec", location: SourceLocation.unknown)
        }

        // Version-specific validation
        switch version {
        case .v3:
            // Version 3: 128KB total, simple memory model
            guard totalSize <= 131072 else {
                throw RuntimeError.corruptedStoryFile("v3 file size \(totalSize) exceeds 128KB limit", location: SourceLocation.unknown)
            }
        case .v4, .v5:
            // Version 4/5: 256KB total, may use extended addressing
            guard totalSize <= 262144 else {
                throw RuntimeError.corruptedStoryFile("v\(version.rawValue) file size \(totalSize) exceeds 256KB limit", location: SourceLocation.unknown)
            }
        case .v6, .v7:
            // Version 6/7: 512KB total, requires routine/string offsets
            guard totalSize <= 524288 else {
                throw RuntimeError.corruptedStoryFile("v\(version.rawValue) file size \(totalSize) exceeds 512KB limit", location: SourceLocation.unknown)
            }
        case .v8:
            // Version 8: 512KB total, modern extensions
            guard totalSize <= 524288 else {
                throw RuntimeError.corruptedStoryFile("v8 file size \(totalSize) exceeds 512KB limit", location: SourceLocation.unknown)
            }
        }
    }

    /// Get maximum memory size for Z-Machine version
    static func getMaxMemorySize(for version: ZMachineVersion) -> UInt32 {
        switch version {
        case .v3:
            return 131072      // 128KB
        case .v4, .v5:
            return 262144      // 256KB
        case .v6, .v7, .v8:
            return 524288      // 512KB
        }
    }

    private func loadGameData() throws {
        // Load global variables from dynamic memory
        try loadGlobals()

        // Load object tree from static memory
        // Convert absolute object table address to offset within static memory
        let objectTableOffset = header.objectTableAddress - header.staticMemoryBase

        guard objectTableOffset < UInt32(staticMemory.count) else {
            throw RuntimeError.corruptedStoryFile("Object table offset \(objectTableOffset) exceeds static memory size \(staticMemory.count)", location: SourceLocation.unknown)
        }

        try objectTree.load(from: staticMemory, version: version, objectTableAddress: UInt32(objectTableOffset), staticMemoryBase: header.staticMemoryBase, dictionaryAddress: header.dictionaryAddress)

        // Load dictionary from static memory
        // Convert absolute dictionary address to offset within static memory
        let dictionaryOffset = header.dictionaryAddress - header.staticMemoryBase

        guard dictionaryOffset < UInt32(staticMemory.count) else {
            throw RuntimeError.corruptedStoryFile("Dictionary offset \(dictionaryOffset) exceeds static memory size \(staticMemory.count)", location: SourceLocation.unknown)
        }

        try dictionary.load(from: staticMemory, dictionaryAddress: UInt32(dictionaryOffset))

        // Load abbreviation table from static memory
        try loadAbbreviationTable()
    }

    private func loadAbbreviationTable() throws {
        // Clear existing abbreviation table
        abbreviationTable.removeAll()

        // Skip loading if no abbreviation table is defined
        guard header.abbreviationTableAddress > 0 else {
            // Initialize empty table for consistency
            abbreviationTable = Array(repeating: 0, count: 96)
            return
        }

        // Determine which memory region contains the abbreviation table
        let abbrevAddress = header.abbreviationTableAddress
        let abbrevData: Data
        let abbrevOffset: Int

        if abbrevAddress < header.staticMemoryBase {
            // Abbreviation table is in dynamic memory
            guard abbrevAddress < UInt32(dynamicMemory.count) else {
                throw RuntimeError.corruptedStoryFile("Abbreviation table address \(abbrevAddress) exceeds dynamic memory size", location: SourceLocation.unknown)
            }
            abbrevData = dynamicMemory
            abbrevOffset = Int(abbrevAddress)
        } else if abbrevAddress < header.highMemoryBase {
            // Abbreviation table is in static memory
            let staticOffset = abbrevAddress - header.staticMemoryBase
            guard staticOffset < UInt32(staticMemory.count) else {
                throw RuntimeError.corruptedStoryFile("Abbreviation table offset \(staticOffset) exceeds static memory size", location: SourceLocation.unknown)
            }
            abbrevData = staticMemory
            abbrevOffset = Int(staticOffset)
        } else {
            // Abbreviation table is in high memory
            let highOffset = abbrevAddress - header.highMemoryBase
            guard highOffset < UInt32(highMemory.count) else {
                throw RuntimeError.corruptedStoryFile("Abbreviation table offset \(highOffset) exceeds high memory size", location: SourceLocation.unknown)
            }
            abbrevData = highMemory
            abbrevOffset = Int(highOffset)
        }

        // Load 96 abbreviation entries (32 for each abbreviation type A0, A1, A2)
        // Each entry is a word address pointing to the abbreviated string
        let abbrevTableSize = 96 * 2  // 96 words = 192 bytes
        guard abbrevOffset + abbrevTableSize <= abbrevData.count else {
            throw RuntimeError.corruptedStoryFile("Abbreviation table extends beyond memory region", location: SourceLocation.unknown)
        }

        abbreviationTable.reserveCapacity(96)
        for i in 0..<96 {
            let entryOffset = abbrevOffset + (i * 2)
            let entryValue = (UInt16(abbrevData[entryOffset]) << 8) | UInt16(abbrevData[entryOffset + 1])

            // Convert word address to byte address using version-specific unpacking
            let packedAddress = UInt32(entryValue)
            let unpackedAddress = unpackStringAddress(packedAddress)
            abbreviationTable.append(unpackedAddress)
        }
    }

    private func loadGlobals() throws {
        let globalBase = header.globalTableAddress
        let globalCount = min(globals.count, Int((staticMemoryBase - globalBase) / 2))

        for i in 0..<Int(globalCount) {
            let address = globalBase + UInt32(i * 2)
            globals[i] = try readWord(at: address)
        }
    }

    // MARK: - Execution Engine

    /// Start VM execution
    ///
    /// Begins executing Z-Machine bytecode from the initial PC.
    /// This method runs the main execution loop until the game quits.
    ///
    /// - Throws: RuntimeError for execution failures
    public func run() throws {
        isRunning = true
        hasQuit = false

        while isRunning && !hasQuit {
            try executeInstruction()
        }
    }

    /// Execute a single instruction
    ///
    /// - Throws: RuntimeError for invalid instructions or operands
    public func executeInstruction() throws {
        guard programCounter < highMemoryBase + UInt32(highMemory.count) else {
            throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
        }

        let opcode = try readByte(at: programCounter)
        programCounter += 1

        try decodeAndExecuteInstruction(opcode)
    }

    private func decodeAndExecuteInstruction(_ opcode: UInt8) throws {
        // Determine instruction form based on opcode pattern
        if opcode >= 0xE0 {
            // VAR form instructions
            try executeVarInstruction(opcode)
        } else if opcode >= 0xB0 {
            // 0OP form instructions
            try execute0OPInstruction(opcode)
        } else if opcode >= 0x80 {
            // 1OP form instructions
            try execute1OPInstruction(opcode)
        } else {
            // 2OP form instructions
            try execute2OPInstruction(opcode)
        }
    }

    // MARK: - Memory Access

    /// Read a byte from memory
    ///
    /// - Parameter address: Memory address to read from
    /// - Returns: Byte value at the address
    /// - Throws: RuntimeError for invalid memory access
    public func readByte(at address: UInt32) throws -> UInt8 {
        // Determine which memory region contains the address
        if address < staticMemoryBase {
            // Dynamic memory (read/write)
            guard address < UInt32(dynamicMemory.count) else {
                throw RuntimeError.invalidMemoryAccess(Int(address), location: SourceLocation.unknown)
            }
            return dynamicMemory[Int(address)]
        } else if address < highMemoryBase {
            // Static memory (read-only)
            let staticOffset = address - staticMemoryBase
            guard staticOffset < UInt32(staticMemory.count) else {
                throw RuntimeError.invalidMemoryAccess(Int(address), location: SourceLocation.unknown)
            }
            return staticMemory[Int(staticOffset)]
        } else {
            // High memory (executable code and compressed strings)
            let highOffset = address - highMemoryBase
            guard highOffset < UInt32(highMemory.count) else {
                throw RuntimeError.invalidMemoryAccess(Int(address), location: SourceLocation.unknown)
            }
            return highMemory[Int(highOffset)]
        }
    }

    /// Write a byte to memory
    ///
    /// - Parameters:
    ///   - value: Byte value to write
    ///   - address: Memory address to write to
    /// - Throws: RuntimeError for invalid memory access or write to read-only memory
    public func writeByte(_ value: UInt8, at address: UInt32) throws {
        // Only dynamic memory is writable
        guard address < staticMemoryBase else {
            throw RuntimeError.invalidMemoryAccess(Int(address), location: SourceLocation.unknown)
        }

        guard address < UInt32(dynamicMemory.count) else {
            throw RuntimeError.invalidMemoryAccess(Int(address), location: SourceLocation.unknown)
        }

        dynamicMemory[Int(address)] = value
    }

    /// Read a word (16-bit big-endian) from memory
    ///
    /// - Parameter address: Memory address to read from
    /// - Returns: Word value at the address
    /// - Throws: RuntimeError for invalid memory access
    public func readWord(at address: UInt32) throws -> UInt16 {
        // Check for address overflow before reading two bytes
        guard address < UInt32.max else {
            throw RuntimeError.invalidMemoryAccess(Int(address), location: SourceLocation.unknown)
        }

        let highByte = try readByte(at: address)
        let lowByte = try readByte(at: address + 1)
        return (UInt16(highByte) << 8) | UInt16(lowByte)
    }

    /// Write a word (16-bit big-endian) to memory
    ///
    /// - Parameters:
    ///   - value: Word value to write
    ///   - address: Memory address to write to
    /// - Throws: RuntimeError for invalid memory access or write to read-only memory
    public func writeWord(_ value: UInt16, at address: UInt32) throws {
        // Check for address overflow before writing two bytes
        guard address < UInt32.max else {
            throw RuntimeError.invalidMemoryAccess(Int(address), location: SourceLocation.unknown)
        }

        try writeByte(UInt8((value >> 8) & 0xFF), at: address)
        try writeByte(UInt8(value & 0xFF), at: address + 1)
    }

    /// Get the memory region that contains an address
    ///
    /// - Parameter address: Memory address to check
    /// - Returns: Memory region type
    internal func getMemoryRegion(for address: UInt32) -> MemoryRegion {
        if address < staticMemoryBase {
            return .dynamic
        } else if address < highMemoryBase {
            return .static
        } else {
            return .high
        }
    }

    /// Memory region enumeration
    internal enum MemoryRegion {
        case dynamic    // Read/write, contains globals and object changes
        case `static`   // Read-only, contains dictionary and object table
        case high       // Execute-only, contains code and compressed strings
    }

    // MARK: - Stack Operations

    /// Push a value onto the evaluation stack
    ///
    /// - Parameter value: Value to push
    /// - Throws: RuntimeError for stack overflow
    public func pushStack(_ value: Int16) throws {
        guard evaluationStack.count < 1024 else {
            throw RuntimeError.stackOverflow(location: SourceLocation.unknown)
        }
        evaluationStack.append(value)
    }

    /// Pop a value from the evaluation stack
    ///
    /// - Returns: Popped value
    /// - Throws: RuntimeError for stack underflow
    public func popStack() throws -> Int16 {
        guard !evaluationStack.isEmpty else {
            throw RuntimeError.stackUnderflow(location: SourceLocation.unknown)
        }
        return evaluationStack.removeLast()
    }

    // MARK: - Text I/O

    /// Output text to the current output stream
    ///
    /// - Parameter text: Text to output
    public func outputText(_ text: String) {
        outputBuffer += text
        outputDelegate?.didOutputText(text)
    }

    /// Read input from the current input stream
    ///
    /// - Returns: Input text from user
    public func readInput() -> String {
        return inputDelegate?.requestInput() ?? ""
    }

    /// Read input with timeout support for Z-Machine v4+
    ///
    /// Implements proper Z-Machine timeout behavior:
    /// - If timeout occurs, calls the timeout routine
    /// - If timeout routine returns 0, restarts input with same timeout
    /// - If timeout routine returns non-zero, terminates with empty input
    ///
    /// - Parameters:
    ///   - timeLimit: Time limit in tenths of seconds (deciseconds)
    ///   - timeRoutine: Packed address of routine to call on timeout
    /// - Returns: Input text from user (empty string if timeout terminates input)
    private func readInputWithTimeout(timeLimit: Int16, timeRoutine: UInt32) -> String {
        // Convert deciseconds to seconds
        let timeoutSeconds = TimeInterval(timeLimit) / 10.0

        // Validate timeout routine address
        guard timeRoutine > 0 else {
            // No valid timeout routine - fall back to normal input
            return readInput()
        }

        // Unpack the timeout routine address
        let unpackedRoutineAddress = unpackAddress(timeRoutine, type: .routine)

        // Loop until input is received or timeout routine terminates input
        while true {
            // Request input with timeout from delegate
            guard let inputDelegate = inputDelegate else {
                return "" // No input delegate available
            }

            let (input, timedOut) = inputDelegate.requestInputWithTimeout(timeLimit: timeoutSeconds)

            if !timedOut, let actualInput = input {
                // Got input before timeout - return it
                return actualInput
            }

            // Timeout occurred - call timeout routine
            do {
                let timeoutResult = try callRoutine(unpackedRoutineAddress, arguments: [])

                if timeoutResult == 0 {
                    // Timeout routine returned 0 - continue waiting for input
                    // The loop will restart with the same timeout
                    continue
                } else {
                    // Timeout routine returned non-zero - terminate with empty input
                    return ""
                }
            } catch {
                // Error calling timeout routine - fall back to empty input
                outputDelegate?.didOutputText("[Timeout routine error: \(error)]")
                return ""
            }
        }
    }

    // MARK: - I/O Instructions

    /// Execute READ/SREAD instruction (0xE4) for player input
    ///
    /// Reads player input into a text buffer and parses it into a parse buffer.
    /// Follows authentic Z-Machine buffer formats for all versions.
    ///
    /// - Parameters:
    ///   - textBuffer: Address of text buffer in dynamic memory
    ///   - parseBuffer: Address of parse buffer in dynamic memory
    ///   - timeLimit: Time limit in tenths of seconds (v4+ only)
    ///   - timeRoutine: Routine to call on timeout (v4+ only)
    /// - Throws: RuntimeError for invalid buffer access
    func executeReadInstruction(textBuffer: UInt32, parseBuffer: UInt32, timeLimit: Int16, timeRoutine: UInt32) throws {
        // Validate version compatibility first
        if version.rawValue >= 4 && timeLimit > 0 && timeRoutine > 0 {
            // Validate timeout routine address is reasonable
            guard timeRoutine < UInt32(storyData.count) else {
                throw RuntimeError.invalidMemoryAccess(Int(timeRoutine), location: SourceLocation.unknown)
            }
        }

        // Validate buffer addresses are in dynamic memory (writable region)
        guard textBuffer < staticMemoryBase && parseBuffer < staticMemoryBase else {
            throw RuntimeError.invalidMemoryAccess(Int(max(textBuffer, parseBuffer)), location: SourceLocation.unknown)
        }

        // Validate buffer addresses are within bounds
        guard textBuffer < UInt32(dynamicMemory.count) && parseBuffer < UInt32(dynamicMemory.count) else {
            throw RuntimeError.invalidMemoryAccess(Int(max(textBuffer, parseBuffer)), location: SourceLocation.unknown)
        }

        // Read and validate text buffer format - byte 0 contains max length
        let maxTextLength = try readByte(at: textBuffer)
        guard maxTextLength > 0 else {
            throw RuntimeError.invalidMemoryAccess(Int(textBuffer), location: SourceLocation.unknown)
        }

        // Ensure text buffer has enough space for the specified length
        let requiredTextBufferSize = version.rawValue <= 4 ? UInt32(maxTextLength) + 1 : UInt32(maxTextLength) + 2
        guard textBuffer + requiredTextBufferSize <= UInt32(dynamicMemory.count) else {
            throw RuntimeError.invalidMemoryAccess(Int(textBuffer + requiredTextBufferSize - 1), location: SourceLocation.unknown)
        }

        // Read and validate parse buffer format - byte 0 contains max word count
        let maxWordCount = try readByte(at: parseBuffer)
        guard maxWordCount > 0 else {
            throw RuntimeError.invalidMemoryAccess(Int(parseBuffer), location: SourceLocation.unknown)
        }

        // Ensure parse buffer has enough space for the specified word count
        // Format: max_words(1) + current_words(1) + entries(maxWords * 4)
        let requiredParseBufferSize = UInt32(2 + maxWordCount * 4)
        guard parseBuffer + requiredParseBufferSize <= UInt32(dynamicMemory.count) else {
            throw RuntimeError.invalidMemoryAccess(Int(parseBuffer + requiredParseBufferSize - 1), location: SourceLocation.unknown)
        }

        // Handle timeout for v4+ versions
        let inputText: String
        if version.rawValue >= 4 && timeLimit > 0 && timeRoutine > 0 {
            // v4+ timeout support: attempt to get input with timeout
            inputText = readInputWithTimeout(timeLimit: timeLimit, timeRoutine: timeRoutine).lowercased()
        } else {
            // No timeout or v1-3: standard input
            inputText = readInput().lowercased()
        }

        // Convert input to ZSCII and truncate to buffer size
        let zsciiInput = convertToZSCII(inputText)
        let truncatedInput = Array(zsciiInput.prefix(Int(maxTextLength)))

        // Store input in version-specific buffer format
        if version.rawValue <= 4 {
            // v1-4: Text buffer format: [max_length][text...] (no length byte)
            // Store text directly starting at textBuffer + 1
            for (index, char) in truncatedInput.enumerated() {
                try writeByte(char, at: textBuffer + 1 + UInt32(index))
            }
            // Null-terminate the input for v1-4
            if truncatedInput.count < maxTextLength {
                try writeByte(0, at: textBuffer + 1 + UInt32(truncatedInput.count))
            }
        } else {
            // v5+: Text buffer format: [max_length][current_length][text...]
            // Store length at textBuffer + 1, text starts at textBuffer + 2
            try writeByte(UInt8(truncatedInput.count), at: textBuffer + 1)
            for (index, char) in truncatedInput.enumerated() {
                try writeByte(char, at: textBuffer + 2 + UInt32(index))
            }
        }

        // Tokenize the input into parse buffer
        // Note: If input is empty due to timeout, this will create an empty parse buffer
        try tokenizeText(textBuffer: textBuffer, parseBuffer: parseBuffer, dictionary: 0, flags: 0)
    }

    /// Execute TOKENISE instruction (0x1B/0xFB) for text parsing
    ///
    /// Parses existing text in a buffer into words without reading new input.
    /// Uses dictionary for word lookup and stores results in parse buffer.
    ///
    /// - Parameters:
    ///   - textBuffer: Address of text buffer containing text to parse
    ///   - parseBuffer: Address of parse buffer to store results
    ///   - dictionary: Address of dictionary (0 = use default)
    ///   - flags: Control flags for parsing behavior
    /// - Throws: RuntimeError for invalid buffer access or dictionary
    func executeTokeniseInstruction(textBuffer: UInt32, parseBuffer: UInt32, dictionary: UInt32, flags: UInt8) throws {
        // Validate buffer addresses are in dynamic memory (writable region)
        guard textBuffer < staticMemoryBase && parseBuffer < staticMemoryBase else {
            throw RuntimeError.invalidMemoryAccess(Int(max(textBuffer, parseBuffer)), location: SourceLocation.unknown)
        }

        // Validate buffer addresses are within bounds
        guard textBuffer < UInt32(dynamicMemory.count) && parseBuffer < UInt32(dynamicMemory.count) else {
            throw RuntimeError.invalidMemoryAccess(Int(max(textBuffer, parseBuffer)), location: SourceLocation.unknown)
        }

        // Validate dictionary address if provided
        if dictionary != 0 {
            guard dictionary >= staticMemoryBase && dictionary < staticMemoryBase + UInt32(staticMemory.count) else {
                throw RuntimeError.invalidMemoryAccess(Int(dictionary), location: SourceLocation.unknown)
            }
        }

        // Validate flag bits - only bits 0-1 are defined, others should be 0 for strict compliance
        let definedFlagBits: UInt8 = 0x03  // Bits 0 and 1
        let undefinedBits = flags & ~definedFlagBits
        if undefinedBits != 0 {
            // Log warning about undefined flag bits but continue processing
            outputDelegate?.didOutputText("[Warning: TOKENISE instruction uses undefined flag bits: 0x\(String(undefinedBits, radix: 16, uppercase: true))]")
        }

        try tokenizeText(textBuffer: textBuffer, parseBuffer: parseBuffer, dictionary: dictionary, flags: flags)
    }

    /// Tokenize text from text buffer into parse buffer
    ///
    /// - Parameters:
    ///   - textBuffer: Address of text buffer (version-dependent format)
    ///   - parseBuffer: Address of parse buffer (format: max_words, current_words, entries...)
    ///   - dictionary: Dictionary address (0 = use default)
    ///   - flags: Control flags for parsing behavior
    /// - Throws: RuntimeError for buffer access errors
    private func tokenizeText(textBuffer: UInt32, parseBuffer: UInt32, dictionary: UInt32, flags: UInt8) throws {
        // Read text buffer contents based on version
        let textLength: UInt8
        let textStartAddress: UInt32

        if version.rawValue <= 4 {
            // v1-4: Text buffer format: [max_length][text...] (null-terminated)
            // Scan for null terminator to find length
            let maxLength = try readByte(at: textBuffer)
            var length: UInt8 = 0
            textStartAddress = textBuffer + 1

            // Validate we can read up to maxLength characters
            guard textBuffer + 1 + UInt32(maxLength) <= UInt32(dynamicMemory.count) else {
                throw RuntimeError.invalidMemoryAccess(Int(textBuffer + 1 + UInt32(maxLength)), location: SourceLocation.unknown)
            }

            while length < maxLength {
                let char = try readByte(at: textStartAddress + UInt32(length))
                if char == 0 { break }
                length += 1
            }
            textLength = length
        } else {
            // v5+: Text buffer format: [max_length][current_length][text...]
            let maxLength = try readByte(at: textBuffer)
            textLength = try readByte(at: textBuffer + 1)

            // Validate current length doesn't exceed maximum length
            guard textLength <= maxLength else {
                throw RuntimeError.invalidMemoryAccess(Int(textBuffer + 1), location: SourceLocation.unknown)
            }

            // Validate we can read the specified number of characters
            guard textBuffer + 2 + UInt32(textLength) <= UInt32(dynamicMemory.count) else {
                throw RuntimeError.invalidMemoryAccess(Int(textBuffer + 2 + UInt32(textLength)), location: SourceLocation.unknown)
            }
            textStartAddress = textBuffer + 2
        }

        guard textLength > 0 else {
            // Empty input - clear parse buffer
            try writeByte(0, at: parseBuffer + 1)
            return
        }

        // Read text data
        var textData: [UInt8] = []
        for i in 0..<textLength {
            let char = try readByte(at: textStartAddress + UInt32(i))
            textData.append(char)
        }

        // Convert ZSCII to string for processing
        let inputString = convertFromZSCII(textData)

        // Parse words using Z-Machine word separation rules
        let words = parseWordsFromInput(inputString)

        // Get maximum word count from parse buffer
        let maxWords = try readByte(at: parseBuffer)
        let actualWordCount = min(words.count, Int(maxWords))

        // Store word count
        try writeByte(UInt8(actualWordCount), at: parseBuffer + 1)

        // Process each word
        for (index, wordInfo) in words.prefix(actualWordCount).enumerated() {
            let entryAddress = parseBuffer + 2 + UInt32(index * 4)

            // Look up word in dictionary (unless flags prevent it)
            var dictionaryAddress: UInt16 = 0
            if (flags & 0x01) == 0 {  // Bit 0: Skip dictionary lookup
                dictionaryAddress = lookupWordInDictionary(wordInfo.text, dictionaryAddr: dictionary)

                // Bit 1: Flag unrecognized words with special value instead of 0
                if dictionaryAddress == 0 && (flags & 0x02) != 0 {
                    dictionaryAddress = 1  // Special value for unrecognized words
                }
            }
            // Note: Bits 2-7 are reserved and should be ignored

            // Store word entry: dictionary_addr(2), length(1), position(1)
            try writeWord(dictionaryAddress, at: entryAddress)
            try writeByte(UInt8(wordInfo.length), at: entryAddress + 2)
            try writeByte(UInt8(wordInfo.position + 1), at: entryAddress + 3) // 1-based position
        }
    }

    /// Word information for parsing
    private struct WordInfo {
        let text: String
        let length: Int
        let position: Int
    }

    /// Parse input string into words following Z-Machine rules
    ///
    /// Z-Machine word separation uses dictionary separators and whitespace as delimiters.
    /// Multiple consecutive separators are treated as single separators.
    ///
    /// - Parameter input: Input string to parse
    /// - Returns: Array of word information
    private func parseWordsFromInput(_ input: String) -> [WordInfo] {
        var words: [WordInfo] = []
        var currentWord = ""
        var wordStart = 0

        for (index, char) in input.enumerated() {
            let charByte = char.asciiValue ?? 32 // Default to space for non-ASCII

            // Check if character is a separator (dictionary separators + whitespace)
            if dictionary.isSeparator(charByte) || char.isWhitespace {
                // Found separator - end current word if any
                if !currentWord.isEmpty {
                    words.append(WordInfo(text: currentWord.lowercased(), length: currentWord.count, position: wordStart))
                    currentWord = ""
                }
            } else {
                // Character is part of word
                if currentWord.isEmpty {
                    wordStart = index
                }
                currentWord.append(char)
            }
        }

        // Handle final word
        if !currentWord.isEmpty {
            words.append(WordInfo(text: currentWord.lowercased(), length: currentWord.count, position: wordStart))
        }

        return words
    }

    /// Look up word in dictionary
    ///
    /// - Parameters:
    ///   - word: Word to look up (already lowercased)
    ///   - dictionaryAddr: Dictionary address (0 = use default)
    /// - Returns: Dictionary entry address (0 if not found)
    private func lookupWordInDictionary(_ word: String, dictionaryAddr: UInt32) -> UInt16 {
        // Use default dictionary if none specified
        let dict = dictionaryAddr == 0 ? dictionary : loadAlternateDictionary(at: dictionaryAddr)

        // Truncate word to dictionary word length before encoding
        // Z-Machine dictionary words are limited by the encoding format:
        // - v1-3: 4 bytes = 2 words = 6 Z-characters = ~6 ASCII characters
        // - v4+:  6 bytes = 3 words = 9 Z-characters = ~9 ASCII characters
        let maxWordLength = version.rawValue >= 4 ? 9 : 6
        let truncatedWord = String(word.prefix(maxWordLength))

        // Look up truncated word in dictionary
        if let entry = dict.lookup(truncatedWord) {
            // Calculate absolute dictionary entry address
            // entry.address is offset within dictionary data
            let baseDictionaryAddress = dictionaryAddr == 0 ? header.dictionaryAddress : dictionaryAddr
            let absoluteAddress = baseDictionaryAddress + UInt32(entry.address)
            return UInt16(absoluteAddress & 0xFFFF) // Truncate to 16 bits
        }

        return 0 // Word not found
    }

    /// Load alternate dictionary (simplified implementation)
    private func loadAlternateDictionary(at address: UInt32) -> Dictionary {
        // For now, just return the main dictionary
        // Real implementation would parse dictionary at specified address
        return dictionary
    }

    /// Convert string to ZSCII byte array
    ///
    /// - Parameter text: Input text string
    /// - Returns: ZSCII byte array
    private func convertToZSCII(_ text: String) -> [UInt8] {
        // Simplified ZSCII conversion - handle basic ASCII
        return text.compactMap { char in
            let scalar = char.unicodeScalars.first?.value ?? 0
            // Basic ZSCII mapping for printable ASCII
            if scalar >= 32 && scalar <= 126 {
                return UInt8(scalar)
            }
            return nil // Skip non-printable characters
        }
    }

    /// Convert ZSCII byte array to string
    ///
    /// - Parameter zsciiData: ZSCII byte array
    /// - Returns: Decoded string
    private func convertFromZSCII(_ zsciiData: [UInt8]) -> String {
        // Simplified ZSCII conversion - handle basic ASCII
        return String(zsciiData.compactMap { byte in
            if byte >= 32 && byte <= 126 {
                // ASCII printable characters (32-126) are guaranteed valid Unicode scalars
                return Character(UnicodeScalar(UInt32(byte)).unsafelyUnwrapped)
            }
            return nil
        })
    }

    // MARK: - Game Control

    /// Quit the game
    public func quit() {
        hasQuit = true
        isRunning = false
        outputDelegate?.didQuit()
    }

    /// Restart the game
    public func restart() throws {
        // Reset VM state
        setupInitialState()
        programCounter = unpackRoutineAddress(header.initialPC)

        // Reset dynamic memory to initial state from story file
        let dynamicSize = Int(staticMemoryBase)
        guard dynamicSize <= storyData.count else {
            throw RuntimeError.corruptedStoryFile("Invalid dynamic memory size during restart", location: SourceLocation.unknown)
        }
        dynamicMemory = storyData.subdata(in: 0..<dynamicSize)

        // Reload global variables from story file
        try loadGlobals()

        // Reload object tree to reset all object states
        let objectTableOffset = header.objectTableAddress - header.staticMemoryBase
        try objectTree.load(from: staticMemory, version: version, objectTableAddress: UInt32(objectTableOffset), staticMemoryBase: header.staticMemoryBase)

        // Reload dictionary (though it shouldn't change)
        let dictionaryOffset = header.dictionaryAddress - header.staticMemoryBase
        try dictionary.load(from: staticMemory, dictionaryAddress: UInt32(dictionaryOffset))

        // Reload abbreviation table
        try loadAbbreviationTable()
    }

    // MARK: - Address Unpacking

    /// Address type for unpacking
    enum AddressType {
        case routine
        case string
        case data
    }

    /// Unpack a packed address based on Z-Machine version and type
    ///
    /// Z-Machine addresses are packed (divided by version-specific scale factors) to allow
    /// addressing larger memory spaces. This method unpacks them back to actual byte addresses
    /// according to the ZIP interpreter specification.
    ///
    /// - Parameters:
    ///   - packedAddress: The packed address from the story file
    ///   - type: The type of address (affects v6/v7 offset calculation)
    /// - Returns: The actual byte address in memory
    internal func unpackAddress(_ packedAddress: UInt32, type: AddressType = .data) -> UInt32 {
        guard packedAddress > 0 else {
            return 0  // Null address stays null
        }

        let baseAddress: UInt32

        switch version {
        case .v3:
            // Version 3: multiply by 2 (word addressing)
            baseAddress = packedAddress * 2
        case .v4, .v5:
            // Version 4/5: multiply by 4 (quad addressing)
            baseAddress = packedAddress * 4
        case .v6, .v7:
            // Version 6/7: multiply by 4, then add version-specific offset
            baseAddress = packedAddress * 4
            switch type {
            case .routine:
                return baseAddress + header.routineOffset * 8
            case .string:
                return baseAddress + header.stringOffset * 8
            case .data:
                return baseAddress
            }
        case .v8:
            // Version 8: multiply by 8 (oct addressing)
            baseAddress = packedAddress * 8
        }

        return baseAddress
    }

    /// Unpack a routine address from the story file header format
    ///
    /// - Parameter packedAddress: The packed address from the story file header
    /// - Returns: The actual byte address in memory
    private func unpackRoutineAddress(_ packedAddress: UInt32) -> UInt32 {
        return unpackAddress(packedAddress, type: .routine)
    }

    /// Unpack a string address for text decoding
    ///
    /// - Parameter packedAddress: The packed string address
    /// - Returns: The actual byte address in memory
    internal func unpackStringAddress(_ packedAddress: UInt32) -> UInt32 {
        return unpackAddress(packedAddress, type: .string)
    }

    /// Validate that memory management is working correctly
    ///
    /// - Returns: True if memory management is working, false otherwise
    public func validateMemoryManagement() -> Bool {
        // Check that memory regions are properly initialized
        guard !dynamicMemory.isEmpty else {
            print("❌ Dynamic memory not initialized")
            return false
        }

        guard !staticMemory.isEmpty else {
            print("❌ Static memory not initialized")
            return false
        }

        guard !highMemory.isEmpty else {
            print("❌ High memory not initialized")
            return false
        }

        // Check that boundaries are correct
        guard staticMemoryBase > 64 else {
            print("❌ Static memory base (\(staticMemoryBase)) must be > 64")
            return false
        }

        guard highMemoryBase >= staticMemoryBase else {
            print("❌ High memory base (\(highMemoryBase)) must be >= static memory base (\(staticMemoryBase))")
            return false
        }

        // Check that memory regions match header
        guard dynamicMemory.count == Int(staticMemoryBase) else {
            print("❌ Dynamic memory size (\(dynamicMemory.count)) doesn't match static base (\(staticMemoryBase))")
            return false
        }

        guard staticMemory.count == Int(highMemoryBase - staticMemoryBase) else {
            print("❌ Static memory size (\(staticMemory.count)) doesn't match expected size (\(highMemoryBase - staticMemoryBase))")
            return false
        }

        // Test memory access operations
        do {
            // Test dynamic memory read/write
            let originalValue = try readByte(at: 0)
            try writeByte(42, at: 0)
            let newValue = try readByte(at: 0)
            try writeByte(originalValue, at: 0) // restore

            guard newValue == 42 else {
                print("❌ Dynamic memory write/read test failed")
                return false
            }

            // Test static memory read (should work)
            _ = try readByte(at: staticMemoryBase)

            // Test high memory read (should work)
            _ = try readByte(at: highMemoryBase)

            print("✓ Memory management validation successful")
            print("  Dynamic: 0 - \(staticMemoryBase-1) (\(dynamicMemory.count) bytes)")
            print("  Static: \(staticMemoryBase) - \(highMemoryBase-1) (\(staticMemory.count) bytes)")
            print("  High: \(highMemoryBase) - \(highMemoryBase + UInt32(highMemory.count)-1) (\(highMemory.count) bytes)")
            return true

        } catch {
            print("❌ Memory access test failed: \(error)")
            return false
        }
    }
}

// MARK: - Supporting Types

/// Story file header structure
public struct StoryHeader {
    public let version: ZMachineVersion
    public let flags: UInt16
    public let highMemoryBase: UInt32
    public let initialPC: UInt32
    public let dictionaryAddress: UInt32
    public let objectTableAddress: UInt32
    public let globalTableAddress: UInt32
    public let staticMemoryBase: UInt32
    public let abbreviationTableAddress: UInt32  // Abbreviation (FWORDS) table address (bytes 24-25)
    public let serialNumber: String
    public let checksum: UInt16
    public let routineOffset: UInt32  // v6/v7 routine offset
    public let stringOffset: UInt32   // v6/v7 string offset

    public init() {
        version = .v3
        flags = 0
        highMemoryBase = 0
        initialPC = 0
        dictionaryAddress = 0
        objectTableAddress = 0
        globalTableAddress = 0
        staticMemoryBase = 0
        abbreviationTableAddress = 0
        serialNumber = ""
        checksum = 0
        routineOffset = 0
        stringOffset = 0
    }

    public init(from data: Data) throws {
        guard data.count >= 64 else {
            throw RuntimeError.corruptedStoryFile("Header too small", location: SourceLocation.unknown)
        }

        // Parse header fields according to ZIP specification
        let versionByte = data[0]
        guard let zmVersion = ZMachineVersion(rawValue: versionByte) else {
            throw RuntimeError.corruptedStoryFile("Invalid version \(versionByte)", location: SourceLocation.unknown)
        }
        version = zmVersion

        // Flags (byte 1 for v3, bytes 1-2 for v4+)
        if zmVersion == .v3 {
            flags = UInt16(data[1])
        } else {
            flags = (UInt16(data[1]) << 8) | UInt16(data[2])
        }

        // High memory base (ENDLOD) - bytes 4-5
        highMemoryBase = (UInt32(data[4]) << 8) | UInt32(data[5])

        // Initial PC (START) - bytes 6-7, needs unpacking based on version
        let initialPCRaw = (UInt32(data[6]) << 8) | UInt32(data[7])
        initialPC = initialPCRaw

        // Dictionary address (VOCAB) - bytes 8-9
        dictionaryAddress = (UInt32(data[8]) << 8) | UInt32(data[9])

        // Object table address (OBJECT) - bytes 10-11
        objectTableAddress = (UInt32(data[10]) << 8) | UInt32(data[11])

        // Global variables address (GLOBAL) - bytes 12-13
        globalTableAddress = (UInt32(data[12]) << 8) | UInt32(data[13])

        // Static memory base (PURBOT) - bytes 14-15
        staticMemoryBase = (UInt32(data[14]) << 8) | UInt32(data[15])

        // Abbreviation table address (bytes 24-25) - Available in v2+, but we support v3+
        abbreviationTableAddress = (UInt32(data[24]) << 8) | UInt32(data[25])

        // Serial number (bytes 18-23) - 6 ASCII digits
        let serialData = data.subdata(in: 18..<24)
        serialNumber = String(data: serialData, encoding: .ascii) ?? "000000"

        // Checksum (bytes 28-29)
        checksum = (UInt16(data[28]) << 8) | UInt16(data[29])

        // Version-specific fields
        if zmVersion == .v6 || zmVersion == .v7 {
            // Routine and string offsets for v6/v7 (bytes 40-43)
            if data.count >= 44 {
                routineOffset = (UInt32(data[40]) << 8) | UInt32(data[41])
                stringOffset = (UInt32(data[42]) << 8) | UInt32(data[43])
            } else {
                routineOffset = 0
                stringOffset = 0
            }
        } else {
            routineOffset = 0
            stringOffset = 0
        }

        // Validate header fields according to ZIP specification
        try validateHeader(version: zmVersion, dataSize: UInt32(data.count))
    }

    /// Validate header fields according to ZIP interpreter specification
    private func validateHeader(version: ZMachineVersion, dataSize: UInt32) throws {
        // Check basic memory layout constraints
        guard staticMemoryBase >= 64 else {
            throw RuntimeError.corruptedStoryFile("Static memory base (\(staticMemoryBase)) must be >= 64", location: SourceLocation.unknown)
        }

        guard highMemoryBase >= staticMemoryBase else {
            throw RuntimeError.corruptedStoryFile("High memory base (\(highMemoryBase)) must be >= static memory base (\(staticMemoryBase))", location: SourceLocation.unknown)
        }

        guard highMemoryBase <= dataSize else {
            throw RuntimeError.corruptedStoryFile("High memory base (\(highMemoryBase)) exceeds file size (\(dataSize))", location: SourceLocation.unknown)
        }

        // Version-specific validation
        let maxMemorySize = ZMachine.getMaxMemorySize(for: version)
        guard dataSize <= maxMemorySize else {
            throw RuntimeError.corruptedStoryFile("File size (\(dataSize)) exceeds maximum for version \(version.rawValue) (\(maxMemorySize))", location: SourceLocation.unknown)
        }

        // Validate that essential tables are within bounds
        guard dictionaryAddress >= staticMemoryBase && dictionaryAddress < dataSize else {
            throw RuntimeError.corruptedStoryFile("Dictionary address (\(dictionaryAddress)) out of bounds", location: SourceLocation.unknown)
        }

        guard objectTableAddress >= staticMemoryBase && objectTableAddress < dataSize else {
            throw RuntimeError.corruptedStoryFile("Object table address (\(objectTableAddress)) out of bounds", location: SourceLocation.unknown)
        }

        guard globalTableAddress < staticMemoryBase else {
            throw RuntimeError.corruptedStoryFile("Global table address (\(globalTableAddress)) must be in dynamic memory", location: SourceLocation.unknown)
        }
    }
}

/// Stack frame for routine calls
internal struct StackFrame {
    let returnPC: UInt32
    let localCount: Int
    let locals: [UInt16]
    let evaluationStackBase: Int
}

/// Text output delegate for handling text display
public protocol TextOutputDelegate: AnyObject {
    func didOutputText(_ text: String)
    func didQuit()
}

/// Text input delegate for handling user input
///
/// ## Timeout Support (Z-Machine v4+)
///
/// The `requestInputWithTimeout` method should be implemented to support Z-Machine
/// timeout behavior according to the official specification:
///
/// ### Implementation Guidelines:
/// 1. **Start a timer** when the method is called with the specified timeout
/// 2. **Wait for user input** while the timer is running
/// 3. **Return immediately** if user provides input before timeout
/// 4. **Return timeout status** if no input received within time limit
///
/// ### Return Values:
/// - `(input: "user text", timedOut: false)` - User provided input before timeout
/// - `(input: nil, timedOut: true)` - Timeout occurred, no input received
///
/// ### Example Implementation:
/// ```swift
/// func requestInputWithTimeout(timeLimit: TimeInterval) -> (input: String?, timedOut: Bool) {
///     let startTime = Date()
///
///     while Date().timeIntervalSince(startTime) < timeLimit {
///         if let input = checkForInput() { // Non-blocking input check
///             return (input, false)
///         }
///         Thread.sleep(forTimeInterval: 0.01) // Brief pause to avoid busy waiting
///     }
///
///     return (nil, true) // Timeout occurred
/// }
/// ```
public protocol TextInputDelegate: AnyObject {
    func requestInput() -> String
    func requestInputWithTimeout(timeLimit: TimeInterval) -> (input: String?, timedOut: Bool)
}