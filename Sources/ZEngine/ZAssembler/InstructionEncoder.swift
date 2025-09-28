/// Z-Machine Instruction Encoder - Converts ZAP instructions to Z-Machine bytecode
import Foundation

/// Encodes ZAP assembly instructions into Z-Machine bytecode format
public class InstructionEncoder {

    public let version: ZMachineVersion
    private var output: [UInt8] = []

    public init(version: ZMachineVersion) {
        self.version = version
    }

    /// Calculate the size of an instruction without encoding it
    ///
    /// - Parameters:
    ///   - instruction: The ZAP instruction
    ///   - address: Current address for size calculations
    ///   - symbolTable: Symbol table for branch offset calculation
    /// - Returns: Size in bytes
    /// - Throws: AssemblyError for encoding failures
    public func calculateInstructionSize(_ instruction: ZAPInstruction, at address: UInt32, symbolTable: [String: UInt32] = [:]) throws -> UInt32 {
        let opcode = try mapOpcodeToZMachine(instruction.opcode)

        // Basic size calculation: opcode byte + operands
        var size: UInt32 = 1 // Opcode byte

        // Add operand type byte for variable form instructions
        if needsOperandTypeByte(opcode) {
            size += 1
        }

        // Add operand sizes
        for operand in instruction.operands {
            size += try calculateOperandSize(operand)
        }

        // Add result storage byte if instruction produces a result
        if instruction.resultTarget != nil {
            size += 1
        }

        // Add branch offset if instruction has branch target
        if let branchTarget = instruction.branchTarget {
            // Special targets are always single-byte
            if branchTarget.uppercased() == "RTRUE" || branchTarget.uppercased() == "RFALSE" {
                size += 1
            } else if let targetAddress = symbolTable[branchTarget] {
                // Calculate approximate branch offset to determine encoding size
                let branchFromAddress = address + size + 2  // Assume 2-byte branch initially
                let rawOffset = Int32(targetAddress) - Int32(branchFromAddress)

                // Check if we can use single-byte encoding (6-bit range: -32 to +31)
                if rawOffset >= -32 && rawOffset <= 31 {
                    size += 1
                } else {
                    size += 2
                }
            } else {
                // Forward reference - assume 2-byte encoding (conservative)
                size += 2
            }
        }

        return size
    }

    /// Encode an instruction to bytecode
    ///
    /// - Parameters:
    ///   - instruction: The ZAP instruction to encode
    ///   - symbolTable: Symbol table for address resolution
    ///   - location: Source location for error reporting
    ///   - currentAddress: Current address for branch offset calculation
    /// - Returns: Encoded bytecode
    /// - Throws: AssemblyError for encoding failures
    public func encodeInstruction(_ instruction: ZAPInstruction, symbolTable: [String: UInt32], location: SourceLocation, currentAddress: UInt32) throws -> Data {
        output.removeAll()

        let opcode = try mapOpcodeToZMachine(instruction.opcode)
        let operands = instruction.operands

        // Determine instruction form and encode opcode
        try encodeOpcode(opcode, operands: operands)

        // Add operand type byte for variable form instructions
        if needsOperandTypeByte(opcode) {
            let typeByte = try encodeOperandTypeByte(for: operands)
            output.append(typeByte)
        }

        // Encode operands
        for operand in operands {
            try encodeOperand(operand, symbolTable: symbolTable)
        }

        // Encode result storage if instruction produces a result
        if let resultTarget = instruction.resultTarget {
            try encodeResultStorage(resultTarget, symbolTable: symbolTable)
        }

        // Encode branch target if present
        if let branchTarget = instruction.branchTarget {
            try encodeBranchTarget(branchTarget,
                                 condition: instruction.branchCondition ?? .branchOnTrue,
                                 symbolTable: symbolTable,
                                 currentAddress: currentAddress,
                                 instructionLength: UInt32(output.count))
        }

        return Data(output)
    }

    // MARK: - Private Implementation

