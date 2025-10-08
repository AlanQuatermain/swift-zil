/// Quetzal Save System - Implements the standard Quetzal IFF format for Z-Machine save files
///
/// The Quetzal format provides cross-interpreter compatibility for save files and is the
/// standard format used by all modern Z-Machine interpreters. This implementation follows
/// the Quetzal specification for maximum compatibility.
///
/// ## Key Features
/// - Full IFF (Interchange File Format) compliance
/// - Compressed memory delta storage for efficient file sizes
/// - Story file identification to prevent loading incompatible saves
/// - Complete execution state preservation (stacks, PC, locals)
/// - Cross-interpreter compatibility with other Z-Machine implementations
///
/// ## Quetzal File Format
/// ```
/// FORM....IFZS     ; IFF FORM chunk with 'IFZS' type
///   IFhd....       ; Story identification header
///   CMem....       ; Compressed memory delta
///   Stks....       ; Stack state (evaluation + call stacks)
///   IntD....       ; Optional interpreter-specific data
/// ```
import Foundation

// MARK: - Quetzal Save State

/// Complete save state for Quetzal format
internal struct QuetzalSaveState {
    /// Story file identification
    let identification: StoryIdentification

    /// Compressed memory delta (only changed dynamic memory)
    let compressedMemory: Data

    /// Complete stack state
    let stackState: StackState

    /// Current program counter
    let programCounter: UInt32

    /// Store variable that SAVE instruction used (needed for RESTORE to store 2)
    let saveInstructionStoreVariable: UInt8

    /// Z-Machine version (needed for Stks dummy frame logic)
    let version: UInt8

    /// Interpreter-specific data (optional)
    let interpreterData: Data?

    /// Creation timestamp
    let timestamp: Date
}

/// Story identification for save compatibility
internal struct StoryIdentification {
    /// Release number from story file header
    let release: UInt16

    /// Serial number from story file header (6 ASCII digits)
    let serial: String

    /// Checksum from story file header
    let checksum: UInt16

    /// Initial program counter from story file header
    let initialPC: UInt32
}

/// Complete stack state for save/restore
internal struct StackState {
    /// Evaluation stack contents
    let evaluationStack: [Int16]

    /// Call stack frames with full context
    let callStack: [QuetzalStackFrame]
}

/// Enhanced stack frame for Quetzal format
internal struct QuetzalStackFrame {
    /// Return address (program counter)
    let returnPC: UInt32

    /// Number of local variables
    let localCount: UInt8

    /// Local variable values
    let locals: [UInt16]

    /// Evaluation stack base for this frame
    let stackBase: UInt16

    /// Store variable for return value (0x00-0xFF)
    let storeVariable: UInt8

    /// Argument count mask (bits indicate which locals were provided as arguments)
    let argumentMask: UInt16
}

// MARK: - IFF Chunk Types

/// IFF chunk identifiers for Quetzal format
internal enum QuetzalChunkType: UInt32 {
    case form = 0x464F524D    // 'FORM'
    case ifzs = 0x49465A53    // 'IFZS'
    case ifhd = 0x49466864    // 'IFhd' - Story identification
    case cmem = 0x434D656D    // 'CMem' - Compressed memory
    case stks = 0x53746B73    // 'Stks' - Stack state
    case intd = 0x496E7444    // 'IntD' - Interpreter data

    var fourCC: String {
        let bytes = withUnsafeBytes(of: self.rawValue.bigEndian) { Data($0) }
        return String(data: bytes, encoding: .ascii) ?? "????"
    }
}

// MARK: - Quetzal Writer

/// Writes Quetzal save files in standard IFF format
internal class QuetzalWriter {

