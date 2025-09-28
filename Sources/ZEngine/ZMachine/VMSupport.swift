/// Z-Machine VM Support Methods - Operand handling, variables, text, and utilities
import Foundation

// MARK: - Operand and Variable Handling
extension ZMachine {

    /// Operand types for Z-Machine instructions
    enum OperandType: UInt8 {
        case largeConstant = 0x00  // 2-byte constant
        case smallConstant = 0x01  // 1-byte constant
        case variable = 0x02       // Variable reference
        case omitted = 0x03        // No operand
    }

    /// Read operand types for 2OP instructions
    func read2OPOperandTypes(_ opcode: UInt8) -> (OperandType, OperandType) {
        let type1: OperandType = ((opcode & 0x40) != 0) ? .variable : .smallConstant
        let type2: OperandType = ((opcode & 0x20) != 0) ? .variable : .smallConstant
        return (type1, type2)
    }

    /// Read variable number of operands based on operand type byte
    func readVarOperands(_ operandTypeByte: UInt8) throws -> [Int16] {
        var operands: [Int16] = []

        for i in 0..<4 {
            let typeCode = (operandTypeByte >> (6 - i * 2)) & 0x03
            guard let operandType = OperandType(rawValue: typeCode) else { continue }

            if operandType == .omitted {
                break
            }

            let operand = try readOperand(type: operandType)
            operands.append(operand)
        }

        return operands
    }

    /// Read a single operand based on its type
    func readOperand(type: OperandType) throws -> Int16 {
        switch type {
        case .largeConstant:
            let value = try readWord(at: programCounter)
            programCounter += 2
            return Int16(bitPattern: value)

        case .smallConstant:
            let value = try readByte(at: programCounter)
            programCounter += 1
            return Int16(value)

        case .variable:
            let variableNumber = try readByte(at: programCounter)
            programCounter += 1
            return try readVariable(variableNumber)

        case .omitted:
            return 0
        }
    }

    /// Read value from a variable
    func readVariable(_ variableNumber: UInt8) throws -> Int16 {
        if variableNumber == 0 {
            // Stack
            return try popStack()
        } else if variableNumber <= 15 {
            // Local variables (1-15)
            let localIndex = Int(variableNumber - 1)
            guard localIndex < locals.count else {
                return 0 // Undefined local variables are 0
            }
            return Int16(bitPattern: locals[localIndex])
        } else {
            // Global variables (16-255 -> globals 0-239)
            let globalIndex = Int(variableNumber - 16)
            guard globalIndex < globals.count else {
                throw RuntimeError.invalidMemoryAccess(globalIndex, location: SourceLocation.unknown)
            }
            return Int16(bitPattern: globals[globalIndex])
        }
    }

    /// Write value to a variable
    func writeVariable(_ variableNumber: UInt8, value: Int16) throws {
        if variableNumber == 0 {
            // Stack
            try pushStack(value)
        } else if variableNumber <= 15 {
            // Local variables (1-15)
            let localIndex = Int(variableNumber - 1)

            // Extend locals array if necessary
            while localIndex >= locals.count {
                locals.append(0)
            }

            locals[localIndex] = UInt16(bitPattern: value)
        } else {
            // Global variables (16-255 -> globals 0-239)
            let globalIndex = Int(variableNumber - 16)
            guard globalIndex < globals.count else {
                throw RuntimeError.invalidMemoryAccess(globalIndex, location: SourceLocation.unknown)
            }
            globals[globalIndex] = UInt16(bitPattern: value)
        }
    }

    /// Store result in the variable specified by the next instruction byte
    func storeResult(_ value: Int16) throws {
        let variableNumber = try readByte(at: programCounter)
        programCounter += 1
        try writeVariable(variableNumber, value: value)
    }

    /// Handle branch instructions
    func branchOnCondition(_ condition: Bool) throws {
        let branchByte = try readByte(at: programCounter)
        programCounter += 1

        let shouldBranch = ((branchByte & 0x80) != 0) == condition
        let offsetHigh = branchByte & 0x3F

        let offset: Int16
        if (branchByte & 0x40) != 0 {
            // Single-byte offset
            offset = Int16(offsetHigh)
        } else {
            // Two-byte offset
            let offsetLow = try readByte(at: programCounter)
            programCounter += 1

            let fullOffset = (UInt16(offsetHigh) << 8) | UInt16(offsetLow)
            // Sign-extend 14-bit value
            if (fullOffset & 0x2000) != 0 {
                offset = Int16(fullOffset | 0xC000) // Extend sign
            } else {
                offset = Int16(fullOffset)
            }
        }

        if shouldBranch {
            if offset == 0 {
                // Return false
                try returnFromRoutine(value: 0)
            } else if offset == 1 {
                // Return true
                try returnFromRoutine(value: 1)
            } else {
                // Jump to offset
                programCounter = UInt32(Int32(programCounter) + Int32(offset) - 2)
            }
        }
    }
}

// MARK: - Routine Call Management
extension ZMachine {