    private func mapOpcodeToZMachine(_ opcode: String) throws -> UInt8 {
        // Map ZAP opcodes to Z-Machine opcodes based on version
        // Reference: Z-Machine Standards Document v1.0, Section 14

        switch opcode.uppercased() {

        // ===== 2OP Instructions (Long Form: 0x00-0x1F) =====
        case "JE", "EQUAL?": return 0x01      // Jump if equal
        case "JL", "LESS?": return 0x02       // Jump if less than
        case "JG", "GRTR?": return 0x03       // Jump if greater than
        case "JIN": return 0x06               // Jump if object in object
        case "TEST": return 0x07              // Test bitmap
        case "OR": return 0x08                // Bitwise OR
        case "AND": return 0x09               // Bitwise AND
        case "TEST_ATTR", "FSET?": return 0x0A  // Test attribute
        case "SET_ATTR", "FSET": return 0x0B    // Set attribute
        case "CLEAR_ATTR", "FCLEAR": return 0x0C // Clear attribute
        case "STORE": return 0x0D             // Store variable
        case "INSERT_OBJ": return 0x0E        // Insert object into object
        case "LOADW": return 0x0F             // Load word from array
        case "LOADB": return 0x10             // Load byte from array
        case "GET_PROP": return 0x11          // Get property value
        case "GET_PROP_ADDR": return 0x12     // Get property address
        case "GET_NEXT_PROP": return 0x13     // Get next property number
        case "ADD": return 0x14               // Addition
        case "SUB": return 0x15               // Subtraction
        case "MUL": return 0x16               // Multiplication
        case "DIV": return 0x17               // Division
        case "MOD": return 0x18               // Modulo
        case "SET_COLOUR": return 0x1B        // Set text colors (V5+)
        case "THROW": return 0x1C             // Throw to catch (V5+)

        // ===== 1OP Instructions (Short Form: 0x80-0x8F base) =====
        case "JZ", "ZERO?": return 0x80       // Jump if zero
        case "GET_SIBLING", "NEXT?": return 0x81  // Get sibling object
        case "GET_CHILD", "FIRST?": return 0x82   // Get child object
        case "GET_PARENT", "LOC": return 0x83     // Get parent object
        case "GET_PROP_LEN": return 0x84      // Get property length
        case "INC": return 0x85               // Increment variable
        case "DEC": return 0x86               // Decrement variable
        case "PRINT_ADDR": return 0x87        // Print string at address
        case "REMOVE_OBJ", "REMOVE": return 0x89  // Remove object from tree
        case "PRINT_OBJ", "PRINTN": return 0x8A   // Print object short name
        case "RET", "RETURN": return 0x8B     // Return from routine
        case "JUMP": return 0x8C              // Unconditional jump
        case "PRINT_PADDR": return 0x8D       // Print string at packed address
        case "LOAD": return 0x8E              // Load variable
        case "CALL_1N": return 0x8F           // Call routine, discard result (V5+)

        // ===== 0OP Instructions (Short Form: 0xB0-0xBF) =====
        case "RTRUE": return 0xB0             // Return true
        case "RFALSE": return 0xB1            // Return false
        case "PRINT", "PRINTI": return 0xB2       // Print literal string
        case "PRINT_RET", "PRINTR": return 0xB3   // Print literal string and return
        case "NOP": return 0xB4               // No operation (V4+)
        case "SAVE": return 0xB5              // Save game (V1-3: branch, V4+: store)
        case "RESTORE": return 0xB6           // Restore game (V1-3: branch, V4+: store)
        case "RESTART": return 0xB7           // Restart game
        case "RET_POPPED": return 0xB8        // Return popped value
        case "POP": return 0xB9               // Pop from stack (V1)/catch (V5+)
        case "QUIT": return 0xBA              // Quit game
        case "NEW_LINE", "CRLF": return 0xBB  // Print newline
        case "SHOW_STATUS": return 0xBC       // Show status line (V3)
        case "VERIFY": return 0xBD            // Verify story file integrity
        case "EXTENDED": return 0xBE          // Extended opcode follows (V5+)
        case "PIRACY": return 0xBF            // Piracy check (V5+)

        // ===== VAR Instructions (Variable Form: 0xE0-0xFF) =====
        case "CALL", "CALL_VS": return 0xE0   // Call routine with variable args
        case "STOREW": return 0xE1            // Store word in array
        case "STOREB": return 0xE2            // Store byte in array
        case "PUT_PROP": return 0xE3          // Set property value
        case "SREAD", "READ": return 0xE4     // Read line of input (SREAD v1-4, READ v5+)
        case "PRINT_CHAR": return 0xE5        // Print character
        case "PRINT_NUM", "PRINTD": return 0xE6   // Print signed number
        case "RANDOM": return 0xE7            // Random number generator
        case "PUSH": return 0xE8              // Push onto stack
        case "PULL": return 0xE9              // Pull from stack
        case "SPLIT_WINDOW": return 0xEA      // Split screen window (V3+)
        case "SET_WINDOW": return 0xEB        // Set current window (V3+)
        case "CALL_VS2": return 0xEC          // Call routine, up to 7 args (V4+)
        case "ERASE_WINDOW": return 0xED      // Clear window (V4+)
        case "ERASE_LINE": return 0xEE        // Clear line in window (V4+)
        case "SET_CURSOR": return 0xEF        // Set cursor position (V4+)
        case "GET_CURSOR": return 0xF0        // Get cursor position (V4+)
        case "SET_TEXT_STYLE": return 0xF1    // Set text style (V4+)
        case "BUFFER_MODE": return 0xF2       // Set buffering mode (V4+)
        case "OUTPUT_STREAM": return 0xF3     // Select output streams (V3+)
        case "INPUT_STREAM": return 0xF4      // Select input stream (V3+)
        case "SOUND_EFFECT": return 0xF5      // Play sound effect (V4+)
        case "READ_CHAR": return 0xF6         // Read single character (V4+)
        case "SCAN_TABLE": return 0xF7        // Scan table for value (V4+)
        case "NOT": return 0xF8               // Bitwise complement (V5+)
        case "CALL_VN": return 0xF9           // Call routine, discard result (V5+)
        case "CALL_VN2": return 0xFA          // Call routine, up to 7 args, discard result (V5+)
        case "TOKENISE": return 0xFB          // Tokenize text (V5+)
        case "ENCODE_TEXT": return 0xFC       // Encode text (V5+)
        case "COPY_TABLE": return 0xFD        // Copy table (V5+)
        case "PRINT_TABLE": return 0xFE       // Print table (V5+)
        case "CHECK_ARG_COUNT": return 0xFF   // Check argument count (V5+)

        // ===== Version-Specific Instructions =====
        case "DEC_CHK":
            guard version.rawValue >= 4 else {
                throw AssemblyError.versionMismatch(instruction: "DEC_CHK", version: Int(version.rawValue), location: SourceLocation(file: "assembly", line: 0, column: 0))
            }
            return 0x04

        case "INC_CHK":
            guard version.rawValue >= 4 else {
                throw AssemblyError.versionMismatch(instruction: "INC_CHK", version: Int(version.rawValue), location: SourceLocation(file: "assembly", line: 0, column: 0))
            }
            return 0x05

        case "CALL_2S":
            guard version.rawValue >= 4 else {
                throw AssemblyError.versionMismatch(instruction: "CALL_2S", version: Int(version.rawValue), location: SourceLocation(file: "assembly", line: 0, column: 0))
            }
            return 0x19

        case "CALL_1S":
            guard version.rawValue >= 4 else {
                throw AssemblyError.versionMismatch(instruction: "CALL_1S", version: Int(version.rawValue), location: SourceLocation(file: "assembly", line: 0, column: 0))
            }
            return 0x88

        case "CALL_2N":
            guard version.rawValue >= 5 else {
                throw AssemblyError.versionMismatch(instruction: "CALL_2N", version: Int(version.rawValue), location: SourceLocation(file: "assembly", line: 0, column: 0))
            }
            return 0x1A

        case "SOUND":
            // SOUND is an alias for SOUND_EFFECT in V4+
            guard version.rawValue >= 4 else {
                throw AssemblyError.versionMismatch(instruction: "SOUND", version: Int(version.rawValue), location: SourceLocation(file: "assembly", line: 0, column: 0))
            }
            return 0xF5  // SOUND_EFFECT

        default:
            throw AssemblyError.invalidInstruction(opcode, location: SourceLocation(file: "assembly", line: 0, column: 0))
        }
    }