    /// Write a complete Quetzal save file
    ///
    /// - Parameter saveState: The complete save state to write
    /// - Returns: Quetzal save file data in IFF format
    /// - Throws: QuetzalError for encoding failures
    static func writeQuetzalFile(_ saveState: QuetzalSaveState) throws -> Data {
        var chunks: [Data] = []

        // Write IFhd chunk - Story identification
        chunks.append(try writeIFhdChunk(saveState.identification))

        // Write CMem chunk - Compressed memory delta
        chunks.append(try writeCMemChunk(saveState.compressedMemory))

        // Write Stks chunk - Stack state
        chunks.append(try writeStksChunk(saveState.stackState, pc: saveState.programCounter, version: saveState.version))

        // Write IntD chunk - Interpreter data (includes store variable)
        var interpreterData = Data()
        // Format: "SWZL" signature + store variable byte
        interpreterData.append(contentsOf: [0x53, 0x57, 0x5A, 0x4C]) // "SWZL"
        interpreterData.append(saveState.saveInstructionStoreVariable)
        if let additionalData = saveState.interpreterData {
            interpreterData.append(additionalData)
        }
        chunks.append(try writeIntDChunk(interpreterData))

        // Calculate total size for FORM header (including padding bytes)
        let totalChunkSize = chunks.reduce(0) { total, chunk in
            var size = total + chunk.count
            // Add padding byte if chunk size is odd
            if chunk.count % 2 == 1 {
                size += 1
            }
            return size
        }
        let formSize = UInt32(4 + totalChunkSize) // 'IFZS' + chunk data + padding

        // Build complete FORM chunk
        var formData = Data()

        // FORM header
        formData.append(QuetzalChunkType.form.rawValue.bigEndianData)
        formData.append(formSize.bigEndianData)
        formData.append(QuetzalChunkType.ifzs.rawValue.bigEndianData)

        // Append all chunks
        for chunk in chunks {
            formData.append(chunk)

            // Add padding if chunk size is odd (IFF requirement)
            if chunk.count % 2 == 1 {
                formData.append(0)
            }
        }

        return formData
    }

    /// Write IFhd chunk - Story identification
    private static func writeIFhdChunk(_ identification: StoryIdentification) throws -> Data {
        var chunkData = Data()

        // Chunk header
        chunkData.append(QuetzalChunkType.ifhd.rawValue.bigEndianData)
        chunkData.append(UInt32(13).bigEndianData) // IFhd is always 13 bytes

        // IFhd format: release(2) + serial(6) + checksum(2) + pc(3)
        chunkData.append(identification.release.bigEndianData)

        // Serial number (6 ASCII digits, pad if shorter)
        let serialData = identification.serial.padding(toLength: 6, withPad: "0", startingAt: 0).data(using: .ascii) ?? Data(repeating: 48, count: 6)
        chunkData.append(serialData.prefix(6))

        chunkData.append(identification.checksum.bigEndianData)

        // PC as 3-byte big-endian value (packed address format)
        let pcBytes = identification.initialPC.bigEndianData
        chunkData.append(pcBytes.dropFirst()) // Drop high byte, keep 3 bytes

        return chunkData
    }

    /// Write CMem chunk - Compressed memory delta
    private static func writeCMemChunk(_ compressedMemory: Data) throws -> Data {
        var chunkData = Data()

        // Chunk header
        chunkData.append(QuetzalChunkType.cmem.rawValue.bigEndianData)
        chunkData.append(UInt32(compressedMemory.count).bigEndianData)

        // Compressed memory data
        chunkData.append(compressedMemory)

        return chunkData
    }

