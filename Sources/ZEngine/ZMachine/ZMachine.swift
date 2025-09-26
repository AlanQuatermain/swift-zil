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

        // Set initial PC from header AFTER resetting state
        programCounter = unpackRoutineAddress(header.initialPC)
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

        // Dynamic memory: from start to static memory base
        staticMemoryBase = header.staticMemoryBase
        let dynamicSize = Int(staticMemoryBase)

        guard dynamicSize <= dataSize else {
            throw RuntimeError.corruptedStoryFile("Invalid static memory base", location: SourceLocation.unknown)
        }

        dynamicMemory = storyData.subdata(in: 0..<dynamicSize)

        // Static memory: from static base to high memory base
        highMemoryBase = header.highMemoryBase
        let staticSize = Int(highMemoryBase - staticMemoryBase)

        guard staticSize >= 0, Int(highMemoryBase) <= dataSize else {
            throw RuntimeError.corruptedStoryFile("Invalid high memory base", location: SourceLocation.unknown)
        }

        staticMemory = storyData.subdata(in: Int(staticMemoryBase)..<Int(highMemoryBase))

        // High memory: from high base to end of file
        highMemory = storyData.subdata(in: Int(highMemoryBase)..<dataSize)
    }

    private func loadGameData() throws {
        // Load global variables from dynamic memory
        try loadGlobals()

        // Load object tree from static memory
        // Convert absolute object table address to offset within static memory
        let objectTableOffset = header.objectTableAddress - header.staticMemoryBase
        try objectTree.load(from: staticMemory, version: version, objectTableAddress: UInt32(objectTableOffset), staticMemoryBase: header.staticMemoryBase)

        // Load dictionary from static memory
        // Convert absolute dictionary address to offset within static memory
        let dictionaryOffset = header.dictionaryAddress - header.staticMemoryBase
        try dictionary.load(from: staticMemory, dictionaryAddress: UInt32(dictionaryOffset))
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
        if address < staticMemoryBase {
            // Dynamic memory
            guard address < UInt32(dynamicMemory.count) else {
                throw RuntimeError.invalidMemoryAccess(Int(address), location: SourceLocation.unknown)
            }
            return dynamicMemory[Int(address)]
        } else if address < highMemoryBase {
            // Static memory
            let staticOffset = address - staticMemoryBase
            guard staticOffset < UInt32(staticMemory.count) else {
                throw RuntimeError.invalidMemoryAccess(Int(address), location: SourceLocation.unknown)
            }
            return staticMemory[Int(staticOffset)]
        } else {
            // High memory
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
        try writeByte(UInt8((value >> 8) & 0xFF), at: address)
        try writeByte(UInt8(value & 0xFF), at: address + 1)
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
    }

    // MARK: - Address Unpacking

    /// Unpack a routine address from the story file header format
    ///
    /// Z-Machine routine addresses in headers are packed (divided by version-specific scale factor).
    /// This method unpacks them back to actual byte addresses.
    ///
    /// - Parameter packedAddress: The packed address from the story file
    /// - Returns: The actual byte address in memory
    private func unpackRoutineAddress(_ packedAddress: UInt32) -> UInt32 {
        let scaleFactor: UInt32
        switch version {
        case .v3:
            scaleFactor = 2
        case .v4, .v5:
            scaleFactor = 4
        case .v6, .v7, .v8:
            scaleFactor = 8
        }
        return packedAddress * scaleFactor
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
        serialNumber = ""
        checksum = 0
        routineOffset = 0
        stringOffset = 0
    }

    public init(from data: Data) throws {
        guard data.count >= 64 else {
            throw RuntimeError.corruptedStoryFile("Header too small", location: SourceLocation.unknown)
        }

        // Parse header fields
        let versionByte = data[0]
        guard let zmVersion = ZMachineVersion(rawValue: versionByte) else {
            throw RuntimeError.corruptedStoryFile("Invalid version \(versionByte)", location: SourceLocation.unknown)
        }
        version = zmVersion

        flags = (UInt16(data[1]) << 8) | UInt16(data[2])

        highMemoryBase = (UInt32(data[4]) << 8) | UInt32(data[5])
        initialPC = (UInt32(data[6]) << 8) | UInt32(data[7])
        dictionaryAddress = (UInt32(data[8]) << 8) | UInt32(data[9])
        objectTableAddress = (UInt32(data[10]) << 8) | UInt32(data[11])
        globalTableAddress = (UInt32(data[12]) << 8) | UInt32(data[13])
        staticMemoryBase = (UInt32(data[14]) << 8) | UInt32(data[15])

        // Serial number (bytes 18-23)
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
public protocol TextInputDelegate: AnyObject {
    func requestInput() -> String
}