    private func encodeOpcode(_ opcode: UInt8, operands: [ZValue]) throws {
        // Determine instruction form based on opcode value and encode with operand types

        if opcode >= 0xE0 {
            // VAR form (0xE0-0xFF)
            output.append(opcode)

        } else if opcode >= 0xC0 {
            // Variable form 2OP instructions (0xC0-0xDF)
            output.append(opcode)

        } else if opcode >= 0xB0 {
            // 0OP form (0xB0-0xBF)
            output.append(opcode)

        } else if opcode >= 0x80 {
            // 1OP form (0x80-0xAF)
            // Encode operand type in bits 5-4 of opcode
            var encodedOpcode = opcode & 0xCF  // Clear bits 5-4

            if !operands.isEmpty {
                let operandType = determineOperandType(operands[0])
                encodedOpcode |= (operandType.rawValue << 4)
            }
            output.append(encodedOpcode)

        } else {
            // 2OP form (0x00-0x7F)
            // Encode operand types in bit 6 (first operand) and bit 5 (second operand)
            var encodedOpcode = opcode

            if operands.count >= 1 {
                let operandType1 = determineOperandType(operands[0])
                if operandType1 == .variable {
                    encodedOpcode |= 0x40  // Set bit 6 for variable
                }
                // Small/large constants are 0, so no change needed
            }

            if operands.count >= 2 {
                let operandType2 = determineOperandType(operands[1])
                if operandType2 == .variable {
                    encodedOpcode |= 0x20  // Set bit 5 for variable
                }
                // Small/large constants are 0, so no change needed
            }

            output.append(encodedOpcode)
        }
    }