    /// Call a routine with arguments
    func callRoutine(_ packedAddress: UInt32, arguments: [Int16]) throws -> Int16 {
        if packedAddress == 0 {
            // Call to address 0 returns false immediately
            return 0
        }

        let routineAddress = unpackAddress(packedAddress, type: .routine)

        // Create new stack frame
        let frame = StackFrame(
            returnPC: programCounter,
            localCount: locals.count,
            locals: locals,
            evaluationStackBase: evaluationStack.count
        )
        callStack.append(frame)

        // Set up new routine
        programCounter = routineAddress

        // Read local variable count
        let localCount = try readByte(at: programCounter)
        programCounter += 1

        // Initialize new locals
        locals.removeAll()

        // Set up local variables with initial values (v1-4) or arguments (v5+)
        if version.rawValue <= 4 {
            // v1-4: locals have initial values in routine header
            for i in 0..<Int(localCount) {
                let initialValue = try readWord(at: programCounter)
                programCounter += 2

                // Set argument value if provided, otherwise use initial value
                let value = i < arguments.count ? UInt16(bitPattern: arguments[i]) : initialValue
                locals.append(value)
            }
        } else {
            // v5+: locals start at 0, only set arguments
            for i in 0..<Int(localCount) {
                let value = i < arguments.count ? UInt16(bitPattern: arguments[i]) : 0
                locals.append(value)
            }
        }

        return 0 // Return value will be set by RTRUE/RFALSE/RET
    }

    /// Return from current routine
    func returnFromRoutine(value: Int16) throws {
        guard !callStack.isEmpty else {
            // Return from main routine - quit the program
            hasQuit = true
            isRunning = false
            return
        }

        let frame = callStack.removeLast()

        // Restore previous state
        programCounter = frame.returnPC
        locals = frame.locals

        // Restore evaluation stack
        while evaluationStack.count > frame.evaluationStackBase {
            _ = evaluationStack.removeLast()
        }

        // Store return value in the calling routine's result variable
        try storeResult(value)
    }
}

// MARK: - Text Processing
extension ZMachine {

    /// Z-String reading result
    struct ZStringResult {
        let string: String
        let nextAddress: UInt32
    }

    /// Read a Z-encoded string from memory
    func readZString(at address: UInt32) throws -> ZStringResult {
        var currentAddress = address
        var zchars: [UInt8] = []

        // Read Z-string words until end bit is set
        while true {
            let word = try readWord(at: currentAddress)
            currentAddress += 2

            // Extract three 5-bit Z-characters
            let char1 = UInt8((word >> 10) & 0x1F)
            let char2 = UInt8((word >> 5) & 0x1F)
            let char3 = UInt8(word & 0x1F)

            zchars.append(char1)
            zchars.append(char2)
            zchars.append(char3)

            // Stop if end bit is set
            if (word & 0x8000) != 0 {
                break
            }
        }

        let decodedString = try decodeZString(zchars)
        return ZStringResult(string: decodedString, nextAddress: currentAddress)
    }

    /// Decode Z-characters into text
    func decodeZString(_ zchars: [UInt8]) throws -> String {
        var result = ""
        var currentAlphabet = 0
        var i = 0

        // Character sets for Z-Machine text
        let alphabet0 = "abcdefghijklmnopqrstuvwxyz"
        let alphabet1 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let alphabet2 = " \n0123456789.,!?_#'\"/\\-:()"

        while i < zchars.count {
            let zchar = zchars[i]

            if zchar == 0 {
                // Null character - space
                result += " "
            } else if zchar <= 3 {
                // Abbreviations - Z-chars 1, 2, 3 followed by abbreviation number (0-31)
                if i + 1 < zchars.count {
                    let abbrevNumber = zchars[i + 1]

                    // Calculate abbreviation table index
                    // A0 (zchar 1): entries 0-31
                    // A1 (zchar 2): entries 32-63
                    // A2 (zchar 3): entries 64-95
                    let abbrevIndex = Int((zchar - 1) * 32 + abbrevNumber)

                    if abbrevIndex < abbreviationTable.count && abbreviationTable[abbrevIndex] != 0 {
                        // Get the address of the abbreviated string
                        let abbrevStringAddress = abbreviationTable[abbrevIndex]

                        do {
                            // Read and decode the abbreviated string recursively
                            let abbrevResult = try readZString(at: abbrevStringAddress)
                            result += abbrevResult.string
                        } catch {
                            // If abbreviation expansion fails, add a space as fallback
                            result += " "
                        }
                    } else {
                        // Invalid or missing abbreviation - add space as fallback
                        result += " "
                    }

                    i += 1  // Skip the abbreviation number
                } else {
                    // Incomplete abbreviation sequence - add space
                    result += " "
                }
            } else if zchar == 4 {
                // Shift to alphabet 1
                currentAlphabet = 1
            } else if zchar == 5 {
                // Shift to alphabet 2, or ZSCII escape
                if i + 1 < zchars.count && zchars[i + 1] == 6 {
                    // ZSCII escape sequence
                    if i + 4 < zchars.count {
                        let high = zchars[i + 2]
                        let low = zchars[i + 3]
                        let asciiValue = (high << 5) | low

                        if let scalar = UnicodeScalar(Int(asciiValue)) {
                            result += String(Character(scalar))
                        }

                        i += 4 // Skip escape sequence
                        continue
                    }
                } else {
                    currentAlphabet = 2
                }
            } else {
                // Regular character (6-31)
                let charIndex = Int(zchar - 6)

                switch currentAlphabet {
                case 0:
                    if charIndex < alphabet0.count {
                        let alphabetIndex = alphabet0.index(alphabet0.startIndex, offsetBy: charIndex)
                        result += String(alphabet0[alphabetIndex])
                    }
                case 1:
                    if charIndex < alphabet1.count {
                        let alphabetIndex = alphabet1.index(alphabet1.startIndex, offsetBy: charIndex)
                        result += String(alphabet1[alphabetIndex])
                    }
                case 2:
                    if charIndex < alphabet2.count {
                        let alphabetIndex = alphabet2.index(alphabet2.startIndex, offsetBy: charIndex)
                        result += String(alphabet2[alphabetIndex])
                    }
                default:
                    break
                }

                // Reset to alphabet 0 after one character (except for shift 4)
                if currentAlphabet == 2 {
                    currentAlphabet = 0
                }
            }

            i += 1
        }

        return result
    }
}