    /// Write Stks chunk - Complete stack state
    private static func writeStksChunk(_ stackState: StackState, pc: UInt32, version: UInt8) throws -> Data {
        var stackData = Data()

        // For V3-V5 (non-V6), write dummy frame for top-level evaluation stack
        // This matches Frotz behavior (save_quetzal lines 503-516)
        if version != 6 {
            // Dummy frame header: 6 zero bytes (PC=0, flags=0, storeVar=0, argMask=0)
            for _ in 0..<6 {
                stackData.append(0)
            }

            // Calculate top-level eval stack size (stack items not belonging to any frame)
            let topLevelStackSize: UInt16
            if stackState.callStack.isEmpty {
                // No call frames - entire eval stack is top-level
                topLevelStackSize = UInt16(stackState.evaluationStack.count)
            } else {
                // Top-level stack is from start to first frame's stackBase
                topLevelStackSize = stackState.callStack[0].stackBase
            }

            // Write eval stack size for dummy frame
            stackData.append(topLevelStackSize.bigEndianData)

            // Write top-level eval stack values (reverse order per Frotz)
            for i in (0..<Int(topLevelStackSize)).reversed() {
                stackData.append(stackState.evaluationStack[i].bigEndianData)
            }
        }

        // Encode call stack frames (bottom to top)
        for (index, frame) in stackState.callStack.enumerated() {
            // Frame format: returnPC(3) + flags(1) + storeVar(1) + argMask(1) + evalStackSize(2) + locals + evalStack

            // Return PC (3 bytes, big-endian)
            // For the topmost (last) frame, use the current PC (where execution resumes after restore)
            // For all other frames, use the frame's stored return PC
            let framePC = (index == stackState.callStack.count - 1) ? pc : frame.returnPC
            let pcBytes = framePC.bigEndianData
            stackData.append(pcBytes.dropFirst())

            // Flags byte: bits 0-3 = local count, bit 4 = 0 (reserved)
            let flags: UInt8 = frame.localCount & 0x0F
            stackData.append(flags)

            // Store variable for return value
            stackData.append(frame.storeVariable)

            // Argument mask (which locals were provided as arguments)
            stackData.append(UInt8(frame.argumentMask & 0xFF))

            // Calculate evaluation stack size for this frame
            // Each frame gets eval stack from its stackBase to the next frame's stackBase (or end)
            let frameStackStart = Int(frame.stackBase)
            let frameStackEnd: Int
            if index < stackState.callStack.count - 1 {
                frameStackEnd = Int(stackState.callStack[index + 1].stackBase)
            } else {
                // Last frame gets everything up to current eval stack size
                frameStackEnd = stackState.evaluationStack.count
            }
            let frameStackSize = UInt16(frameStackEnd - frameStackStart)
            stackData.append(frameStackSize.bigEndianData)

            // Local variables
            for localValue in frame.locals {
                stackData.append(localValue.bigEndianData)
            }

            // Evaluation stack values for this frame
            for stackIndex in frameStackStart..<frameStackEnd {
                let value = stackState.evaluationStack[stackIndex]
                stackData.append(value.bigEndianData)
            }
        }

        // Build complete chunk
        var chunkData = Data()
        chunkData.append(QuetzalChunkType.stks.rawValue.bigEndianData)
        chunkData.append(UInt32(stackData.count).bigEndianData)
        chunkData.append(stackData)

        return chunkData
    }

    /// Write IntD chunk - Interpreter-specific data (optional)
    private static func writeIntDChunk(_ interpreterData: Data) throws -> Data {
        var chunkData = Data()

        // Chunk header
        chunkData.append(QuetzalChunkType.intd.rawValue.bigEndianData)
        chunkData.append(UInt32(interpreterData.count).bigEndianData)

        // Interpreter data
        chunkData.append(interpreterData)

        return chunkData
    }
}

// MARK: - Quetzal Reader

/// Reads Quetzal save files from standard IFF format
internal class QuetzalReader {