    private func needsOperandTypeByte(_ opcode: UInt8) -> Bool {
        // VAR form instructions (0xC0-0xFF except 0OP) need operand type byte
        return opcode >= 0xC0 && opcode < 0xE0  // 2OP VAR
            || opcode >= 0xE0  // VAR
    }

    private func encodeOperandTypeByte(for operands: [ZValue]) throws -> UInt8 {
        // Encode operand types into a single byte (2 bits per operand, up to 4 operands)
        var typeByte: UInt8 = 0xFF  // Start with all omitted (11)

        for (index, operand) in operands.enumerated() where index < 4 {
            let operandType = determineOperandType(operand)
            let shift = 6 - (index * 2)  // Positions: 6, 4, 2, 0

            // Clear the 2 bits for this operand
            typeByte &= ~(0x03 << shift)
            // Set the operand type
            typeByte |= (operandType.rawValue << shift)
        }

        return typeByte
    }

    private func determineOperandType(_ operand: ZValue) -> ZConstants.ArgumentType {
        switch operand {
        case .number(let value):
            // Small constants: 0-255, Large constants: anything else
            return abs(value) <= 255 ? .small : .large
        case .atom(_):
            // Variables use variable type
            return .variable
        case .string(_):
            // String references are typically large constants
            return .large
        default:
            return .large
        }
    }

    private func calculateOperandSize(_ operand: ZValue) throws -> UInt32 {
        switch operand {
        case .number(let value):
            // Small constants (0-255) use 1 byte, large constants use 2 bytes
            return abs(value) <= 255 ? 1 : 2
        case .atom(_):
            // Variables and symbols typically use 1 byte
            return 1
        case .string(_):
            // Strings are stored separately, reference uses 2 bytes
            return 2
        default:
            return 2 // Conservative estimate
        }
    }

    private func encodeOperand(_ operand: ZValue, symbolTable: [String: UInt32]) throws {
        switch operand {
        case .number(let value):
            if abs(value) <= 255 {
                // Small constant
                output.append(UInt8(value & 0xFF))
            } else {
                // Large constant
                let bytes = withUnsafeBytes(of: value.bigEndian) { Array($0) }
                output.append(contentsOf: bytes)
            }

        case .atom(let name):
            if name.hasPrefix("'") {
                // Global variable
                let varName = String(name.dropFirst())
                if let address = symbolTable[varName] {
                    output.append(UInt8(address & 0xFF))
                } else {
                    throw AssemblyError.undefinedLabel(varName, location: SourceLocation(file: "assembly", line: 0, column: 0))
                }
            } else {
                // Local variable or other symbol
                // Simplified - assume local variable number
                let varNum = parseLocalVariableNumber(name)
                output.append(UInt8(varNum))
            }

        case .string:
            // String references are handled by memory layout
            // For now, output a placeholder
            output.append(0x00)
            output.append(0x00)

        default:
            // Other types - use placeholder
            output.append(0x00)
        }
    }

    private func encodeResultStorage(_ target: String, symbolTable: [String: UInt32]) throws {
        // Result storage: variable number where result should be stored
        let variableNumber = try resolveVariableNumber(target, symbolTable: symbolTable)
        output.append(variableNumber)
    }

