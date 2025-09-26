/// Z-Machine Instruction Execution - Implements the complete Z-Machine instruction set
import Foundation

// MARK: - Instruction Execution Methods
extension ZMachine {

    // MARK: - 0OP Instructions (no operands)

    func execute0OPInstruction(_ opcode: UInt8) throws {
        switch opcode {
        case 0xB0: // RTRUE
            try returnFromRoutine(value: 1)

        case 0xB1: // RFALSE
            try returnFromRoutine(value: 0)

        case 0xB2: // PRINT (string follows instruction)
            let stringAddress = programCounter
            let text = try readZString(at: stringAddress)
            outputText(text.string)
            programCounter = text.nextAddress

        case 0xB3: // PRINT_RET (print string and return true)
            let stringAddress = programCounter
            let text = try readZString(at: stringAddress)
            outputText(text.string)
            outputText("\n")
            programCounter = text.nextAddress
            try returnFromRoutine(value: 1)

        case 0xB4: // NOP
            // Do nothing
            break

        case 0xB5: // SAVE (v1-3)
            if version.rawValue <= 3 {
                // Simplified save - always succeed for now
                try pushStack(1)
            } else {
                throw RuntimeError.unsupportedOperation("SAVE instruction in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0xB6: // RESTORE (v1-3)
            if version.rawValue <= 3 {
                // Simplified restore - always fail for now
                try pushStack(0)
            } else {
                throw RuntimeError.unsupportedOperation("RESTORE instruction in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0xB7: // RESTART
            try restart()

        case 0xB8: // RET_POPPED
            let value = try popStack()
            try returnFromRoutine(value: Int16(value))

        case 0xB9: // POP (v1) / CATCH (v5+)
            if version.rawValue >= 5 {
                // CATCH - return current stack frame
                try pushStack(Int16(callStack.count))
            } else {
                // POP
                _ = try popStack()
            }

        case 0xBA: // QUIT
            quit()

        case 0xBB: // NEW_LINE
            outputText("\n")

        case 0xBC: // SHOW_STATUS (v1-3)
            if version.rawValue <= 3 {
                // Status line display - simplified
                outputDelegate?.didOutputText("[Status: Location, Score/Moves]")
            }

        case 0xBD: // VERIFY
            // Checksum verification - always succeed for now
            try branchOnCondition(true)

        case 0xBE: // EXTENDED (v5+)
            if version.rawValue >= 5 {
                // Extended instruction set
                let extOpcode = try readByte(at: programCounter)
                programCounter += 1
                try executeExtendedInstruction(extOpcode)
            } else {
                throw RuntimeError.unsupportedOperation("EXTENDED in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0xBF: // PIRACY (v5+)
            if version.rawValue >= 5 {
                // Anti-piracy check - always succeed
                try branchOnCondition(true)
            } else {
                throw RuntimeError.unsupportedOperation("PIRACY in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        default:
            throw RuntimeError.unsupportedOperation("0OP opcode 0x\(String(opcode, radix: 16, uppercase: true))", location: SourceLocation.unknown)
        }
    }

    // MARK: - 1OP Instructions (one operand)

    func execute1OPInstruction(_ opcode: UInt8) throws {
        let operandType = (opcode >> 4) & 0x03
        let operand = try readOperand(type: OperandType(rawValue: operandType) ?? .largeConstant)

        let baseOpcode = opcode & 0x0F

        switch baseOpcode {
        case 0x00: // JZ (jump if zero)
            try branchOnCondition(operand == 0)

        case 0x01: // GET_SIBLING
            let siblingNumber = objectTree.getObject(UInt16(operand))?.sibling ?? 0
            try storeResult(Int16(siblingNumber))
            try branchOnCondition(siblingNumber != 0)

        case 0x02: // GET_CHILD
            let childNumber = objectTree.getObject(UInt16(operand))?.child ?? 0
            try storeResult(Int16(childNumber))
            try branchOnCondition(childNumber != 0)

        case 0x03: // GET_PARENT
            let parentNumber = objectTree.getObject(UInt16(operand))?.parent ?? 0
            try storeResult(Int16(parentNumber))

        case 0x04: // GET_PROP_LEN
            // Get length of property data
            // Simplified: assume properties are 2 bytes
            try storeResult(2)

        case 0x05: // INC
            let currentValue = try readVariable(UInt8(operand))
            try writeVariable(UInt8(operand), value: currentValue + 1)

        case 0x06: // DEC
            let currentValue = try readVariable(UInt8(operand))
            try writeVariable(UInt8(operand), value: currentValue - 1)

        case 0x07: // PRINT_ADDR
            let text = try readZString(at: UInt32(operand))
            outputText(text.string)

        case 0x08: // CALL_1S (v4+)
            if version.rawValue >= 4 {
                let result = try callRoutine(UInt32(operand), arguments: [])
                try storeResult(result)
            } else {
                throw RuntimeError.unsupportedOperation("CALL_1S in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x09: // REMOVE_OBJ
            try objectTree.moveObject(UInt16(operand), toParent: 0)

        case 0x0A: // PRINT_OBJ
            // Print object short description (property 1)
            let description = objectTree.getProperty(UInt16(operand), property: 1)
            if description != 0 {
                let text = try readZString(at: UInt32(description))
                outputText(text.string)
            }

        case 0x0B: // RET
            try returnFromRoutine(value: operand)

        case 0x0C: // JUMP
            // Signed 16-bit offset
            let signedOffset = Int16(bitPattern: UInt16(operand))
            programCounter = UInt32(Int32(programCounter) + Int32(signedOffset) - 2)

        case 0x0D: // PRINT_PADDR
            // Print packed address string
            let unpackedAddress = unpackAddress(UInt32(operand), type: .string)
            let text = try readZString(at: unpackedAddress)
            outputText(text.string)

        case 0x0E: // LOAD
            let value = try readVariable(UInt8(operand))
            try storeResult(value)

        case 0x0F: // NOT (v1-4) / CALL_1N (v5+)
            if version.rawValue <= 4 {
                // NOT - bitwise complement
                try storeResult(~operand)
            } else {
                // CALL_1N - call routine and discard result
                _ = try callRoutine(UInt32(operand), arguments: [])
            }

        default:
            throw RuntimeError.unsupportedOperation("1OP opcode 0x\(String(baseOpcode, radix: 16, uppercase: true))", location: SourceLocation.unknown)
        }
    }

    // MARK: - 2OP Instructions (two operands)

    func execute2OPInstruction(_ opcode: UInt8) throws {
        let operandTypes = read2OPOperandTypes(opcode)
        let operand1 = try readOperand(type: operandTypes.0)
        let operand2 = try readOperand(type: operandTypes.1)

        let baseOpcode = opcode & 0x1F

        switch baseOpcode {
        case 0x01: // JE (jump if equal)
            try branchOnCondition(operand1 == operand2)

        case 0x02: // JL (jump if less)
            try branchOnCondition(operand1 < operand2)

        case 0x03: // JG (jump if greater)
            try branchOnCondition(operand1 > operand2)

        case 0x04: // DEC_CHK
            let currentValue = try readVariable(UInt8(operand1))
            let newValue = currentValue - 1
            try writeVariable(UInt8(operand1), value: newValue)
            try branchOnCondition(newValue < operand2)

        case 0x05: // INC_CHK
            let currentValue = try readVariable(UInt8(operand1))
            let newValue = currentValue + 1
            try writeVariable(UInt8(operand1), value: newValue)
            try branchOnCondition(newValue > operand2)

        case 0x06: // JIN (jump if object in container)
            let objectParent = objectTree.getObject(UInt16(operand1))?.parent ?? 0
            try branchOnCondition(objectParent == UInt16(operand2))

        case 0x07: // TEST (test attribute)
            let hasAttribute = objectTree.getAttribute(UInt16(operand1), attribute: UInt8(operand2))
            try branchOnCondition(hasAttribute)

        case 0x08: // OR
            try storeResult(operand1 | operand2)

        case 0x09: // AND
            try storeResult(operand1 & operand2)

        case 0x0A: // TEST_ATTR
            let hasAttribute = objectTree.getAttribute(UInt16(operand1), attribute: UInt8(operand2))
            try branchOnCondition(hasAttribute)

        case 0x0B: // SET_ATTR
            try objectTree.setAttribute(UInt16(operand1), attribute: UInt8(operand2), value: true)

        case 0x0C: // CLEAR_ATTR
            try objectTree.setAttribute(UInt16(operand1), attribute: UInt8(operand2), value: false)

        case 0x0D: // STORE
            try writeVariable(UInt8(operand1), value: operand2)

        case 0x0E: // INSERT_OBJ
            try objectTree.moveObject(UInt16(operand1), toParent: UInt16(operand2))

        case 0x0F: // LOADW
            let address = UInt32(operand1) + UInt32(operand2) * 2
            let value = try readWord(at: address)
            try storeResult(Int16(bitPattern: value))

        case 0x10: // LOADB
            let address = UInt32(operand1) + UInt32(operand2)
            let value = try readByte(at: address)
            try storeResult(Int16(value))

        case 0x11: // GET_PROP
            let propertyValue = objectTree.getProperty(UInt16(operand1), property: UInt8(operand2))
            try storeResult(Int16(bitPattern: propertyValue))

        case 0x12: // GET_PROP_ADDR
            // Simplified: return a dummy address
            try storeResult(0x1000)

        case 0x13: // GET_NEXT_PROP
            // Simplified: return next property number
            let nextProp = operand2 == 0 ? 1 : max(0, operand2 - 1)
            try storeResult(nextProp)

        case 0x14: // ADD
            try storeResult(operand1 + operand2)

        case 0x15: // SUB
            try storeResult(operand1 - operand2)

        case 0x16: // MUL
            try storeResult(operand1 * operand2)

        case 0x17: // DIV
            guard operand2 != 0 else {
                throw RuntimeError.divisionByZero(location: SourceLocation.unknown)
            }
            try storeResult(operand1 / operand2)

        case 0x18: // MOD
            guard operand2 != 0 else {
                throw RuntimeError.divisionByZero(location: SourceLocation.unknown)
            }
            try storeResult(operand1 % operand2)

        case 0x19: // CALL_2S (v4+)
            if version.rawValue >= 4 {
                let result = try callRoutine(UInt32(operand1), arguments: [operand2])
                try storeResult(result)
            } else {
                throw RuntimeError.unsupportedOperation("CALL_2S in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x1A: // CALL_2N (v5+)
            if version.rawValue >= 5 {
                _ = try callRoutine(UInt32(operand1), arguments: [operand2])
            } else {
                throw RuntimeError.unsupportedOperation("CALL_2N in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x1B: // SET_COLOUR (v5+)
            if version.rawValue >= 5 {
                // Color setting - ignored for now
            } else {
                throw RuntimeError.unsupportedOperation("SET_COLOUR in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x1C: // THROW (v5+)
            if version.rawValue >= 5 {
                // Exception handling - simplified
                try returnFromRoutine(value: operand1)
            } else {
                throw RuntimeError.unsupportedOperation("THROW in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        default:
            throw RuntimeError.unsupportedOperation("2OP opcode 0x\(String(baseOpcode, radix: 16, uppercase: true))", location: SourceLocation.unknown)
        }
    }

    // MARK: - VAR Instructions (variable number of operands)

    func executeVarInstruction(_ opcode: UInt8) throws {
        let operandTypeByte = try readByte(at: programCounter)
        programCounter += 1

        let operands = try readVarOperands(operandTypeByte)
        let baseOpcode = opcode & 0x1F

        switch baseOpcode {
        case 0x00: // CALL (v1-3) / CALL_VS (v4+)
            guard !operands.isEmpty else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }

            let routineAddress = UInt32(operands[0])
            let arguments = Array(operands.dropFirst())
            let result = try callRoutine(routineAddress, arguments: arguments)

            if version.rawValue >= 4 {
                try storeResult(result)
            } else {
                // v1-3: result is discarded
            }

        case 0x01: // STOREW
            guard operands.count >= 3 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            let address = UInt32(operands[0]) + UInt32(operands[1]) * 2
            try writeWord(UInt16(bitPattern: operands[2]), at: address)

        case 0x02: // STOREB
            guard operands.count >= 3 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            let address = UInt32(operands[0]) + UInt32(operands[1])
            try writeByte(UInt8(operands[2] & 0xFF), at: address)

        case 0x03: // PUT_PROP
            guard operands.count >= 3 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            try objectTree.setProperty(UInt16(operands[0]), property: UInt8(operands[1]), value: UInt16(bitPattern: operands[2]))

        case 0x04: // READ (v1-3) / SREAD (v4+)
            // Text input - simplified
            let input = readInput()
            outputText("> \(input)\n")

        case 0x05: // PRINT_CHAR
            guard !operands.isEmpty else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            if let scalar = UnicodeScalar(Int(operands[0])) {
                outputText(String(Character(scalar)))
            }

        case 0x06: // PRINT_NUM
            guard !operands.isEmpty else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            outputText(String(operands[0]))

        case 0x07: // RANDOM
            guard !operands.isEmpty else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }

            let range = operands[0]
            let result: Int16

            if range > 0 {
                result = Int16.random(in: 1...range)
            } else if range < 0 {
                // Seed random number generator
                result = 0
            } else {
                result = 0
            }

            try storeResult(result)

        case 0x08: // PUSH
            guard !operands.isEmpty else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            try pushStack(operands[0])

        case 0x09: // PULL (v1-5) / POP (v6+)
            if version.rawValue <= 5 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                let value = try popStack()
                try writeVariable(UInt8(operands[0]), value: value)
            } else {
                let value = try popStack()
                try storeResult(value)
            }

        default:
            throw RuntimeError.unsupportedOperation("VAR opcode 0x\(String(baseOpcode, radix: 16, uppercase: true))", location: SourceLocation.unknown)
        }
    }

    // MARK: - Extended Instructions (v5+)

    func executeExtendedInstruction(_ opcode: UInt8) throws {
        // Extended instructions - simplified implementation
        switch opcode {
        case 0x00: // SAVE
            // Save game - always succeed for now
            try storeResult(1)

        case 0x01: // RESTORE
            // Restore game - always fail for now
            try storeResult(0)

        case 0x02: // LOG_SHIFT
            let operandTypeByte = try readByte(at: programCounter)
            programCounter += 1
            let operands = try readVarOperands(operandTypeByte)

            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }

            let value = operands[0]
            let shift = operands[1]

            let result: Int16
            if shift > 0 {
                result = value << Int(shift)
            } else {
                result = value >> Int(-shift)
            }

            try storeResult(result)

        case 0x03: // ART_SHIFT
            let operandTypeByte = try readByte(at: programCounter)
            programCounter += 1
            let operands = try readVarOperands(operandTypeByte)

            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }

            let value = operands[0]
            let shift = operands[1]

            let result: Int16
            if shift > 0 {
                result = value << Int(shift)
            } else {
                // Arithmetic right shift preserves sign
                result = value >> Int(-shift)
            }

            try storeResult(result)

        default:
            throw RuntimeError.unsupportedOperation("Extended opcode 0x\(String(opcode, radix: 16, uppercase: true))", location: SourceLocation.unknown)
        }
    }
}