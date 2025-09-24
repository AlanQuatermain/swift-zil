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
    /// - Returns: Size in bytes
    /// - Throws: AssemblyError for encoding failures
    public func calculateInstructionSize(_ instruction: ZAPInstruction, at address: UInt32) throws -> UInt32 {
        // This is a simplified size calculation - real implementation would be more complex
        let opcode = try mapOpcodeToZMachine(instruction.opcode)
        let _ = instruction.operands.count

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

        // Add branch offset if instruction has branch target
        if instruction.branchTarget != nil {
            size += 2 // Branch offset (1-2 bytes, simplified to 2)
        }

        return size
    }

    /// Encode an instruction to bytecode
    ///
    /// - Parameters:
    ///   - instruction: The ZAP instruction to encode
    ///   - symbolTable: Symbol table for address resolution
    ///   - location: Source location for error reporting
    /// - Returns: Encoded bytecode
    /// - Throws: AssemblyError for encoding failures
    public func encodeInstruction(_ instruction: ZAPInstruction, symbolTable: [String: UInt32], location: SourceLocation) throws -> Data {
        output.removeAll()

        let opcode = try mapOpcodeToZMachine(instruction.opcode)
        let operands = instruction.operands

        // Determine instruction form and encode opcode
        try encodeOpcode(opcode, operandCount: operands.count)

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
            try encodeBranchTarget(branchTarget, symbolTable: symbolTable)
        }

        return Data(output)
    }

    // MARK: - Private Implementation

    private func mapOpcodeToZMachine(_ opcode: String) throws -> UInt8 {
        // Map ZAP opcodes to Z-Machine opcodes based on version
        switch opcode.uppercased() {
        // 2OP instructions
        case "ADD": return 0x14
        case "SUB": return 0x15
        case "MUL": return 0x16
        case "DIV": return 0x17
        case "MOD": return 0x18
        case "EQUAL?": return 0x01
        case "LESS?": return 0x02
        case "GRTR?": return 0x03
        case "SET": return 0x0D
        case "MOVE": return 0x0E
        case "GET": return 0x0F
        case "PUT": return 0x10
        case "GETP": return 0x11
        case "PUTP": return 0x12
        case "FSET": return 0x0B
        case "FCLEAR": return 0x0C

        // 1OP instructions
        case "ZERO?": return 0x80
        case "NEXT?": return 0x81
        case "FIRST?": return 0x82
        case "LOC": return 0x83
        case "REMOVE": return 0x84
        case "PRINTN": return 0x85
        case "RETURN": return 0x8B
        case "JUMP": return 0x8C

        // 0OP instructions
        case "RTRUE": return 0xB0
        case "RFALSE": return 0xB1
        case "PRINTI": return 0xB2
        case "PRINTR": return 0xB3
        case "CRLF": return 0xBB
        case "QUIT": return 0xBA

        // VAR instructions
        case "CALL": return 0xE0
        case "STOREW": return 0xE1
        case "STOREB": return 0xE2
        case "LOADW": return 0xE3
        case "LOADB": return 0xE4

        // Version-specific instructions
        case "SOUND":
            if version.rawValue >= 4 {
                return 0xE5
            }
            throw AssemblyError.versionMismatch(instruction: "SOUND", version: Int(version.rawValue), location: SourceLocation(file: "assembly", line: 0, column: 0))

        default:
            throw AssemblyError.invalidInstruction(opcode, location: SourceLocation(file: "assembly", line: 0, column: 0))
        }
    }

    private func encodeOpcode(_ opcode: UInt8, operandCount: Int) throws {
        // Determine instruction form based on opcode value and operand count

        if opcode >= 0xE0 {
            // VAR form (0xC0-0xDF for 2OP VAR, 0xE0-0xFF for VAR)
            output.append(opcode)
            // Operand type byte will be added separately after determining operand types

        } else if opcode >= 0xC0 {
            // Variable form 2OP instructions
            output.append(opcode)

        } else if opcode >= 0xB0 {
            // 0OP form (0xB0-0xBF)
            output.append(opcode)

        } else if opcode >= 0x80 {
            // 1OP form (0x80-0xAF)
            // Encode operand type in bits 5-4 of opcode
            var encodedOpcode = opcode
            if operandCount > 0 {
                // For now, assume small constant (type 01)
                encodedOpcode = (opcode & 0x8F) | 0x30  // Set bits 5-4 to 01
            }
            output.append(encodedOpcode)

        } else {
            // 2OP form (0x00-0x7F)
            // Encode operand types in bits 6-5 (first operand) and bit 4 (second operand)
            let encodedOpcode = opcode

            if operandCount >= 1 {
                // First operand - assume small constant (bit 6=0)
                // encodedOpcode already has this as 0
            }

            if operandCount >= 2 {
                // Second operand - assume small constant (bit 5=0)
                // encodedOpcode already has this as 0
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

    private func encodeBranchTarget(_ target: String, symbolTable: [String: UInt32]) throws {
        // Branch encoding format:
        // If bit 7 is 0: 14-bit signed offset in two bytes
        // If bit 7 is 1: 6-bit signed offset in one byte
        // Bit 6 indicates branch condition (1 = branch on true, 0 = branch on false)

        if let targetAddress = symbolTable[target] {
            // Calculate relative offset from current position
            let currentAddress = output.count + 2  // Assuming 2-byte branch
            let offset = Int16(targetAddress) - Int16(currentAddress)

            if offset >= -64 && offset <= 63 {
                // 6-bit offset (single byte)
                var branchByte: UInt8 = 0x80  // Set bit 7 (single byte format)
                branchByte |= 0x40  // Set bit 6 (branch on true - default)
                branchByte |= UInt8(offset & 0x3F)  // 6-bit offset
                output.append(branchByte)
            } else {
                // 14-bit offset (two bytes)
                var branchWord: UInt16 = 0x4000  // Set bit 14 (branch on true - default)
                branchWord |= UInt16(offset & 0x3FFF)  // 14-bit offset
                output.append(UInt8((branchWord >> 8) & 0xFF))
                output.append(UInt8(branchWord & 0xFF))
            }
        } else {
            // Special branch targets
            if target.uppercased() == "RTRUE" {
                output.append(0xC1)  // Branch on true, offset 1 (return true)
            } else if target.uppercased() == "RFALSE" {
                output.append(0xC0)  // Branch on true, offset 0 (return false)
            } else {
                // Forward reference - placeholder
                output.append(0x40)  // Default: branch on true, offset 0
                output.append(0x00)
            }
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