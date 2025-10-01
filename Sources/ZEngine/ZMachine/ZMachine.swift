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
    public private(set) var storyData: Data = Data()

    /// Z-Machine version from story file header
    public private(set) var version: ZMachineVersion = .v3

    /// Story file header information
    public private(set) var header: StoryHeader = StoryHeader()

    // MARK: - Memory Management

    /// Dynamic memory region (read/write)
    internal var dynamicMemory: Data = Data()

    /// Static memory region (read-only)
    internal var staticMemory: Data = Data()

    /// High memory region (execute-only)
    internal var highMemory: Data = Data()

    /// Memory region boundaries
    private var staticMemoryBase: UInt32 = 0
    private var highMemoryBase: UInt32 = 0

    // MARK: - Execution State

    /// Program counter (instruction pointer)
    public internal(set) var programCounter: UInt32 = 0

    /// Call stack for routine calls
    public internal(set) var callStack: [StackFrame] = []

    /// Evaluation stack for computations
    public internal(set) var evaluationStack: [Int16] = []

    /// Random number generator with seed support
    private var randomGenerator: SeededRandomGenerator = SeededRandomGenerator()

    /// Global variables (240 words)
    internal var globals: [UInt16] = Array(repeating: 0, count: 240)

    /// Local variables for current routine
    public internal(set) var locals: [UInt16] = []

    // MARK: - Game State

    /// Current object tree
    public internal(set) var objectTree: ObjectTree = ObjectTree()

    /// Dictionary for parser
    public internal(set) var dictionary: Dictionary = Dictionary()

    /// Abbreviation table for text decompression (96 entries: 32 each for A0, A1, A2)
    public internal(set) var abbreviationTable: [UInt32] = []

    /// Unicode translation table for ZSCII to Unicode mapping (v5+)
    /// Maps ZSCII characters 155-223 to Unicode code points
    public internal(set) var unicodeTranslationTable: [UInt32: UInt32] = [:]

    /// Text output buffer
    private var outputBuffer: String = ""

    /// Input buffer for reading commands
    private var inputBuffer: String = ""

    /// VM execution state
    internal var isRunning: Bool = false
    internal var hasQuit: Bool = false

    // MARK: - Window Management

    /// Window manager for multiple window support (v4+)
    internal var windowManager: WindowManager?

    /// Window delegate for handling window operations
    public weak var windowDelegate: WindowDelegate?

    // MARK: - I/O Delegates

    /// Text output delegate
    public weak var outputDelegate: TextOutputDelegate?

    /// Text input delegate
    public weak var inputDelegate: TextInputDelegate?

    // MARK: - Sound System

    /// Sound manager for audio effects (v4+)
    internal var soundManager: SoundManager?

    /// Sound effects delegate
    public weak var soundDelegate: SoundDelegate?

    // MARK: - Save/Restore System

    /// Save game delegate for handling save/restore operations
    public weak var saveGameDelegate: SaveGameDelegate?

    /// UNDO save state for RAM-based SAVE_UNDO/RESTORE_UNDO (v5+)
    private var undoState: QuetzalSaveState?

    // MARK: - Instruction Tracing

    /// Optional file handle for instruction tracing
    private var traceFileHandle: FileHandle?

    /// Enable instruction tracing to the specified file
    ///
    /// - Parameter url: URL of the trace file to write
    /// - Throws: Error if file cannot be created or opened
    public func enableTracing(to url: URL) throws {
        // Create the file if it doesn't exist, or truncate it if it does exist
        if FileManager.default.fileExists(atPath: url.path) {
            // File exists - remove it to truncate contents
            try FileManager.default.removeItem(at: url)
        }
        // Create a new empty file
        FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)

        traceFileHandle = try FileHandle(forWritingTo: url)

        // Write header to trace file
        let header = "# Z-Machine Instruction Trace\n# Format: <address>: <opcode> (<type>) <operands> [<bytes consumed>]\n\n"
        traceFileHandle?.write(header.data(using: .utf8) ?? Data())
    }

    /// Disable instruction tracing and close the trace file
    public func disableTracing() {
        traceFileHandle?.closeFile()
        traceFileHandle = nil
    }

    /// Current instruction being traced
    private var currentInstruction: InstructionTrace?
    /// PC after all operands have been decoded but before execution
    internal var postDecodePC: UInt32 = 0

    /// Instruction trace data structure
    private struct InstructionTrace {
        let startAddress: UInt32
        let opcode: UInt8
        var type: String = ""
        var operands: [Int16] = []
    }

    /// Begin tracing a new instruction
    internal func beginTrace(address: UInt32, opcode: UInt8) {
        guard traceFileHandle != nil else {
            return
        }

        currentInstruction = InstructionTrace(
            startAddress: address,
            opcode: opcode
        )
    }

    /// Add an operand to the current trace
    internal func traceOperand(_ operand: Int16) {
        guard traceFileHandle != nil else { return }
        currentInstruction?.operands.append(operand)
    }

    /// Set the instruction type for the current trace
    internal func traceType(_ type: String) {
        guard traceFileHandle != nil else { return }
        currentInstruction?.type = type
    }

    /// Set the store byte for the current instruction trace
    internal func traceStoreByte(_ storeByte: UInt8) {
        // Store byte tracking removed - no-op
    }

    /// Write a text line to the trace log
    internal func traceText(_ text: String) {
        guard let traceHandle = traceFileHandle else { return }
        let traceLine = "# \(text)\n"
        traceHandle.write(traceLine.data(using: .utf8) ?? Data())
        traceHandle.synchronizeFile()
    }

    /// Check if an instruction has a store byte based on opcode and type
    private func hasStoreByte(opcode: UInt8, type: String) -> Bool {
        switch type {
        case "1OP":
            let baseOpcode = opcode & 0x0F
            return [0x01, 0x02, 0x03, 0x04, 0x08, 0x0E, 0x0F].contains(baseOpcode) // GET_SIBLING, GET_CHILD, GET_PARENT, GET_PROP_LEN, CALL_1S, LOAD, NOT/CALL_1N

        case "2OP":
            let baseOpcode = opcode & 0x1F
            return [0x08, 0x09, 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19].contains(baseOpcode) // OR, AND, LOADW, LOADB, GET_PROP, GET_PROP_ADDR, GET_NEXT_PROP, ADD, SUB, MUL, DIV, MOD, CALL_2S

        case "2OP_VAR":
            let baseOpcode = opcode & 0x1F
            return [0x08, 0x09, 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19].contains(baseOpcode) // Same as 2OP

        case "VAR":
            let baseOpcode = opcode & 0x1F
            return [0x00, 0x07].contains(baseOpcode) // CALL/CALL_VS, RANDOM

        case "EXT":
            return [0x00, 0x01, 0x02, 0x03, 0x04, 0x09, 0x0A, 0x0B, 0x0C, 0x13].contains(opcode) // Extended opcodes with store bytes

        default:
            return false
        }
    }

    /// Get the mnemonic for an opcode based on its type and value
    private func getMnemonic(opcode: UInt8, type: String) -> String {
        switch type {
        case "0OP":
            switch opcode {
            case 0xB0: return "RTRUE"
            case 0xB1: return "RFALSE"
            case 0xB2: return "PRINT"
            case 0xB3: return "PRINT_RET"
            case 0xB4: return "NOP"
            case 0xB5: return "SAVE"
            case 0xB6: return "RESTORE"
            case 0xB7: return "RESTART"
            case 0xB8: return "RET_POPPED"
            case 0xB9: return "POP"
            case 0xBA: return "QUIT"
            case 0xBB: return "NEW_LINE"
            case 0xBC: return "SHOW_STATUS"
            case 0xBD: return "VERIFY"
            default: return "UNKNOWN_0OP"
            }

        case "1OP":
            let baseOpcode = opcode & 0x0F
            switch baseOpcode {
            case 0x00: return "JZ"
            case 0x01: return "GET_SIBLING"
            case 0x02: return "GET_CHILD"
            case 0x03: return "GET_PARENT"
            case 0x04: return "GET_PROP_LEN"
            case 0x05: return "INC"
            case 0x06: return "DEC"
            case 0x07: return "PRINT_ADDR"
            case 0x08: return "CALL_1S"
            case 0x09: return "REMOVE_OBJ"
            case 0x0A: return "PRINT_OBJ"
            case 0x0B: return "RET"
            case 0x0C: return "JUMP"
            case 0x0D: return "PRINT_PADDR"
            case 0x0E: return "LOAD"
            case 0x0F: return version.rawValue <= 4 ? "NOT" : "CALL_1N"
            default: return "UNKNOWN_1OP"
            }

        case "2OP":
            let baseOpcode = opcode & 0x1F
            switch baseOpcode {
            case 0x01: return "JE"
            case 0x02: return "JL"
            case 0x03: return "JG"
            case 0x04: return "DEC_CHK"
            case 0x05: return "INC_CHK"
            case 0x06: return "JIN"
            case 0x07: return "TEST"
            case 0x08: return "OR"
            case 0x09: return "AND"
            case 0x0A: return "TEST_ATTR"
            case 0x0B: return "SET_ATTR"
            case 0x0C: return "CLEAR_ATTR"
            case 0x0D: return "STORE"
            case 0x0E: return "INSERT_OBJ"
            case 0x0F: return "LOADW"
            case 0x10: return "LOADB"
            case 0x11: return "GET_PROP"
            case 0x12: return "GET_PROP_ADDR"
            case 0x13: return "GET_NEXT_PROP"
            case 0x14: return "ADD"
            case 0x15: return "SUB"
            case 0x16: return "MUL"
            case 0x17: return "DIV"
            case 0x18: return "MOD"
            case 0x19: return "CALL_2S"
            case 0x1A: return "CALL_2N"
            case 0x1B: return "SET_COLOUR"
            case 0x1C: return "THROW"
            default: return "UNKNOWN_2OP"
            }

        case "2OP_VAR":
            // VAR-encoded 2OP instructions (0xC0-0xDF) - use 2OP mnemonic table
            let baseOpcode = opcode & 0x1F
            switch baseOpcode {
            case 0x01: return "JE"
            case 0x02: return "JL"
            case 0x03: return "JG"
            case 0x04: return "DEC_CHK"
            case 0x05: return "INC_CHK"
            case 0x06: return "JIN"
            case 0x07: return "TEST"
            case 0x08: return "OR"
            case 0x09: return "AND"
            case 0x0A: return "TEST_ATTR"
            case 0x0B: return "SET_ATTR"
            case 0x0C: return "CLEAR_ATTR"
            case 0x0D: return "STORE"
            case 0x0E: return "INSERT_OBJ"
            case 0x0F: return "LOADW"
            case 0x10: return "LOADB"
            case 0x11: return "GET_PROP"
            case 0x12: return "GET_PROP_ADDR"
            case 0x13: return "GET_NEXT_PROP"
            case 0x14: return "ADD"
            case 0x15: return "SUB"
            case 0x16: return "MUL"
            case 0x17: return "DIV"
            case 0x18: return "MOD"
            case 0x19: return "CALL_2S"
            case 0x1A: return "CALL_2N"
            case 0x1B: return "SET_COLOUR"
            case 0x1C: return "THROW"
            default: return "UNKNOWN_2OP_VAR"
            }
        case "VAR":
            let baseOpcode = opcode & 0x1F
            switch baseOpcode {
            case 0x00: return version.rawValue <= 3 ? "CALL" : "CALL_VS"
            case 0x01: return "STOREW"
            case 0x02: return "STOREB"
            case 0x03: return "PUT_PROP"
            case 0x04: return "SREAD"
            case 0x05: return "PRINT_CHAR"
            case 0x06: return "PRINT_NUM"
            case 0x07: return "RANDOM"
            case 0x08: return "PUSH"
            case 0x09: return "PULL"
            case 0x0A: return "SPLIT_WINDOW"
            case 0x0B: return "SET_WINDOW"
            case 0x0C: return "CALL_VS2"
            case 0x0D: return "ERASE_WINDOW"
            case 0x0E: return "ERASE_LINE"
            case 0x0F: return "SET_CURSOR"
            case 0x10: return "GET_CURSOR"
            case 0x11: return "SET_TEXT_STYLE"
            case 0x12: return "BUFFER_MODE"
            case 0x13: return "OUTPUT_STREAM"
            case 0x14: return "INPUT_STREAM"
            case 0x15: return "SOUND_EFFECT"
            case 0x16: return "READ_CHAR"
            case 0x17: return "SCAN_TABLE"
            case 0x18: return version.rawValue >= 5 ? "NOT" : "UNKNOWN_VAR_0x18"
            case 0x19: return "CALL_VN"
            case 0x1A: return "CALL_VN2"
            case 0x1B: return "TOKENISE"
            case 0x1C: return "ENCODE_TEXT"
            case 0x1D: return "COPY_TABLE"
            case 0x1E: return "PRINT_TABLE"
            case 0x1F: return "CHECK_ARG_COUNT"
            default: return "UNKNOWN_VAR"
            }

        case "EXT":
            switch opcode {
            case 0x00: return "SAVE"
            case 0x01: return "RESTORE"
            case 0x02: return "LOG_SHIFT"
            case 0x03: return "ART_SHIFT"
            case 0x04: return "SET_FONT"
            case 0x05: return "DRAW_PICTURE"
            case 0x06: return "PICTURE_DATA"
            case 0x07: return "ERASE_PICTURE"
            case 0x08: return "SET_MARGINS"
            case 0x09: return "SAVE_UNDO"
            case 0x0A: return "RESTORE_UNDO"
            case 0x0B: return "PRINT_UNICODE"
            case 0x0C: return "CHECK_UNICODE"
            case 0x0D: return "SET_TRUE_COLOUR"
            case 0x10: return "MOVE_WINDOW"
            case 0x11: return "WINDOW_SIZE"
            case 0x12: return "WINDOW_STYLE"
            case 0x13: return "GET_WIND_PROP"
            case 0x14: return "SCROLL_WINDOW"
            case 0x15: return "POP_STACK"
            case 0x16: return "READ_MOUSE"
            case 0x17: return "MOUSE_WINDOW"
            case 0x18: return "PUSH_STACK"
            case 0x19: return "PUT_WIND_PROP"
            case 0x1A: return "PRINT_FORM"
            case 0x1B: return "MAKE_MENU"
            case 0x1C: return "PICTURE_TABLE"
            case 0x1D: return "BUFFER_SCREEN"
            default: return "UNKNOWN_EXT"
            }

        default:
            return "UNKNOWN"
        }
    }

    /// Write out the current instruction trace and clear it
    private func flushTrace(nextPC: UInt32) {
        guard let traceHandle = traceFileHandle,
              let instruction = currentInstruction else { return }

        // Read the actual bytes consumed by this instruction
        var bytesConsumed: [UInt8] = []
        for addr in instruction.startAddress..<nextPC {
            do {
                bytesConsumed.append(try readByte(at: addr))
            } catch {
                // If we can't read a byte, stop collecting
                break
            }
        }

        let operandStr = instruction.operands.map { String($0) }.joined(separator: ", ")
        let bytesStr = bytesConsumed.map { String(format: "0x%02X", $0) }.joined(separator: " ")
        let mnemonic = getMnemonic(opcode: instruction.opcode, type: instruction.type)

        let traceLine = "\(instruction.startAddress): 0x\(String(format: "%02X", instruction.opcode)) \(mnemonic) (\(instruction.type)) [\(operandStr)] [\(bytesStr)]\n"

//                              instruction.startAddress,
//                              instruction.opcode,
//                              instruction.type,
//                              operandStr,
//                              bytesStr)

        traceHandle.write(traceLine.data(using: .utf8) ?? Data())
        traceHandle.synchronizeFile() // Flush I/O

        currentInstruction = nil
    }

    // MARK: - Initialization

    public init() {
        // Initialize globals array to zeros (will be loaded from story file later)
        globals = Array(repeating: 0, count: 240)

        // Initialize VM components
        setupInitialState()
    }

    private func setupInitialState() {
        callStack.removeAll()
        evaluationStack.removeAll()
        locals.removeAll()
        // Don't clear globals here - they are loaded by loadGameData() and should persist
        // globals = Array(repeating: 0, count: 240)  // REMOVED - this was overwriting loaded globals
        // DON'T clear abbreviationTable here - it's loaded by loadGameData() and should persist!
        // abbreviationTable.removeAll()  // REMOVED - this was clearing the loaded abbreviation table
        unicodeTranslationTable.removeAll()
        programCounter = 0
        isRunning = false
        hasQuit = false
        outputBuffer = ""
        inputBuffer = ""

        // WindowManager is initialized after header parsing, not here
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

        // Initialize WindowManager after header parsing when version is known
        if version.rawValue >= 4 {
            windowManager = WindowManager(version: version)
            windowManager?.delegate = windowDelegate
        }

        // Initialize SoundManager for audio effects (v4+)
        if version.rawValue >= 4 {
            soundManager = SoundManager(version: version)
            soundManager?.setZMachine(self)
            soundManager?.delegate = soundDelegate
        }

        // Reset VM state but preserve important header values
        setupInitialState()

        // Set initial PC from header AFTER memory setup, respecting version-specific packing rules
        programCounter = resolveInitialProgramCounter()

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

    /// Resolve the initial program counter stored in the header to an executable byte address.
    private func resolveInitialProgramCounter() -> UInt32 {
        if version.rawValue <= 3 {
            // Versions 1-3 store the entry address directly in bytes
            return header.initialPC
        }

        // Versions 4+ store packed routine addresses that must be unpacked
        return unpackRoutineAddress(header.initialPC)
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

        // Use header values for memory boundaries
        staticMemoryBase = header.staticMemoryBase
        highMemoryBase = header.highMemoryBase

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
    public static func getMaxMemorySize(for version: ZMachineVersion) -> UInt32 {
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

        // Load object tree from appropriate memory region
        let objectTableAddress = header.objectTableAddress

        // Object tree needs access to entire story file since objects are in dynamic memory
        // but property tables are in static memory
        let objectData = storyData
        let objectTableOffset = objectTableAddress

        try objectTree.load(from: objectData, version: version, objectTableAddress: objectTableOffset, staticMemoryBase: header.staticMemoryBase, dictionaryAddress: header.dictionaryAddress)

        // Load dictionary from static memory
        // Convert absolute dictionary address to offset within static memory
        let dictionaryOffset = header.dictionaryAddress - header.staticMemoryBase

        guard dictionaryOffset < UInt32(staticMemory.count) else {
            throw RuntimeError.corruptedStoryFile("Dictionary offset \(dictionaryOffset) exceeds static memory size \(staticMemory.count)", location: SourceLocation.unknown)
        }

        try dictionary.load(from: staticMemory, dictionaryAddress: UInt32(dictionaryOffset), absoluteDictionaryAddress: header.dictionaryAddress, version: version)

        // Load abbreviation table from static memory
        try loadAbbreviationTable()

        // Load Unicode translation table for v5+
        if version.rawValue >= 5 {
            try loadUnicodeTranslationTable()
        }

        // Debug: Print decoded object short names now that all tables are loaded
        try printObjectShortNames()
    }

    /// Debug method to print decoded object short names
    private func printObjectShortNames() throws {
        // Commented out to reduce debug output
        /*
        print("DEBUG: === Decoding Object Short Names ===")

        // Check first 20 objects to see their short descriptions
        for objectNum in 1...20 {
            if let object = objectTree.getObject(UInt16(objectNum)) {
                let propertyTableOffset = object.getPropertyTableAddress()

                if propertyTableOffset > 0 {
                    // Calculate absolute address
                    let absoluteAddress = header.staticMemoryBase + UInt32(propertyTableOffset)

                    // Read text length
                    let textLength = try readByte(at: absoluteAddress)

                    if textLength > 0 {
                        // Read and decode the short description
                        let textAddress = absoluteAddress + 1
                        do {
                            let result = try readZString(at: textAddress)
                            print("DEBUG: Object \(objectNum) = \"\(result.string)\"")
                        } catch {
                            print("DEBUG: Object \(objectNum) - failed to decode: \(error)")
                        }
                    } else {
                        print("DEBUG: Object \(objectNum) = (no short name)")
                    }
                }
            }
        }
        print("DEBUG: === End Object Short Names ===")
        */
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

    /// Load Unicode translation table for ZSCII to Unicode mapping (v5+)
    private func loadUnicodeTranslationTable() throws {
        // Clear existing Unicode translation table
        unicodeTranslationTable.removeAll()

        // Skip loading if no Unicode table is defined
        guard header.unicodeTableAddress > 0 else {
            // Initialize default ZSCII to Unicode mappings (155-223 map to themselves)
            for zsciiChar in 155...223 {
                unicodeTranslationTable[UInt32(zsciiChar)] = UInt32(zsciiChar)
            }
            return
        }

        // Determine which memory region contains the Unicode table
        let unicodeAddress = header.unicodeTableAddress
        let unicodeData: Data
        let unicodeOffset: Int

        if unicodeAddress < header.staticMemoryBase {
            // Unicode table is in dynamic memory
            guard unicodeAddress < UInt32(dynamicMemory.count) else {
                throw RuntimeError.corruptedStoryFile("Unicode table address \(unicodeAddress) exceeds dynamic memory size", location: SourceLocation.unknown)
            }
            unicodeData = dynamicMemory
            unicodeOffset = Int(unicodeAddress)
        } else if unicodeAddress < header.highMemoryBase {
            // Unicode table is in static memory
            let staticOffset = unicodeAddress - header.staticMemoryBase
            guard staticOffset < UInt32(staticMemory.count) else {
                throw RuntimeError.corruptedStoryFile("Unicode table offset \(staticOffset) exceeds static memory size", location: SourceLocation.unknown)
            }
            unicodeData = staticMemory
            unicodeOffset = Int(staticOffset)
        } else {
            // Unicode table is in high memory
            let highOffset = unicodeAddress - header.highMemoryBase
            guard highOffset < UInt32(highMemory.count) else {
                throw RuntimeError.corruptedStoryFile("Unicode table offset \(highOffset) exceeds high memory size", location: SourceLocation.unknown)
            }
            unicodeData = highMemory
            unicodeOffset = Int(highOffset)
        }

        // Read Unicode table format:
        // Byte 0: Number of Unicode characters (N, max 69 for ZSCII range 155-223)
        guard unicodeOffset < unicodeData.count else {
            throw RuntimeError.corruptedStoryFile("Unicode table extends beyond memory region", location: SourceLocation.unknown)
        }

        let unicodeCount = unicodeData[unicodeOffset]

        // Validate Unicode count (ZSCII 155-223 = 69 possible characters)
        guard unicodeCount <= 69 else {
            throw RuntimeError.corruptedStoryFile("Unicode table count \(unicodeCount) exceeds maximum of 69", location: SourceLocation.unknown)
        }

        // Ensure we have enough data for the table
        let requiredSize = 1 + Int(unicodeCount) * 2  // Header byte + N words
        guard unicodeOffset + requiredSize <= unicodeData.count else {
            throw RuntimeError.corruptedStoryFile("Unicode table extends beyond memory region", location: SourceLocation.unknown)
        }

        // Load Unicode mappings for ZSCII characters 155 through (154 + unicodeCount)
        for i in 0..<Int(unicodeCount) {
            let entryOffset = unicodeOffset + 1 + (i * 2)
            let unicodeValue = (UInt32(unicodeData[entryOffset]) << 8) | UInt32(unicodeData[entryOffset + 1])
            let zsciiChar = UInt32(155 + i)

            // Store the mapping
            unicodeTranslationTable[zsciiChar] = unicodeValue
        }

        // For any ZSCII characters 155-223 not in the table, use default (self-mapping)
        for zsciiChar in Int(155 + unicodeCount)...223 {
            if unicodeTranslationTable[UInt32(zsciiChar)] == nil {
                unicodeTranslationTable[UInt32(zsciiChar)] = UInt32(zsciiChar)
            }
        }
    }

    private func loadGlobals() throws {
        let globalBase = header.globalTableAddress

        // Validate that global table is within dynamic memory
        guard globalBase < staticMemoryBase else {
            throw RuntimeError.corruptedStoryFile("Global table address (\(globalBase)) must be in dynamic memory (< \(staticMemoryBase))", location: SourceLocation.unknown)
        }

        // Calculate available space for globals, ensuring no division by zero
        let availableSpace = staticMemoryBase - globalBase
        guard availableSpace > 0 else {
            throw RuntimeError.corruptedStoryFile("No space available for global variables", location: SourceLocation.unknown)
        }

        let maxGlobalsFromSpace = Int(availableSpace / 2)  // Each global is 2 bytes
        let globalCount = min(globals.count, maxGlobalsFromSpace)

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

        let startPC = programCounter
        let opcode = try readByte(at: programCounter)
        programCounter += 1

        // Begin tracing this instruction
        beginTrace(address: startPC, opcode: opcode)

        // Set post-decode PC BEFORE instruction execution (after operands will be consumed)
        postDecodePC = programCounter

        // Decode and execute the instruction
        try decodeAndExecuteInstruction(opcode)

        // Use the post-decode PC for tracing
        flushTrace(nextPC: postDecodePC)
    }

    private func decodeAndExecuteInstruction(_ opcode: UInt8) throws {
        // Check for extended form first (V4+)
        if opcode == 0xBE && version.rawValue >= 4 {
            traceType("EXT")
            let extOpcode = try readByte(at: programCounter)
            programCounter += 1
            try executeExtendedInstruction(extOpcode)
            return
        }

        // Determine instruction form based on opcode bit patterns
        let topTwoBits = opcode & 0xC0  // Extract bits 7-6

        switch topTwoBits {
        case 0x80:  // 10xxxxxx - Short form
            let operandTypeBits = opcode & 0x30  // Extract bits 5-4
            if operandTypeBits == 0x30 {
                // Operand type = 11 (omitted) -> 0OP
                traceType("0OP")
                try execute0OPInstruction(opcode)
            } else {
                // Operand type != 11 -> 1OP
                traceType("1OP")
                try execute1OPInstruction(opcode)
            }

        case 0xC0:  // 11xxxxxx - Variable form
            let varTypeBit = opcode & 0x20  // Extract bit 5
            if varTypeBit == 0 {
                // Bit 5 = 0 -> 2OP instructions encoded in VAR space (C0-DF)
                traceType("2OP_VAR")
                try execute2OPVarInstruction(opcode)
            } else {
                // Bit 5 = 1 -> True VAR opcodes like CALL (E0-FF)
                traceType("VAR")
                try executeVarInstruction(opcode)
            }

        default:  // 00xxxxxx or 01xxxxxx - Long form (2OP)
            traceType("2OP")
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
    /// According to the Z-Machine specification, reading from an empty stack
    /// should return 0, not generate an error. This allows games to check
    /// the stack state without explicit stack management.
    ///
    /// - Returns: Popped value (0 if stack is empty)
    public func popStack() -> Int16 {
        guard !evaluationStack.isEmpty else {
            return 0  // Z-Machine spec: empty stack reads return 0
        }
        return evaluationStack.removeLast()
    }

    // MARK: - Text I/O

    /// Output text to the current output stream
    ///
    /// - Parameter text: Text to output
    public func outputText(_ text: String) {
        outputBuffer += text

        // Use window system if available (v4+), otherwise fall back to delegate
        if let windowManager = windowManager {
            windowManager.outputText(text)
        } else {
            outputDelegate?.didOutputText(text)
        }
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
        let maxTextLengthRaw = try readByte(at: textBuffer)
        // V1-V4: stored as (max-1), V5+: actual max
        let maxTextLength = version.rawValue <= 4 ? Int(maxTextLengthRaw) + 1 : Int(maxTextLengthRaw)
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
            var dictionaryAddress: UInt32 = 0
            if (flags & 0x01) == 0 {  // Bit 0: Skip dictionary lookup
                dictionaryAddress = lookupWordInDictionary(wordInfo.text, dictionaryAddr: dictionary)

                // Bit 1: Flag unrecognized words with special value instead of 0
                if dictionaryAddress == 0 && (flags & 0x02) != 0 {
                    dictionaryAddress = 1  // Special value for unrecognized words
                }
            }
            // Note: Bits 2-7 are reserved and should be ignored

            // Store word entry: dictionary_addr(2), length(1), position(1)
            try writeWord(UInt16(dictionaryAddress), at: entryAddress)
            try writeByte(UInt8(wordInfo.length), at: entryAddress + 2)
            // Position should be 1-based from start of text area in buffer
            // V1-V4: text starts at buffer[1], V5+: text starts at buffer[2]
            let positionInBuffer = wordInfo.position + 1  // Convert to 1-based
            try writeByte(UInt8(positionInBuffer), at: entryAddress + 3)
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
    private func lookupWordInDictionary(_ word: String, dictionaryAddr: UInt32) -> UInt32 {
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
            // Dictionary entry already contains absolute address
            return entry.address
        } else {
            return 0 // Word not found
        }
    }

    /// Load alternate dictionary (simplified implementation)
    private func loadAlternateDictionary(at address: UInt32) -> Dictionary {
        // For now, just return the main dictionary
        // Real implementation would parse dictionary at specified address
        return dictionary
    }

    /// Convert string to ZSCII byte array with Unicode translation support
    ///
    /// - Parameter text: Input text string
    /// - Returns: ZSCII byte array
    private func convertToZSCII(_ text: String) -> [UInt8] {
        return text.compactMap { char in
            let scalar = char.unicodeScalars.first?.value ?? 0

            // Basic ZSCII mapping for characters 0-154 (map directly)
            if scalar <= 154 {
                return UInt8(scalar)
            }

            // For v5+, try reverse Unicode translation for extended characters
            if version.rawValue >= 5 {
                if let zsciiChar = unicodeToZSCII(scalar) {
                    return zsciiChar
                }
            }

            // Fall back to basic ASCII mapping for printable characters
            if scalar >= 32 && scalar <= 126 {
                return UInt8(scalar)
            }

            return nil // Skip characters that can't be mapped
        }
    }

    /// Convert ZSCII byte array to string with Unicode translation support
    ///
    /// - Parameter zsciiData: ZSCII byte array
    /// - Returns: Decoded string
    private func convertFromZSCII(_ zsciiData: [UInt8]) -> String {
        return String(zsciiData.compactMap { byte in
            // For v5+, use Unicode translation table for extended ZSCII characters
            if version.rawValue >= 5 {
                let unicodeValue = zsciiToUnicode(byte)
                if let scalar = UnicodeScalar(unicodeValue) {
                    return Character(scalar)
                }
            }

            // Fall back to basic ASCII mapping
            if byte >= 32 && byte <= 126 {
                if let scalar = UnicodeScalar(UInt32(byte)) {
                    return Character(scalar)
                }
            }

            return nil // Skip invalid characters
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
        programCounter = resolveInitialProgramCounter()

        // Reset dynamic memory to initial state from story file
        let dynamicSize = Int(staticMemoryBase)
        guard dynamicSize <= storyData.count else {
            throw RuntimeError.corruptedStoryFile("Invalid dynamic memory size during restart", location: SourceLocation.unknown)
        }
        dynamicMemory = storyData.subdata(in: 0..<dynamicSize)

        // Reload global variables from story file
        try loadGlobals()

        // Reload object tree to reset all object states
        // Object tree needs access to entire story file since objects are in dynamic memory
        // but property tables are in static memory
        let objectTableAddress = header.objectTableAddress
        let objectData = storyData
        let objectTableOffset = objectTableAddress

        try objectTree.load(from: objectData, version: version, objectTableAddress: objectTableOffset, staticMemoryBase: header.staticMemoryBase, dictionaryAddress: header.dictionaryAddress)

        // Reload dictionary (though it shouldn't change)
        let dictionaryOffset = header.dictionaryAddress - header.staticMemoryBase
        try dictionary.load(from: staticMemory, dictionaryAddress: UInt32(dictionaryOffset), absoluteDictionaryAddress: header.dictionaryAddress, version: version)

        // Reload abbreviation table
        try loadAbbreviationTable()

        // Reload Unicode translation table for v5+
        if version.rawValue >= 5 {
            try loadUnicodeTranslationTable()
        }
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

    // MARK: - Save/Restore System

    /// Save current game state to Quetzal format
    ///
    /// Creates a complete save state including all VM state that needs to be preserved:
    /// - Story identification for save compatibility validation
    /// - Compressed memory delta (only changed dynamic memory)
    /// - Complete stack state (evaluation stack + call stack with locals)
    /// - Current program counter and execution context
    ///
    /// - Parameters:
    ///   - defaultName: Suggested filename for save file
    /// - Returns: True if save succeeded, false if cancelled or failed
    public func saveGame(defaultName: String = "save") -> Bool {
        guard let delegate = saveGameDelegate else {
            outputDelegate?.didOutputText("[No save delegate configured]")
            return false
        }

        guard let saveURL = delegate.requestSaveFileURL(defaultName: defaultName) else {
            // User cancelled save operation
            return false
        }

        do {
            // Capture current game state
            let saveState = try captureGameState()

            // Write Quetzal save file
            let quetzalData = try QuetzalWriter.writeQuetzalFile(saveState)

            // Write to disk
            try quetzalData.write(to: saveURL)

            // Notify delegate of successful save
            delegate.didSaveGame(to: saveURL)

            return true

        } catch {
            delegate.saveRestoreDidFail(operation: "save", error: error)
            return false
        }
    }

    /// Restore game state from Quetzal format
    ///
    /// Loads and validates a Quetzal save file, then restores the complete VM state:
    /// - Validates save compatibility with current story file
    /// - Decompresses and restores dynamic memory changes
    /// - Restores complete stack state and execution context
    /// - Resumes execution from the saved program counter
    ///
    /// - Returns: True if restore succeeded, false if cancelled or failed
    public func restoreGame() -> Bool {
        guard let delegate = saveGameDelegate else {
            outputDelegate?.didOutputText("[No save delegate configured]")
            return false
        }

        guard let restoreURL = delegate.requestRestoreFileURL() else {
            // User cancelled restore operation
            return false
        }

        do {
            // Read Quetzal save file
            let saveData = try Data(contentsOf: restoreURL)
            let saveState = try QuetzalReader.readQuetzalFile(saveData)

            // Validate save compatibility
            try validateSaveCompatibility(saveState.identification)

            // Restore VM state
            try restoreGameState(saveState)

            // Notify delegate of successful restore
            delegate.didRestoreGame(from: restoreURL)

            return true

        } catch {
            delegate.saveRestoreDidFail(operation: "restore", error: error)
            return false
        }
    }

    /// Save UNDO state for RAM-based save/restore (v5+)
    ///
    /// Creates a complete save state stored in memory for the SAVE_UNDO instruction.
    /// This allows games to implement features like multi-level undo without file I/O.
    ///
    /// - Throws: RuntimeError for state capture failures
    public func saveUndo() throws {
        guard version.rawValue >= 5 else {
            throw RuntimeError.unsupportedOperation("SAVE_UNDO not supported in version \(version.rawValue)", location: SourceLocation.unknown)
        }

        // Capture current state for UNDO
        undoState = try captureGameState()
    }

    /// Restore UNDO state from memory (v5+)
    ///
    /// Restores the VM state from the most recent SAVE_UNDO operation.
    /// This provides instant restore functionality without file system access.
    ///
    /// - Returns: True if UNDO state was available and restored, false if no UNDO state
    /// - Throws: RuntimeError for restore failures
    public func restoreUndo() throws -> Bool {
        guard version.rawValue >= 5 else {
            throw RuntimeError.unsupportedOperation("RESTORE_UNDO not supported in version \(version.rawValue)", location: SourceLocation.unknown)
        }

        guard let savedUndoState = undoState else {
            return false // No UNDO state available
        }

        // Restore state from UNDO
        try restoreGameState(savedUndoState)
        return true
    }

    /// Capture complete game state for save operations
    ///
    /// Creates a QuetzalSaveState containing all VM state needed for restoration:
    /// - Story identification from current header
    /// - Compressed dynamic memory delta
    /// - Complete stack state with proper frame encoding
    /// - Current execution context
    ///
    /// - Returns: Complete save state ready for serialization
    /// - Throws: RuntimeError for state capture failures
    private func captureGameState() throws -> QuetzalSaveState {
        // Create story identification for save validation
        let identification = StoryIdentification(
            release: UInt16(storyData.subdata(in: 2..<4).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }), // Release from header bytes 2-3
            serial: header.serialNumber,
            checksum: header.checksum,
            initialPC: header.initialPC
        )

        // Get original dynamic memory from story file for delta compression
        let originalDynamicMemory = storyData.subdata(in: 0..<Int(staticMemoryBase))

        // Compress memory delta (only store changes)
        let compressedMemory = MemoryCompressor.compressMemoryDelta(
            original: originalDynamicMemory,
            current: dynamicMemory
        )

        // Convert call stack to Quetzal format with enhanced frame information
        var quetzalCallStack: [QuetzalStackFrame] = []
        var stackBase: UInt16 = 0

        for frame in callStack {
            let quetzalFrame = QuetzalStackFrame(
                returnPC: frame.returnPC,
                localCount: UInt8(min(frame.localCount, 15)), // Quetzal limit
                locals: frame.locals,
                stackBase: stackBase,
                storeVariable: frame.storeVariable ?? 0, // Save store variable (0 for CALL_VN)
                argumentMask: 0   // This would need argument count tracking
            )
            quetzalCallStack.append(quetzalFrame)
            stackBase = UInt16(evaluationStack.count)
        }

        // Create complete stack state
        let stackState = StackState(
            evaluationStack: evaluationStack,
            callStack: quetzalCallStack
        )

        return QuetzalSaveState(
            identification: identification,
            compressedMemory: compressedMemory,
            stackState: stackState,
            programCounter: programCounter,
            interpreterData: nil, // Could store Swift-ZIL specific data
            timestamp: Date()
        )
    }

    /// Validate save file compatibility with current story
    ///
    /// Ensures the save file was created for the same story to prevent
    /// loading incompatible save data that could corrupt game state.
    ///
    /// - Parameter identification: Story identification from save file
    /// - Throws: QuetzalError for incompatible saves
    private func validateSaveCompatibility(_ identification: StoryIdentification) throws {
        // Check serial number (primary identifier)
        guard identification.serial == header.serialNumber else {
            throw QuetzalError.incompatibleSave("Save file serial '\(identification.serial)' doesn't match story '\(header.serialNumber)'")
        }

        // Check checksum (secondary validation)
        guard identification.checksum == header.checksum else {
            throw QuetzalError.incompatibleSave("Save file checksum \(identification.checksum) doesn't match story \(header.checksum)")
        }

        // Verify initial PC matches (ensures same version/compilation)
        guard identification.initialPC == header.initialPC else {
            throw QuetzalError.incompatibleSave("Save file initial PC \(identification.initialPC) doesn't match story \(header.initialPC)")
        }
    }

    /// Restore complete game state from save data
    ///
    /// Restores all VM state from a Quetzal save:
    /// - Decompresses and restores dynamic memory
    /// - Rebuilds call stack with proper frame structure
    /// - Restores evaluation stack contents
    /// - Sets program counter and execution context
    ///
    /// - Parameter saveState: Complete save state to restore
    /// - Throws: RuntimeError or QuetzalError for restoration failures
    private func restoreGameState(_ saveState: QuetzalSaveState) throws {
        // Get original dynamic memory for decompression
        let originalDynamicMemory = storyData.subdata(in: 0..<Int(staticMemoryBase))

        // Decompress and restore dynamic memory
        dynamicMemory = try MemoryCompressor.decompressMemoryDelta(
            compressed: saveState.compressedMemory,
            original: originalDynamicMemory
        )

        // Restore evaluation stack
        evaluationStack = saveState.stackState.evaluationStack

        // Convert Quetzal call stack back to VM format
        callStack.removeAll()
        for quetzalFrame in saveState.stackState.callStack {
            let vmFrame = StackFrame(
                returnPC: quetzalFrame.returnPC,
                localCount: Int(quetzalFrame.localCount),
                locals: quetzalFrame.locals,
                evaluationStackBase: Int(quetzalFrame.stackBase),
                storeVariable: quetzalFrame.storeVariable  // Restore from save
            )
            callStack.append(vmFrame)
        }

        // Restore locals from top frame (if any)
        if let topFrame = callStack.last {
            locals = topFrame.locals
        } else {
            locals.removeAll()
        }

        // Restore program counter
        programCounter = saveState.programCounter

        // Reload global variables from restored dynamic memory
        try loadGlobals()

        // Reload object tree state (objects may have moved/changed)
        // Object tree needs access to entire story file since objects are in dynamic memory
        // but property tables are in static memory
        let objectTableAddress = header.objectTableAddress
        let objectData = storyData
        let objectTableOffset = objectTableAddress

        try objectTree.load(from: objectData, version: version, objectTableAddress: objectTableOffset, staticMemoryBase: header.staticMemoryBase, dictionaryAddress: header.dictionaryAddress)
    }

    // MARK: - Random Number Generation

    /// Generate a random number in the given range
    ///
    /// - Parameter range: Positive for random range 1...range, negative to seed generator, 0 returns 0
    /// - Returns: Random number or 0 for seeding
    internal func generateRandom(_ range: Int16) -> Int16 {
        if range > 0 {
            return randomGenerator.next(in: 1...Int(range))
        } else if range < 0 {
            // Use absolute value of negative range as seed
            randomGenerator.seed(UInt32(abs(Int(range))))
            return 0
        } else {
            return 0
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
    public let unicodeTableAddress: UInt32  // Unicode translation table address (v5+, bytes 52-53)

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
        unicodeTableAddress = 0
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

        // Initial PC (START) - bytes 6-7 (byte address in v1-3, packed routine address in v4+)
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

        // Unicode translation table address for v5+ (bytes 52-53)
        if zmVersion.rawValue >= 5 {
            if data.count >= 54 {
                unicodeTableAddress = (UInt32(data[52]) << 8) | UInt32(data[53])
            } else {
                unicodeTableAddress = 0
            }
        } else {
            unicodeTableAddress = 0
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

        // Object table can be in dynamic or static memory, just needs to be within file bounds
        guard objectTableAddress < dataSize else {
            throw RuntimeError.corruptedStoryFile("Object table address (\(objectTableAddress)) out of bounds", location: SourceLocation.unknown)
        }

        guard globalTableAddress < staticMemoryBase else {
            throw RuntimeError.corruptedStoryFile("Global table address (\(globalTableAddress)) must be in dynamic memory", location: SourceLocation.unknown)
        }
    }
}

/// Stack frame for routine calls
public struct StackFrame {
    let returnPC: UInt32
    let localCount: Int
    let locals: [UInt16]
    let evaluationStackBase: Int
    let storeVariable: UInt8?  // Store variable for CALL (nil for CALL_VN)
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

/// Seeded random number generator for consistent game behavior
internal class SeededRandomGenerator {
    private var seed: UInt32

    init() {
        // Initialize with current time as default seed
        self.seed = UInt32(Date().timeIntervalSince1970) & 0xFFFFFF
    }

    /// Set the random seed
    ///
    /// - Parameter newSeed: New seed value
    func seed(_ newSeed: UInt32) {
        self.seed = newSeed & 0xFFFFFF // Keep it 24-bit for consistency
    }

    /// Generate next random number in range
    ///
    /// Uses a simple linear congruential generator for consistency
    /// - Parameter range: Range for random number (e.g., 1...6 for dice)
    /// - Returns: Random number in the specified range
    func next(in range: ClosedRange<Int>) -> Int16 {
        // Bounds checking
        guard range.lowerBound >= Int(Int16.min) && range.upperBound <= Int(Int16.max) else {
            return 0 // Return safe value for out-of-bounds range
        }
        guard range.lowerBound <= range.upperBound else {
            return Int16(range.lowerBound) // Invalid range, return lower bound
        }

        // Linear congruential generator: (a * seed + c) mod m
        // Using constants from Numerical Recipes
        seed = (1664525 &* seed &+ 1013904223) & 0xFFFFFF

        let rangeSize = range.upperBound - range.lowerBound + 1
        let result = range.lowerBound + Int(seed % UInt32(rangeSize))

        // Ensure result fits in Int16
        return Int16(clamping: result)
    }
}