    /// Read a complete Quetzal save file
    ///
    /// - Parameters:
    ///   - data: Quetzal save file data in IFF format
    ///   - version: Z-Machine version (needed for Stks parsing logic)
    /// - Returns: Parsed save state
    /// - Throws: QuetzalError for parsing failures
    static func readQuetzalFile(_ data: Data, version: UInt8) throws -> QuetzalSaveState {
        guard data.count >= 12 else {
            throw QuetzalError.invalidFormat("File too small for IFF header")
        }

        var offset = 0

        // Verify FORM chunk header
        let formType = data.readUInt32BigEndian(at: &offset)
        guard formType == QuetzalChunkType.form.rawValue else {
            throw QuetzalError.invalidFormat("Not a valid IFF FORM file")
        }

        let formSize = data.readUInt32BigEndian(at: &offset)
        guard offset + Int(formSize) <= data.count else {
            throw QuetzalError.invalidFormat("FORM size exceeds file size")
        }

        let ifzsType = data.readUInt32BigEndian(at: &offset)
        guard ifzsType == QuetzalChunkType.ifzs.rawValue else {
            throw QuetzalError.invalidFormat("Not a Quetzal (IFZS) file")
        }

        // Parse chunks
        var identification: StoryIdentification?
        var compressedMemory: Data?
        var stackState: StackState?
        var programCounter: UInt32 = 0
        var interpreterData: Data?

        let formEnd = offset + Int(formSize) - 4 // Subtract 'IFZS' already read

        while offset < formEnd {
            let chunkType = data.readUInt32BigEndian(at: &offset)
            let chunkSize = data.readUInt32BigEndian(at: &offset)

            guard offset + Int(chunkSize) <= formEnd else {
                throw QuetzalError.invalidFormat("Chunk size exceeds remaining data")
            }

            let chunkData = data.subdata(in: offset..<(offset + Int(chunkSize)))
            offset += Int(chunkSize)

            // Skip padding byte if chunk size is odd
            if chunkSize % 2 == 1 && offset < formEnd {
                offset += 1
            }

            // Process chunk based on type
            switch chunkType {
            case QuetzalChunkType.ifhd.rawValue:
                identification = try parseIFhdChunk(chunkData)
                // Note: PC in IFhd is NOT used for execution - only for validation
                // Actual resume PC comes from topmost frame in Stks chunk
            case QuetzalChunkType.cmem.rawValue:
                compressedMemory = chunkData
            case QuetzalChunkType.stks.rawValue:
                let (stack, pc) = try parseStksChunk(chunkData, version: version)
                stackState = stack
                programCounter = pc  // PC from topmost frame's return PC
            case QuetzalChunkType.intd.rawValue:
                interpreterData = chunkData
            default:
                // Skip unknown chunks (IFF allows this)
                continue
            }
        }

        // Validate required chunks are present
        guard let finalIdentification = identification else {
            throw QuetzalError.missingChunk("IFhd chunk missing")
        }
        guard let finalCompressedMemory = compressedMemory else {
            throw QuetzalError.missingChunk("CMem chunk missing")
        }
        guard let finalStackState = stackState else {
            throw QuetzalError.missingChunk("Stks chunk missing")
        }

        // Extract store variable from IntD chunk (if present)
        var storeVariable: UInt8 = 0  // Default to 0 if not found
        if let intdData = interpreterData, intdData.count >= 5 {
            // Check for "SWZL" signature
            if intdData[0] == 0x53 && intdData[1] == 0x57 && intdData[2] == 0x5A && intdData[3] == 0x4C {
                storeVariable = intdData[4]
            }
        }

        return QuetzalSaveState(
            identification: finalIdentification,
            compressedMemory: finalCompressedMemory,
            stackState: finalStackState,
            programCounter: programCounter,
            saveInstructionStoreVariable: storeVariable,
            version: version,  // Use version parameter
            interpreterData: interpreterData,
            timestamp: Date()
        )
    }

    /// Parse IFhd chunk - Story identification
    private static func parseIFhdChunk(_ data: Data) throws -> StoryIdentification {
        guard data.count >= 13 else {
            throw QuetzalError.invalidChunk("IFhd chunk too small")
        }

        var offset = 0

        let release = data.readUInt16BigEndian(at: &offset)

        let serialData = data.subdata(in: offset..<(offset + 6))
        let serial = String(data: serialData, encoding: .ascii) ?? "000000"
        offset += 6

        let checksum = data.readUInt16BigEndian(at: &offset)

        // PC is stored as 3 bytes (packed address)
        let pcBytes = data.subdata(in: offset..<(offset + 3))
        let pc = UInt32(pcBytes[0]) << 16 | UInt32(pcBytes[1]) << 8 | UInt32(pcBytes[2])

        return StoryIdentification(
            release: release,
            serial: serial,
            checksum: checksum,
            initialPC: pc
        )
    }