    private func encodeBranchTarget(_ target: String, condition: BranchCondition, symbolTable: [String: UInt32], currentAddress: UInt32, instructionLength: UInt32) throws {
        // Z-Machine branch encoding format:
        //
        // For single-byte format (6-bit offset):
        // Bit 7: 1 (indicates single byte format)
        // Bit 6: Branch condition (1 = branch on true, 0 = branch on false)
        // Bits 5-0: 6-bit signed offset (-32 to +31)
        //
        // For two-byte format (14-bit offset):
        // First byte:  Bit 7: 0 (indicates two byte format)
        //              Bit 6: Branch condition (1 = branch on true, 0 = branch on false)
        //              Bits 5-0: Upper 6 bits of 14-bit signed offset
        // Second byte: Lower 8 bits of 14-bit signed offset
        //
        // Special offsets: 0 = RFALSE, 1 = RTRUE

        // Handle special targets first
        if target.uppercased() == "RTRUE" {
            // Branch and return true (offset 1)
            let branchByte: UInt8 = 0x80 | (condition == .branchOnTrue ? 0x40 : 0x00) | 0x01
            output.append(branchByte)
            return
        }

        if target.uppercased() == "RFALSE" {
            // Branch and return false (offset 0)
            let branchByte: UInt8 = 0x80 | (condition == .branchOnTrue ? 0x40 : 0x00) | 0x00
            output.append(branchByte)
            return
        }

        // Look up target address
        guard let targetAddress = symbolTable[target] else {
            // Forward reference - use placeholder encoding for now
            // This should be resolved in a second pass
            output.append(0x40)  // Default: branch on true, offset 0
            output.append(0x00)
            return
        }

        // Calculate branch offset relative to the address AFTER this instruction
        let branchFromAddress = currentAddress + instructionLength + 2  // Assume 2-byte branch initially
        let rawOffset = Int32(targetAddress) - Int32(branchFromAddress)

        // Validate offset range
        if rawOffset < -8192 || rawOffset > 8191 {
            throw AssemblyError.branchTargetOutOfRange(target: target, offset: Int(rawOffset),
                                                     location: SourceLocation(file: "assembly", line: 0, column: 0))
        }

        // Determine if we can use single-byte encoding
        if rawOffset >= -32 && rawOffset <= 31 {
            // Single-byte format
            let branchByte: UInt8 = 0x80 |  // Single byte indicator
                                   (condition == .branchOnTrue ? 0x40 : 0x00) |  // Branch condition
                                   UInt8(rawOffset & 0x3F)  // 6-bit offset
            output.append(branchByte)
        } else {
            // Two-byte format
            // Recalculate offset for two-byte branch (we assumed 2 bytes, so this is correct)
            let offset14 = UInt16(rawOffset & 0x3FFF)  // 14-bit offset

            let firstByte: UInt8 = 0x00 |  // Two byte indicator (bit 7 = 0)
                                  (condition == .branchOnTrue ? 0x40 : 0x00) |  // Branch condition
                                  UInt8((offset14 >> 8) & 0x3F)  // Upper 6 bits

            let secondByte: UInt8 = UInt8(offset14 & 0xFF)  // Lower 8 bits

            output.append(firstByte)
            output.append(secondByte)
        }
    }

    private func resolveVariableNumber(_ name: String, symbolTable: [String: UInt32]) throws -> UInt8 {
        // Variable number encoding:
        // 0x00: Stack top
        // 0x01-0x0F: Local variables 1-15
        // 0x10-0xFF: Global variables 0x10-0xFF

        if name.uppercased() == "STACK" {
            return 0x00
        }

        // Check for local variable (L01, L02, etc.)
        if name.hasPrefix("L") && name.count == 3 {
            if let number = Int(name.dropFirst()), number >= 1 && number <= 15 {
                return UInt8(number)
            }
        }

        // Check for global variable
        if let globalAddress = symbolTable[name] {
            // Convert address to global variable number
            let globalIndex = (globalAddress - 64) / 2  // Globals start at 64, 2 bytes each
            return UInt8(0x10 + globalIndex)
        }

        // Default to local variable 1
        return 0x01
    }

    private func parseLocalVariableNumber(_ name: String) -> Int {
        // Simple local variable name to number mapping
        // In real implementation, this would use proper symbol table lookup
        switch name.uppercased() {
        case "STACK": return 0x00
        default: return 0x01 // Default to local variable 1
        }
    }
}