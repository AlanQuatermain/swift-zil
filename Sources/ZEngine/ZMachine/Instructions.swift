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
                // v1-3: SAVE pushes result onto stack (1=success, 0=failure)
                let success = saveGame(defaultName: "save.qzl")
                try pushStack(success ? 1 : 0)
            } else {
                throw RuntimeError.unsupportedOperation("SAVE instruction in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0xB6: // RESTORE (v1-3)
            if version.rawValue <= 3 {
                // v1-3: RESTORE pushes result onto stack (2=success, 0=failure)
                // Note: Success should not return since execution resumes from save point
                let success = restoreGame()
                if !success {
                    // Only push failure result; success doesn't return
                    try pushStack(0)
                }
            } else {
                throw RuntimeError.unsupportedOperation("RESTORE instruction in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0xB7: // RESTART
            try restart()

        case 0xB8: // RET_POPPED
            let value = popStack()
            try returnFromRoutine(value: value)

        case 0xB9: // POP (v1) / CATCH (v5+)
            if version.rawValue >= 5 {
                // CATCH - return current stack frame
                // Safely convert call stack count to Int16, clamping to prevent overflow
                let stackFrameCount = min(callStack.count, Int(Int16.max))
                try pushStack(Int16(stackFrameCount))
            } else {
                // POP
                _ = popStack()
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

        // Extended/Non-standard opcodes that some games may use
        case 0xC0...0xFF:
            // These opcodes should now be handled by VAR instruction decoding
            // If we reach here, it means the opcode decoding logic has an issue
            throw RuntimeError.unsupportedOperation("Unexpected opcode 0x\(String(opcode, radix: 16, uppercase: true)) in 0OP handler at PC \(programCounter-1)", location: SourceLocation.unknown)

        default:
            throw RuntimeError.unsupportedOperation("0OP opcode 0x\(String(opcode, radix: 16, uppercase: true)) at PC \(programCounter-1)", location: SourceLocation.unknown)
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
            let siblingNumber = objectTree.getObject(UInt16(bitPattern: operand))?.sibling ?? 0
            try storeResult(Int16(siblingNumber))
            try branchOnCondition(siblingNumber != 0)

        case 0x02: // GET_CHILD
            let childNumber = objectTree.getObject(UInt16(bitPattern: operand))?.child ?? 0
            try storeResult(Int16(childNumber))
            try branchOnCondition(childNumber != 0)

        case 0x03: // GET_PARENT
            let parentNumber = objectTree.getObject(UInt16(bitPattern: operand))?.parent ?? 0
            try storeResult(Int16(parentNumber))

        case 0x04: // GET_PROP_LEN
            // Get length of property data at given address
            let address = UInt16(bitPattern: operand)
            let length = objectTree.getPropertyLength(at: address)
            try storeResult(Int16(length))

        case 0x05: // INC
            let variableNum = UInt8(operand & 0xFF) // Ensure positive value, variables are 0-255
            let currentValue = try readVariable(variableNum)
            try writeVariable(variableNum, value: currentValue + 1)

        case 0x06: // DEC
            let variableNum = UInt8(operand & 0xFF) // Ensure positive value, variables are 0-255
            let currentValue = try readVariable(variableNum)
            try writeVariable(variableNum, value: currentValue - 1)

        case 0x07: // PRINT_ADDR
            let text = try readZString(at: UInt32(operand))
            outputText(text.string)

        case 0x08: // CALL_1S (v4+)
            if version.rawValue >= 4 {
                let result = try callRoutine(UInt32(UInt16(bitPattern: operand)), arguments: [])
                try storeResult(result)
            } else {
                throw RuntimeError.unsupportedOperation("CALL_1S in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x09: // REMOVE_OBJ
            try objectTree.moveObject(UInt16(bitPattern: operand), toParent: 0)

        case 0x0A: // PRINT_OBJ
            // Print object short description from property table (not property 1)
            // print("DEBUG: PRINT_OBJ instruction - object=\(UInt16(bitPattern: operand))")
            let description = try readObjectShortDescription(UInt16(bitPattern: operand))
            if !description.isEmpty {
                outputText(description)
            }

        case 0x0B: // RET
            try returnFromRoutine(value: operand)

        case 0x0C: // JUMP
            // Unconditional jump with signed 16-bit offset
            // Offset is relative to the address of the first operand (PC + 1 from instruction start)
            // Calculate from postDecodePC - operand_size + 1
            let instructionStart = postDecodePC - 3  // JUMP is 3 bytes total (opcode + 2 byte operand)
            let operandAddress = instructionStart + 1  // First operand is at instruction + 1
            programCounter = UInt32(Int32(operandAddress) + Int32(operand))

        case 0x0D: // PRINT_PADDR
            // Print packed address string
            let unpackedAddress = unpackAddress(UInt32(UInt16(bitPattern: operand)), type: .string)
            let text = try readZString(at: unpackedAddress)
            outputText(text.string)

        case 0x0E: // LOAD
            let variableNum = UInt8(operand & 0xFF) // Ensure positive value, variables are 0-255
            let value = try readVariable(variableNum)
            try storeResult(value)

        case 0x0F: // NOT (v1-4) / CALL_1N (v5+)
            if version.rawValue <= 4 {
                // NOT - bitwise complement
                try storeResult(~operand)
            } else {
                // CALL_1N - call routine and discard result
                _ = try callRoutine(UInt32(UInt16(bitPattern: operand)), arguments: [])
            }

        default:
            throw RuntimeError.unsupportedOperation("1OP opcode 0x\(String(baseOpcode, radix: 16, uppercase: true)) at PC \(programCounter-1)", location: SourceLocation.unknown)
        }
    }

    // MARK: - 2OP Instructions (two operands)

    func execute2OPInstruction(_ opcode: UInt8) throws {
        let operandTypes = read2OPOperandTypes(opcode)
        let operand1 = try readOperand(type: operandTypes.0)
        let operand2 = try readOperand(type: operandTypes.1)

        let baseOpcode = opcode & 0x1F

        switch baseOpcode {
        case 0x00: // Reserved/ILLEGAL - some games may use this
            // In some implementations, this might be RTRUE or NOP
            // For compatibility, we'll implement it as NOP
            break

        case 0x01: // JE (jump if equal)
            try branchOnCondition(operand1 == operand2)

        case 0x02: // JL (jump if less)
            try branchOnCondition(operand1 < operand2)

        case 0x03: // JG (jump if greater)
            try branchOnCondition(operand1 > operand2)

        case 0x04: // DEC_CHK
            let variableNum = UInt8(operand1 & 0xFF) // Ensure positive value, variables are 0-255
            let currentValue = try readVariable(variableNum)
            let newValue = currentValue - 1
            try writeVariable(variableNum, value: newValue)
            try branchOnCondition(newValue < operand2)

        case 0x05: // INC_CHK
            let variableNum = UInt8(operand1 & 0xFF) // Ensure positive value, variables are 0-255
            let currentValue = try readVariable(variableNum)
            let newValue = currentValue + 1
            try writeVariable(variableNum, value: newValue)
            try branchOnCondition(newValue > operand2)

        case 0x06: // JIN (jump if object in container)
            let objectParent = objectTree.getObject(UInt16(bitPattern: operand1))?.parent ?? 0
            try branchOnCondition(objectParent == UInt16(bitPattern: operand2))

        case 0x07: // TEST (bitwise test)
            // Branch if all bits in operand2 are set in operand1
            // Equivalent to PEZ: (~operand1 & operand2) == 0
            let result = (operand1 & operand2) == operand2
            try branchOnCondition(result)

        case 0x08: // OR
            try storeResult(operand1 | operand2)

        case 0x09: // AND
            try storeResult(operand1 & operand2)

        case 0x0A: // TEST_ATTR
            let hasAttribute = objectTree.getAttribute(UInt16(bitPattern: operand1), attribute: UInt8(operand2 & 0xFF))
            try branchOnCondition(hasAttribute)

        case 0x0B: // SET_ATTR
            try objectTree.setAttribute(UInt16(bitPattern: operand1), attribute: UInt8(operand2 & 0xFF), value: true)

        case 0x0C: // CLEAR_ATTR
            try objectTree.setAttribute(UInt16(bitPattern: operand1), attribute: UInt8(operand2 & 0xFF), value: false)

        case 0x0D: // STORE
            let variableNum = UInt8(operand1 & 0xFF) // Ensure positive value, variables are 0-255
            try writeVariable(variableNum, value: operand2)

        case 0x0E: // INSERT_OBJ
            try objectTree.moveObject(UInt16(bitPattern: operand1), toParent: UInt16(bitPattern: operand2))

        case 0x0F: // LOADW
            // Emulate ZIP behavior: 16-bit address calculation with wraparound
            let address = UInt32(UInt16(bitPattern: operand1) &+ UInt16(bitPattern: operand2) &* 2)
            let value = try readWord(at: address)
            try storeResult(Int16(bitPattern: value))

        case 0x10: // LOADB
            // Emulate ZIP behavior: 16-bit address calculation with wraparound
            let address = UInt32(UInt16(bitPattern: operand1) &+ UInt16(bitPattern: operand2))
            let value = try readByte(at: address)
            try storeResult(Int16(value))

        case 0x11: // GET_PROP
            let objectNum = UInt16(bitPattern: operand1)
            let propertyNum = UInt8(operand2 & 0xFF)
            let propertyValue = objectTree.getProperty(objectNum, property: propertyNum)
            try storeResult(Int16(bitPattern: propertyValue))

        case 0x12: // GET_PROP_ADDR
            // Get address of object property data
            let objectNum = UInt16(bitPattern: operand1)
            let propertyNum = UInt8(operand2 & 0xFF)
            let address = objectTree.getPropertyAddress(objectNum, property: propertyNum)
            try storeResult(Int16(bitPattern: address))

        case 0x13: // GET_NEXT_PROP
            // Get next property number in object's property list
            let objectNum = UInt16(bitPattern: operand1)
            let currentProp = UInt8(operand2 & 0xFF)
            let nextProp = objectTree.getNextProperty(objectNum, after: currentProp)
            try storeResult(Int16(nextProp))

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
                let result = try callRoutine(UInt32(UInt16(bitPattern: operand1)), arguments: [operand2])
                try storeResult(result)
            } else {
                throw RuntimeError.unsupportedOperation("CALL_2S in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x1A: // CALL_2N (v5+)
            if version.rawValue >= 5 {
                _ = try callRoutine(UInt32(UInt16(bitPattern: operand1)), arguments: [operand2])
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

        case 0x1D: // Reserved/Illegal
            // This opcode is reserved and not defined in the Z-Machine specification
            // Some early or non-standard games might use it, so we'll treat it as NOP
            break

        case 0x1E: // CALL_2S (alternate encoding, v4+)
            if version.rawValue >= 4 {
                // This is an alternate encoding for CALL_2S with different operand format
                let result = try callRoutine(UInt32(UInt16(bitPattern: operand1)), arguments: [operand2])
                try storeResult(result)
            } else {
                throw RuntimeError.unsupportedOperation("CALL_2S (0x1E) in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x1F: // CALL_2N (alternate encoding, v5+)
            if version.rawValue >= 5 {
                // This is an alternate encoding for CALL_2N with different operand format
                _ = try callRoutine(UInt32(UInt16(bitPattern: operand1)), arguments: [operand2])
            } else {
                throw RuntimeError.unsupportedOperation("CALL_2N (0x1F) in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        default:
            throw RuntimeError.unsupportedOperation("2OP opcode 0x\(String(baseOpcode, radix: 16, uppercase: true)) at PC \(programCounter-1)", location: SourceLocation.unknown)
        }
    }

    // MARK: - 2OP VAR Instructions (variable form with 2 operands)

    func execute2OPVarInstruction(_ opcode: UInt8) throws {
        // Read operand type byte for variable form instructions
        let operandTypeByte = try readByte(at: programCounter)
        programCounter += 1

        // Parse ALL operands for 2OP VAR instructions (not limited to 2)
        // The "2OP" refers to instruction semantics, not operand count limits
        let operands = try readVarOperands(operandTypeByte, maxOperands: 4)
        guard !operands.isEmpty else {
            throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
        }

        let baseOpcode = opcode & 0x1F  // Extract bits 4-0

        switch baseOpcode {
        case 0x01: // JE (jump if equal) - VAR form
            // JE tests if first operand equals ANY of the remaining operands
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            let testValue = operands[0]
            let matches = operands.dropFirst().contains(testValue)
            try branchOnCondition(matches)

        case 0x02: // JL (jump if less) - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            try branchOnCondition(operands[0] < operands[1])

        case 0x03: // JG (jump if greater) - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            try branchOnCondition(operands[0] > operands[1])

        case 0x04: // DEC_CHK - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            let currentValue = try readVariable(UInt8(operands[0] & 0xFF))
            let newValue = currentValue - 1
            try writeVariable(UInt8(operands[0] & 0xFF), value: newValue)
            try branchOnCondition(newValue < operands[1])

        case 0x05: // INC_CHK - VAR form (this is 0xC5!)
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            let currentValue = try readVariable(UInt8(operands[0] & 0xFF))
            let newValue = currentValue + 1
            try writeVariable(UInt8(operands[0] & 0xFF), value: newValue)
            try branchOnCondition(newValue > operands[1])

        case 0x06: // JIN (jump if object in container) - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            let objectParent = objectTree.getObject(UInt16(bitPattern: operands[0]))?.parent ?? 0
            try branchOnCondition(objectParent == UInt16(bitPattern: operands[1]))

        case 0x07: // TEST (bitwise test) - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            // Branch if all bits in operands[1] are set in operands[0]
            // Equivalent to PEZ: (~operands[0] & operands[1]) == 0
            let result = (operands[0] & operands[1]) == operands[1]
            try branchOnCondition(result)

        case 0x08: // OR - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            try storeResult(operands[0] | operands[1])

        case 0x09: // AND - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            try storeResult(operands[0] & operands[1])

        case 0x0A: // TEST_ATTR - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            let hasAttribute = objectTree.getAttribute(UInt16(bitPattern: operands[0]), attribute: UInt8(operands[1] & 0xFF))
            try branchOnCondition(hasAttribute)

        case 0x0B: // SET_ATTR - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            try objectTree.setAttribute(UInt16(bitPattern: operands[0]), attribute: UInt8(operands[1] & 0xFF), value: true)

        case 0x0C: // CLEAR_ATTR - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            try objectTree.setAttribute(UInt16(bitPattern: operands[0]), attribute: UInt8(operands[1] & 0xFF), value: false)

        case 0x0D: // STORE - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            try writeVariable(UInt8(operands[0] & 0xFF), value: operands[1])

        case 0x0E: // INSERT_OBJ - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            try objectTree.moveObject(UInt16(bitPattern: operands[0]), toParent: UInt16(bitPattern: operands[1]))

        case 0x0F: // LOADW - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            // Emulate ZIP behavior: 16-bit address calculation with wraparound
            let address = UInt32(UInt16(bitPattern: operands[0]) &+ UInt16(bitPattern: operands[1]) &* 2)
            let value = try readWord(at: address)
            try storeResult(Int16(bitPattern: value))

        case 0x10: // LOADB - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            // Emulate ZIP behavior: 16-bit address calculation with wraparound
            let address = UInt32(UInt16(bitPattern: operands[0]) &+ UInt16(bitPattern: operands[1]))
            let value = try readByte(at: address)
            try storeResult(Int16(value))

        case 0x11: // GET_PROP - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            let objectNum = UInt16(bitPattern: operands[0])
            let propertyNum = UInt8(operands[1] & 0xFF)
            let propertyValue = objectTree.getProperty(objectNum, property: propertyNum)
            try storeResult(Int16(bitPattern: propertyValue))

        case 0x12: // GET_PROP_ADDR - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            let objectNum = UInt16(bitPattern: operands[0])
            let propertyNum = UInt8(operands[1] & 0xFF)
            let address = objectTree.getPropertyAddress(objectNum, property: propertyNum)
            try storeResult(Int16(bitPattern: address))

        case 0x13: // GET_NEXT_PROP - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            let objectNum = UInt16(bitPattern: operands[0])
            let currentProp = UInt8(operands[1] & 0xFF)
            let nextProp = objectTree.getNextProperty(objectNum, after: currentProp)
            try storeResult(Int16(nextProp))

        case 0x14: // ADD - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            try storeResult(operands[0] + operands[1])

        case 0x15: // SUB - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            try storeResult(operands[0] - operands[1])

        case 0x16: // MUL - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            try storeResult(operands[0] * operands[1])

        case 0x17: // DIV - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            guard operands[1] != 0 else {
                throw RuntimeError.divisionByZero(location: SourceLocation.unknown)
            }
            try storeResult(operands[0] / operands[1])

        case 0x18: // MOD - VAR form
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            guard operands[1] != 0 else {
                throw RuntimeError.divisionByZero(location: SourceLocation.unknown)
            }
            try storeResult(operands[0] % operands[1])

        case 0x19: // CALL_2S - VAR form (v4+)
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            if version.rawValue >= 4 {
                let result = try callRoutine(UInt32(UInt16(bitPattern: operands[0])), arguments: [operands[1]])
                try storeResult(result)
            } else {
                throw RuntimeError.unsupportedOperation("CALL_2S in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x1A: // CALL_2N - VAR form (v5+)
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            if version.rawValue >= 5 {
                _ = try callRoutine(UInt32(UInt16(bitPattern: operands[0])), arguments: [operands[1]])
            } else {
                throw RuntimeError.unsupportedOperation("CALL_2N in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        default:
            throw RuntimeError.unsupportedOperation("2OP VAR opcode 0x\(String(baseOpcode, radix: 16, uppercase: true)) at PC \(programCounter-1)", location: SourceLocation.unknown)
        }
    }

    // MARK: - Window Instructions (v4+)

    /// Execute SPLIT_WINDOW instruction (2OP opcode 0xA0)
    ///
    /// Creates or resizes the upper status window.
    ///
    /// - Parameter lines: Number of lines for upper window (0 to remove it)
    /// - Throws: RuntimeError for unsupported versions or window operations
    func executeSplitWindow(lines: Int16) throws {
        guard version.rawValue >= 4 else {
            throw RuntimeError.unsupportedOperation("SPLIT_WINDOW not supported in version \(version.rawValue)", location: SourceLocation.unknown)
        }

        try windowManager?.splitWindow(lines: Int(lines))
    }

    /// Execute SET_WINDOW instruction (2OP opcode 0xA1)
    ///
    /// Switches the current output window.
    ///
    /// - Parameter windowNumber: Window number (0, 1, or -3 for current)
    /// - Throws: RuntimeError for invalid window operations
    func executeSetWindow(_ windowNumber: Int16) throws {
        guard version.rawValue >= 4 else {
            throw RuntimeError.unsupportedOperation("SET_WINDOW not supported in version \(version.rawValue)", location: SourceLocation.unknown)
        }

        // Handle special window number -3 (current window)
        let targetWindow = windowNumber == -3 ? windowManager?.currentWindow ?? 0 : Int(windowNumber)

        // Validate window number range
        guard targetWindow >= 0 && targetWindow <= 1 else {
            // Invalid window numbers are ignored (no error)
            return
        }

        windowManager?.setCurrentWindow(targetWindow)
    }

    /// Execute ERASE_WINDOW instruction (2OP opcode 0xA2)
    ///
    /// Clears the specified window or all windows.
    ///
    /// - Parameter windowSpec: Window number (-2 for all, -1 for current, or specific window)
    /// - Throws: RuntimeError for invalid window operations
    func executeEraseWindow(_ windowSpec: Int16) throws {
        guard version.rawValue >= 4 else {
            throw RuntimeError.unsupportedOperation("ERASE_WINDOW not supported in version \(version.rawValue)", location: SourceLocation.unknown)
        }

        windowManager?.eraseWindow(Int(windowSpec))
    }

    /// Execute ERASE_LINE instruction (2OP opcode 0xA3)
    ///
    /// Clears from cursor to end of current line.
    ///
    /// - Parameter value: Should be 1 for current line
    /// - Throws: RuntimeError for invalid operations
    func executeEraseLine(_ value: Int16) throws {
        guard version.rawValue >= 4 else {
            throw RuntimeError.unsupportedOperation("ERASE_LINE not supported in version \(version.rawValue)", location: SourceLocation.unknown)
        }

        windowManager?.eraseLine(Int(value))
    }

    /// Execute SET_CURSOR instruction (2OP opcode 0xA4)
    ///
    /// Positions cursor in current window (non-scrolling windows only).
    ///
    /// - Parameters:
    ///   - line: Line number (1-based)
    ///   - column: Column number (1-based)
    /// - Throws: RuntimeError for invalid cursor operations
    func executeSetCursor(line: Int16, column: Int16) throws {
        guard version.rawValue >= 4 else {
            throw RuntimeError.unsupportedOperation("SET_CURSOR not supported in version \(version.rawValue)", location: SourceLocation.unknown)
        }

        try windowManager?.setCursor(line: Int(line), column: Int(column))
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

            // Treat routine address as unsigned even if operand is signed
            let routineAddress = UInt32(UInt16(bitPattern: operands[0]))
            let arguments = Array(operands.dropFirst())

            // CALL always stores result in all versions (v1-v8)
            // Read store variable byte and advance PC to next instruction (return address)
            let storeVariable = try readByte(at: programCounter)
            programCounter += 1  // PC now points to next instruction (return address)
            postDecodePC = programCounter  // Save for tracing

            // Trace the store byte
            traceStoreByte(storeVariable)

            _ = try callRoutine(routineAddress, arguments: arguments, storeVariable: storeVariable)

            // Result storage is handled by returnFromRoutine using saved store variable

        case 0x01: // STOREW
            guard operands.count >= 3 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            // Emulate ZIP behavior: 16-bit address calculation with wraparound
            let address = UInt32(UInt16(bitPattern: operands[0]) &+ UInt16(bitPattern: operands[1]) &* 2)
            try writeWord(UInt16(bitPattern: operands[2]), at: address)

        case 0x02: // STOREB
            guard operands.count >= 3 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            // Emulate ZIP behavior: 16-bit address calculation with wraparound
            let address = UInt32(UInt16(bitPattern: operands[0]) &+ UInt16(bitPattern: operands[1]))
            try writeByte(UInt8(operands[2] & 0xFF), at: address)

        case 0x03: // PUT_PROP
            guard operands.count >= 3 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }
            try objectTree.setProperty(UInt16(bitPattern: operands[0]), property: UInt8(operands[1] & 0xFF), value: UInt16(bitPattern: operands[2]))

        case 0x04: // READ (v1-3) / SREAD (v4+)
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }

            let textBufferAddr = UInt32(operands[0])
            let parseBufferAddr = UInt32(operands[1])

            // Optional time and routine operands for v4+
            var timeLimit: Int16 = 0
            var timeRoutine: UInt32 = 0
            if version.rawValue >= 4 && operands.count >= 4 {
                timeLimit = operands[2]
                timeRoutine = UInt32(operands[3])
            }

            try executeReadInstruction(textBuffer: textBufferAddr, parseBuffer: parseBufferAddr,
                                     timeLimit: timeLimit, timeRoutine: timeRoutine)

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
            let result = generateRandom(range)
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
                let value = popStack()
                try writeVariable(UInt8(operands[0] & 0xFF), value: value)
            } else {
                let value = popStack()
                try storeResult(value)
            }

        case 0x1B: // TOKENISE (V5+) / SET_COLOUR (V5+)
            if version.rawValue >= 5 {
                guard operands.count >= 2 else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }

                // Heuristic to distinguish SET_COLOUR from TOKENISE:
                // SET_COLOUR typically has 2-3 operands with small color values (0-15)
                // TOKENISE has 2-4 operands with the first two being buffer addresses (typically larger values)
                let firstOperand = UInt16(bitPattern: operands[0])
                let secondOperand = UInt16(bitPattern: operands[1])

                if operands.count <= 3 && firstOperand <= 15 && secondOperand <= 15 {
                    // Likely SET_COLOUR: foreground, background, [window]
                    let foreground = operands[0]
                    let background = operands[1]
                    let window = operands.count > 2 ? operands[2] : -1
                    try executeSetColour(foreground: foreground, background: background, window: window)
                } else {
                    // Likely TOKENISE: text_buffer, parse_buffer, [dictionary], [flags]
                    let textBufferAddr = UInt32(operands[0])
                    let parseBufferAddr = UInt32(operands[1])
                    let dictionaryAddr = operands.count > 2 ? UInt32(operands[2]) : 0
                    let flags = operands.count > 3 ? UInt8(operands[3] & 0xFF) : 0

                    try executeTokeniseInstruction(textBuffer: textBufferAddr, parseBuffer: parseBufferAddr,
                                                 dictionary: dictionaryAddr, flags: flags)
                }
            } else {
                throw RuntimeError.unsupportedOperation("TOKENISE/SET_COLOUR in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x0A: // SPLIT_WINDOW (v4+)
            if version.rawValue >= 4 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                try executeSplitWindow(lines: operands[0])
            } else {
                throw RuntimeError.unsupportedOperation("SPLIT_WINDOW in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x0B: // SET_WINDOW (v4+)
            if version.rawValue >= 4 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                try executeSetWindow(operands[0])
            } else {
                throw RuntimeError.unsupportedOperation("SET_WINDOW in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x0C: // ERASE_WINDOW (v4+)
            if version.rawValue >= 4 {
                let windowSpec = operands.isEmpty ? -1 : operands[0]  // Default to current window
                try executeEraseWindow(windowSpec)
            } else {
                throw RuntimeError.unsupportedOperation("ERASE_WINDOW in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x0D: // ERASE_LINE (v4+)
            if version.rawValue >= 4 {
                let value = operands.isEmpty ? 1 : operands[0]  // Default to current line
                try executeEraseLine(value)
            } else {
                throw RuntimeError.unsupportedOperation("ERASE_LINE in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x0E: // SET_CURSOR (v4+)
            if version.rawValue >= 4 {
                guard operands.count >= 2 else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                try executeSetCursor(line: operands[0], column: operands[1])
            } else {
                throw RuntimeError.unsupportedOperation("SET_CURSOR in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x11: // SET_TEXT_STYLE (v4+)
            if version.rawValue >= 4 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                try executeSetTextStyle(operands[0])
            } else {
                throw RuntimeError.unsupportedOperation("SET_TEXT_STYLE in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        default:
            throw RuntimeError.unsupportedOperation("VAR opcode 0x\(String(baseOpcode, radix: 16, uppercase: true))", location: SourceLocation.unknown)
        }
    }

    // MARK: - Extended Instructions (v5+)

    func executeExtendedInstruction(_ opcode: UInt8) throws {
        // Extended instructions require operand type byte (except for some special cases)
        let operandTypeByte = try readByte(at: programCounter)
        programCounter += 1
        let operands = try readVarOperands(operandTypeByte)

        switch opcode {
        case 0x00: // SAVE (V4+)
            if version.rawValue >= 4 {
                // v4+: SAVE stores result (1=success, 0=failure)
                // Optional table argument for aux memory save (not implemented)
                let success = saveGame(defaultName: "save.qzl")
                try storeResult(success ? 1 : 0)
            } else {
                throw RuntimeError.unsupportedOperation("Extended SAVE in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x01: // RESTORE (V4+)
            if version.rawValue >= 4 {
                // v4+: RESTORE stores result (2=success, 0=failure)
                // Note: Success should not return since execution resumes from save point
                let success = restoreGame()
                if !success {
                    // Only store failure result; success doesn't return
                    try storeResult(0)
                }
            } else {
                throw RuntimeError.unsupportedOperation("Extended RESTORE in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x02: // LOG_SHIFT
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }

            let value = UInt16(bitPattern: operands[0])
            let shift = operands[1]

            let result: UInt16
            if shift > 0 {
                result = value << Int(shift)
            } else if shift < 0 {
                result = value >> Int(-shift)
            } else {
                result = value
            }

            try storeResult(Int16(bitPattern: result))

        case 0x03: // ART_SHIFT
            guard operands.count >= 2 else {
                throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
            }

            let value = operands[0]
            let shift = operands[1]

            let result: Int16
            if shift > 0 {
                result = value << Int(shift)
            } else if shift < 0 {
                // Arithmetic right shift preserves sign
                result = value >> Int(-shift)
            } else {
                result = value
            }

            try storeResult(result)

        case 0x04: // SET_FONT (V5+)
            if version.rawValue >= 5 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Font setting - simplified implementation
                // Return previous font (0 = default)
                try storeResult(0)
            } else {
                throw RuntimeError.unsupportedOperation("SET_FONT in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x05: // SOUND_EFFECT (EXT opcode 5, v4+)
            if version.rawValue >= 4 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }

                let effect = UInt16(bitPattern: operands[0])
                let volume = operands.count > 1 ? UInt8(max(1, min(operands[1], 8))) : 8 // Default volume
                let repeats = operands.count > 2 ? UInt8(operands[2] & 0xFF) : 1
                let routine = operands.count > 3 ? UInt32(operands[3]) : 0

                let success = soundManager?.executeSoundEffect(
                    effect: effect,
                    volume: volume,
                    repeats: repeats,
                    routine: routine
                ) ?? false

                // Some games check the result to determine if sound is supported
                try storeResult(success ? 1 : 0)
            } else {
                throw RuntimeError.unsupportedOperation("SOUND_EFFECT in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x06: // DRAW_PICTURE (V6) - moved from 0x05
            if version.rawValue == 6 {
                guard operands.count >= 3 else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Graphics drawing - not implemented
                // Picture number, y, x coordinates
                // No-op for now
            } else {
                throw RuntimeError.unsupportedOperation("DRAW_PICTURE in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x07: // PICTURE_DATA (V6) - moved from 0x06
            if version.rawValue == 6 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Picture data query - not implemented
                // Return 0 (picture not available)
                try branchOnCondition(false)
            } else {
                throw RuntimeError.unsupportedOperation("PICTURE_DATA in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x08: // SET_MARGINS (V6) - moved from 0x08 (keeping original position)
            if version.rawValue == 6 {
                guard operands.count >= 2 else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Set margins - not implemented
                // No-op for now
            } else {
                throw RuntimeError.unsupportedOperation("SET_MARGINS in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x09: // SAVE_UNDO (V5+)
            if version.rawValue >= 5 {
                // v5+: Save UNDO state to memory (RAM-based save)
                do {
                    try saveUndo()
                    try storeResult(1) // Success
                } catch {
                    try storeResult(0) // Failure
                }
            } else {
                throw RuntimeError.unsupportedOperation("SAVE_UNDO in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x0A: // RESTORE_UNDO (V5+)
            if version.rawValue >= 5 {
                // v5+: Restore UNDO state from memory
                // Note: Success doesn't return (execution continues from UNDO point)
                do {
                    let success = try restoreUndo()
                    if !success {
                        // Only store failure result; success doesn't return
                        try storeResult(0)
                    }
                } catch {
                    try storeResult(0) // Failure
                }
            } else {
                throw RuntimeError.unsupportedOperation("RESTORE_UNDO in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x0B: // PRINT_UNICODE (V5+)
            if version.rawValue >= 5 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Print Unicode character using the enhanced method
                let charCode = UInt32(operands[0])
                try executePrintUnicode(charCode)
            } else {
                throw RuntimeError.unsupportedOperation("PRINT_UNICODE in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x0C: // CHECK_UNICODE (V5+)
            if version.rawValue >= 5 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Check if Unicode character can be displayed using enhanced method
                let charCode = UInt32(operands[0])
                let canDisplay = checkUnicodeSupport(charCode)
                try storeResult(canDisplay ? 3 : 0) // 3 = can input and output, 0 = cannot
            } else {
                throw RuntimeError.unsupportedOperation("CHECK_UNICODE in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x0D: // SET_TRUE_COLOUR (V5+)
            if version.rawValue >= 5 {
                guard operands.count >= 2 else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Set true color - not implemented
                // No-op for now
            } else {
                throw RuntimeError.unsupportedOperation("SET_TRUE_COLOUR in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x10: // MOVE_WINDOW (V6)
            if version.rawValue == 6 {
                guard operands.count >= 3 else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Move window - not implemented
                // No-op for now
            } else {
                throw RuntimeError.unsupportedOperation("MOVE_WINDOW in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x11: // WINDOW_SIZE (V6)
            if version.rawValue == 6 {
                guard operands.count >= 3 else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Set window size - not implemented
                // No-op for now
            } else {
                throw RuntimeError.unsupportedOperation("WINDOW_SIZE in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x12: // WINDOW_STYLE (V6)
            if version.rawValue == 6 {
                guard operands.count >= 2 else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Set window style - not implemented
                // No-op for now
            } else {
                throw RuntimeError.unsupportedOperation("WINDOW_STYLE in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x13: // GET_WIND_PROP (V6)
            if version.rawValue == 6 {
                guard operands.count >= 2 else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Get window property - not implemented
                // Return 0
                try storeResult(0)
            } else {
                throw RuntimeError.unsupportedOperation("GET_WIND_PROP in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x14: // SCROLL_WINDOW (V6)
            if version.rawValue == 6 {
                guard operands.count >= 2 else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Scroll window - not implemented
                // No-op for now
            } else {
                throw RuntimeError.unsupportedOperation("SCROLL_WINDOW in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x15: // POP_STACK (V6)
            if version.rawValue >= 6 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Pop multiple values from stack
                let items = Int(operands[0])
                for _ in 0..<items {
                    _ = popStack()
                }
            } else {
                throw RuntimeError.unsupportedOperation("POP_STACK in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x16: // READ_MOUSE (V6)
            if version.rawValue == 6 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Read mouse coordinates - not implemented
                // No-op for now
            } else {
                throw RuntimeError.unsupportedOperation("READ_MOUSE in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x17: // MOUSE_WINDOW (V6)
            if version.rawValue == 6 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Enable mouse in window - not implemented
                // No-op for now
            } else {
                throw RuntimeError.unsupportedOperation("MOUSE_WINDOW in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x18: // PUSH_STACK (V6)
            if version.rawValue >= 6 {
                guard operands.count >= 2 else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Push to user stack - simplified implementation
                try branchOnCondition(true)
            } else {
                throw RuntimeError.unsupportedOperation("PUSH_STACK in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x19: // PUT_WIND_PROP (V6)
            if version.rawValue == 6 {
                guard operands.count >= 3 else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Set window property - not implemented
                // No-op for now
            } else {
                throw RuntimeError.unsupportedOperation("PUT_WIND_PROP in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x1A: // PRINT_FORM (V6)
            if version.rawValue == 6 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Print formatted text - not implemented
                // No-op for now
            } else {
                throw RuntimeError.unsupportedOperation("PRINT_FORM in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x1B: // MAKE_MENU (V6)
            if version.rawValue == 6 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Create menu - not implemented
                // Return failure
                try branchOnCondition(false)
            } else {
                throw RuntimeError.unsupportedOperation("MAKE_MENU in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        case 0x1C: // PICTURE_TABLE (V6)
            if version.rawValue == 6 {
                guard !operands.isEmpty else {
                    throw RuntimeError.invalidMemoryAccess(Int(programCounter), location: SourceLocation.unknown)
                }
                // Set picture table - not implemented
                // No-op for now
            } else {
                throw RuntimeError.unsupportedOperation("PICTURE_TABLE in version \(version.rawValue)", location: SourceLocation.unknown)
            }

        default:
            throw RuntimeError.unsupportedOperation("Extended opcode 0x\(String(opcode, radix: 16, uppercase: true))", location: SourceLocation.unknown)
        }
    }

    // MARK: - Text Style and Color Instructions

    /// Execute SET_TEXT_STYLE instruction
    /// - Parameter styleFlags: Style flags (0-15)
    /// - Throws: RuntimeError for invalid operations or version restrictions
    func executeSetTextStyle(_ styleFlags: Int16) throws {
        // SET_TEXT_STYLE is supported in v4+, with some interpreters supporting it in v3
        if version.rawValue < 3 {
            // v1-2: No style support
            throw RuntimeError.unsupportedOperation("SET_TEXT_STYLE not supported in version \(version.rawValue)", location: SourceLocation.unknown)
        }

        // v3+: Allow style setting with version-appropriate restrictions
        let textStyle = convertToTextStyle(UInt8(styleFlags & 0xFF))

        // Version-specific style restrictions
        let allowedStyle = applyVersionStyleRestrictions(textStyle)

        windowManager?.getCurrentWindow()?.setStyle(allowedStyle)
    }

    /// Execute SET_COLOUR instruction
    /// - Parameters:
    ///   - foreground: Foreground color code (0-15)
    ///   - background: Background color code (0-15)
    ///   - window: Window number (-1 = current window)
    /// - Throws: RuntimeError for invalid operations
    func executeSetColour(foreground: Int16, background: Int16, window: Int16) throws {
        let fg = ZMachineColor.from(UInt8(foreground & 0xFF))
        let bg = ZMachineColor.from(UInt8(background & 0xFF))

        // Apply version-specific color restrictions
        let allowedFg = applyVersionColorRestrictions(fg)
        let allowedBg = applyVersionColorRestrictions(bg)

        if window == -1 {
            // Set colors for current window
            windowManager?.getCurrentWindow()?.setColors(foreground: allowedFg, background: allowedBg)
        } else {
            // Set colors for specific window
            windowManager?.getWindow(Int(window))?.setColors(foreground: allowedFg, background: allowedBg)
        }
    }

    /// Convert Z-Machine style flags to TextStyle
    /// - Parameter flags: Z-Machine style flags (0-15)
    /// - Returns: TextStyle option set
    private func convertToTextStyle(_ flags: UInt8) -> TextStyle {
        guard flags != 0 else {
            return .roman  // 0 = normal/roman text
        }

        var style: TextStyle = []
        if flags & 0x01 != 0 { style.insert(.reverse) }    // Bit 0: Reverse video
        if flags & 0x02 != 0 { style.insert(.bold) }       // Bit 1: Bold
        if flags & 0x04 != 0 { style.insert(.italic) }     // Bit 2: Italic
        if flags & 0x08 != 0 { style.insert(.fixedPitch) } // Bit 3: Fixed-pitch font

        return style
    }

    /// Apply version-specific style restrictions
    /// - Parameter style: Original style flags
    /// - Returns: Style flags adjusted for Z-Machine version compatibility
    private func applyVersionStyleRestrictions(_ style: TextStyle) -> TextStyle {
        switch version.rawValue {
        case 1...3:
            // v1-3: Very limited style support
            // Only reverse video and fixed-pitch are commonly supported
            return style.intersection([.reverse, .fixedPitch])

        case 4:
            // v4: Full basic style support
            // All standard styles are supported
            return style

        case 5...6:
            // v5-6: Full style support with colors
            // All styles supported
            return style

        case 7...8:
            // v7-8: Extended style support
            // All styles supported with potential extensions
            return style

        default:
            // Unknown version - be conservative
            return style.intersection([.reverse, .fixedPitch])
        }
    }

    /// Apply version-specific color restrictions
    /// - Parameter color: Original color code
    /// - Returns: Color adjusted for Z-Machine version compatibility
    private func applyVersionColorRestrictions(_ color: ZMachineColor) -> ZMachineColor {
        switch version.rawValue {
        case 1...4:
            // v1-4: No color support - return default
            return .default

        case 5:
            // v5: Standard color support (colors 0-9)
            if color.rawValue > 9 {
                return .default
            }
            return color

        case 6...8:
            // v6-8: Full color support including grey shades (colors 0-13)
            return color

        default:
            // Unknown version - no color support
            return .default
        }
    }
}