    /// Parse Stks chunk - Stack state
    private static func parseStksChunk(_ data: Data, version: UInt8) throws -> (StackState, UInt32) {
        var offset = 0
        var callStack: [QuetzalStackFrame] = []
        var evaluationStack: [Int16] = []
        var currentPC: UInt32 = 0

        // For V3-V5 (non-V6), parse dummy frame for top-level evaluation stack
        // This matches Frotz behavior (restore_quetzal lines 235-251)
        if version != 6 {
            guard offset + 8 <= data.count else {
                throw QuetzalError.invalidChunk("Insufficient data for V3 dummy frame")
            }

            // Dummy frame header: 6 zero bytes (should be PC=0, flags=0, storeVar=0, argMask=0)
            for i in 0..<6 {
                if data[offset + i] != 0 {
                    throw QuetzalError.invalidChunk("Invalid V3 dummy frame header")
                }
            }
            offset += 6

            // Read eval stack size for top-level stack
            let topLevelStackSize = data.readUInt16BigEndian(at: &offset)

            // Read top-level eval stack values
            for _ in 0..<topLevelStackSize {
                guard offset + 2 <= data.count else {
                    throw QuetzalError.invalidChunk("Insufficient data for V3 top-level stack")
                }
                let stackValue = data.readInt16BigEndian(at: &offset)
                evaluationStack.append(stackValue)
            }
        }

        // Parse call stack frames
        while offset < data.count {
            guard offset + 8 <= data.count else {
                break // Not enough data for frame header
            }

            // Frame header: returnPC(3) + flags(1) + storeVar(1) + argMask(1) + evalStackSize(2)
            let pcBytes = data.subdata(in: offset..<(offset + 3))
            let returnPC = UInt32(pcBytes[0]) << 16 | UInt32(pcBytes[1]) << 8 | UInt32(pcBytes[2])
            offset += 3

            let flags = data[offset]
            offset += 1
            let localCount = flags & 0x0F

            let storeVariable = data[offset]
            offset += 1

            let argumentMask = UInt16(data[offset])
            offset += 1

            let evalStackSize = data.readUInt16BigEndian(at: &offset)

            // Read local variables
            var locals: [UInt16] = []
            for _ in 0..<localCount {
                guard offset + 2 <= data.count else {
                    throw QuetzalError.invalidChunk("Insufficient data for frame locals")
                }
                let localValue = data.readUInt16BigEndian(at: &offset)
                locals.append(localValue)
            }

            // Read evaluation stack for this frame
            for _ in 0..<evalStackSize {
                guard offset + 2 <= data.count else {
                    throw QuetzalError.invalidChunk("Insufficient data for frame evaluation stack")
                }
                let stackValue = data.readInt16BigEndian(at: &offset)
                evaluationStack.append(stackValue)
            }

            let frame = QuetzalStackFrame(
                returnPC: returnPC,
                localCount: localCount,
                locals: locals,
                stackBase: UInt16(evaluationStack.count - Int(evalStackSize)),
                storeVariable: storeVariable,
                argumentMask: argumentMask
            )
            callStack.append(frame)
            currentPC = returnPC
        }

        // Remaining evaluation stack items belong to current routine
        while offset < data.count - 1 {
            let stackValue = data.readInt16BigEndian(at: &offset)
            evaluationStack.append(stackValue)
        }

        let stackState = StackState(
            evaluationStack: evaluationStack,
            callStack: callStack
        )

        return (stackState, currentPC)
    }
}

// MARK: - Memory Compression

/// Compresses dynamic memory changes using XOR delta compression
internal class MemoryCompressor {

    /// Compress memory delta using XOR compression
    ///
    /// This creates a compressed representation of the differences between
    /// the original dynamic memory and the current state. Only changed bytes
    /// are stored, resulting in efficient save file sizes.
    ///
    /// Implements Frotz/Quetzal compression format:
    /// - XOR story file with current memory
    /// - Runs of zeros (unchanged bytes) encoded as `0x00, (count-1)`
    /// - Non-zero XOR deltas stored directly
    /// - Trailing runs are omitted (game will read from story file)
    ///
    /// - Parameters:
    ///   - original: Original dynamic memory from story file
    ///   - current: Current dynamic memory state
    /// - Returns: Compressed memory delta
    static func compressMemoryDelta(original: Data, current: Data) -> Data {
        guard original.count == current.count else {
            // If sizes don't match, store uncompressed current memory
            return current
        }

        var compressed = Data()
        var runLength = 0

        for i in 0..<original.count {
            let originalByte = original[i]
            let currentByte = current[i]
            let delta = originalByte ^ currentByte

            if delta == 0 {
                // Unchanged byte - accumulate run
                runLength += 1
            } else {
                // Changed byte - flush any pending run first
                if runLength > 0 {
                    // Write runs in chunks of 256 bytes (max run length is 256, encoded as 0xFF)
                    while runLength > 256 {
                        compressed.append(0x00)  // Zero marker
                        compressed.append(0xFF)  // Max run (256 bytes)
                        runLength -= 256
                    }

                    // Write remaining run as (runLength - 1)
                    // Frotz format: 0x00, N means (N+1) bytes unchanged
                    compressed.append(0x00)  // Zero marker
                    compressed.append(UInt8(runLength - 1))
                    runLength = 0
                }

                // Store the XOR delta (non-zero)
                compressed.append(delta)
            }
        }

        // NOTE: Trailing runs are omitted (Frotz compatibility)
        // The decompressor will read remaining unchanged bytes from story file

        return compressed
    }

    /// Decompress memory delta to restore original state
    ///
    /// This implements the Frotz/Quetzal XOR compression format:
    /// - `0x00, N` → Copy (N+1) bytes from story file (unchanged)
    /// - Non-zero byte B → XOR story file byte with B
    ///
    /// - Parameters:
    ///   - compressed: Compressed memory delta
    ///   - original: Original dynamic memory from story file
    /// - Returns: Restored dynamic memory state
    /// - Throws: QuetzalError for decompression failures
    static func decompressMemoryDelta(compressed: Data, original: Data) throws -> Data {
        var restored = Data()
        restored.reserveCapacity(original.count)

        var compressedOffset = 0
        var originalOffset = 0

        while compressedOffset < compressed.count && originalOffset < original.count {
            let byte = compressed[compressedOffset]
            compressedOffset += 1

            if byte == 0 {
                // Zero run marker - next byte is run length
                guard compressedOffset < compressed.count else {
                    throw QuetzalError.corruptedData("Missing run length after zero marker")
                }

                let runLength = Int(compressed[compressedOffset])
                compressedOffset += 1

                // Copy (runLength + 1) unchanged bytes from story file
                // Frotz format: 0x00, N means copy (N+1) bytes
                let bytesToCopy = runLength + 1

                guard originalOffset + bytesToCopy <= original.count else {
                    throw QuetzalError.corruptedData("Zero run exceeds memory bounds")
                }

                for _ in 0..<bytesToCopy {
                    restored.append(original[originalOffset])
                    originalOffset += 1
                }

            } else {
                // Non-zero byte - XOR with original
                guard originalOffset < original.count else {
                    throw QuetzalError.corruptedData("Delta exceeds memory bounds")
                }

                let originalByte = original[originalOffset]
                let restoredByte = originalByte ^ byte
                restored.append(restoredByte)
                originalOffset += 1
            }
        }

        // If compressed data ended early (omitted trailing run), copy remaining bytes from story file
        // This matches Frotz behavior (quetzal.c lines 370-374)
        while originalOffset < original.count {
            restored.append(original[originalOffset])
            originalOffset += 1
        }

        return restored
    }
}

// MARK: - Quetzal Errors

/// Errors that can occur during Quetzal save/restore operations
internal enum QuetzalError: LocalizedError {
    case invalidFormat(String)
    case missingChunk(String)
    case invalidChunk(String)
    case corruptedData(String)
    case incompatibleSave(String)
    case ioError(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat(let message):
            return "Invalid Quetzal format: \(message)"
        case .missingChunk(let chunk):
            return "Missing required chunk: \(chunk)"
        case .invalidChunk(let message):
            return "Invalid chunk data: \(message)"
        case .corruptedData(let message):
            return "Corrupted save data: \(message)"
        case .incompatibleSave(let message):
            return "Incompatible save file: \(message)"
        case .ioError(let message):
            return "I/O error: \(message)"
        }
    }
}

// MARK: - Data Extensions for IFF

extension Data {
    /// Read a big-endian UInt32 at the specified offset (handles unaligned reads)
    func readUInt32BigEndian(at offset: inout Int) -> UInt32 {
        // Read bytes individually to avoid alignment issues
        let byte0 = UInt32(self[offset])
        let byte1 = UInt32(self[offset + 1])
        let byte2 = UInt32(self[offset + 2])
        let byte3 = UInt32(self[offset + 3])
        offset += 4
        return (byte0 << 24) | (byte1 << 16) | (byte2 << 8) | byte3
    }

    /// Read a big-endian UInt16 at the specified offset (handles unaligned reads)
    func readUInt16BigEndian(at offset: inout Int) -> UInt16 {
        // Read bytes individually to avoid alignment issues
        let byte0 = UInt16(self[offset])
        let byte1 = UInt16(self[offset + 1])
        offset += 2
        return (byte0 << 8) | byte1
    }

    /// Read a big-endian Int16 at the specified offset (handles unaligned reads)
    func readInt16BigEndian(at offset: inout Int) -> Int16 {
        // Read bytes individually to avoid alignment issues
        let byte0 = UInt16(self[offset])
        let byte1 = UInt16(self[offset + 1])
        offset += 2
        let unsigned = (byte0 << 8) | byte1
        return Int16(bitPattern: unsigned)
    }
}

extension UInt32 {
    /// Convert to big-endian Data representation
    var bigEndianData: Data {
        return withUnsafeBytes(of: self.bigEndian) { Data($0) }
    }
}

extension UInt16 {
    /// Convert to big-endian Data representation
    var bigEndianData: Data {
        return withUnsafeBytes(of: self.bigEndian) { Data($0) }
    }
}

extension Int16 {
    /// Convert to big-endian Data representation
    var bigEndianData: Data {
        return withUnsafeBytes(of: self.bigEndian) { Data($0) }
    }
}

// MARK: - Save Game Delegate Protocol

/// Delegate protocol for handling save/restore file operations
public protocol SaveGameDelegate: AnyObject {
    /// Request a save file URL from the user
    ///
    /// - Parameter defaultName: Suggested filename for the save
    /// - Returns: URL where save file should be written, or nil if cancelled
    func requestSaveFileURL(defaultName: String) -> URL?

    /// Request a restore file URL from the user
    ///
    /// - Returns: URL of save file to restore, or nil if cancelled
    func requestRestoreFileURL() -> URL?

    /// Notify that save operation completed successfully
    ///
    /// - Parameter url: The URL where the file was saved
    func didSaveGame(to url: URL)

    /// Notify that restore operation completed successfully
    ///
    /// - Parameter url: The URL from which the file was restored
    func didRestoreGame(from url: URL)

    /// Notify that save/restore operation failed
    ///
    /// - Parameters:
    ///   - operation: The operation that failed ("save" or "restore")
    ///   - error: The error that occurred
    func saveRestoreDidFail(operation: String, error: Error)
}