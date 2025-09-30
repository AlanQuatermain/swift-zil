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
    func readVarOperands(_ operandTypeByte: UInt8, maxOperands: Int = 4) throws -> [Int16] {
        var operands: [Int16] = []

        let operandLimit = min(maxOperands, 4)  // Never exceed 4 operands per instruction
        for i in 0..<operandLimit {
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
        let operand: Int16
        switch type {
        case .largeConstant:
            let value = try readWord(at: programCounter)
            programCounter += 2
            operand = Int16(bitPattern: value)

        case .smallConstant:
            let value = try readByte(at: programCounter)
            programCounter += 1
            // Small constants are unsigned 8-bit values (0-255)
            // When converted to signed 16-bit, they should remain positive
            operand = Int16(value)

        case .variable:
            let variableNumber = try readByte(at: programCounter)
            programCounter += 1
            operand = try readVariable(variableNumber)

        case .omitted:
            operand = 0
        }

        // Update post-decode PC to track bytes consumed during operand reading
        postDecodePC = programCounter

        // Add operand to trace
        traceOperand(operand)
        return operand
    }

    /// Read value from a variable
    func readVariable(_ variableNumber: UInt8) throws -> Int16 {
        if variableNumber == 0 {
            // Stack
            return popStack()
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
            let value = Int16(bitPattern: globals[globalIndex])

            return value
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
            // Single-byte offset (6-bit unsigned value: 0-63)
            // Z-Machine spec treats 6-bit offsets as unsigned, not signed
            offset = Int16(offsetHigh)
        } else {
            // Two-byte offset
            let offsetLow = try readByte(at: programCounter)
            programCounter += 1

            let fullOffset = (UInt16(offsetHigh) << 8) | UInt16(offsetLow)
            // Sign-extend 14-bit value
            if (fullOffset & 0x2000) != 0 {
                offset = Int16(bitPattern: fullOffset | 0xC000) // Extend sign safely
            } else {
                offset = Int16(bitPattern: fullOffset)
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
        // Debug: Log string decoding attempts for object short names (commented out)
        /*
        let shouldLog = address >= 0x3900 && address <= 0x3910 // Focus on Object 1's address range
        if shouldLog {
            print("DEBUG: readZString called at address=0x\(String(address, radix: 16, uppercase: true))")
        }
        */

        var currentAddress = address
        var zchars: [UInt8] = []

        // Read Z-string words until end bit is set
        while true {
            let word = try readWord(at: currentAddress)

            /*
            if shouldLog {
                print("DEBUG: readZString word at 0x\(String(currentAddress, radix: 16)): 0x\(String(word, radix: 16, uppercase: true))")
            }
            */

            currentAddress += 2

            // Extract three 5-bit Z-characters
            let char1 = UInt8((word >> 10) & 0x1F)
            let char2 = UInt8((word >> 5) & 0x1F)
            let char3 = UInt8(word & 0x1F)

            /*
            if shouldLog {
                print("DEBUG: Z-chars from word: \(char1), \(char2), \(char3)")
            }
            */

            zchars.append(char1)
            zchars.append(char2)
            zchars.append(char3)

            // Stop if end bit is set
            if (word & 0x8000) != 0 {
                /*
                if shouldLog {
                    print("DEBUG: End bit set, stopping Z-string read")
                }
                */
                break
            }
        }

        let decodedString = try decodeZString(zchars)

        /*
        if shouldLog {
            print("DEBUG: readZString result at 0x\(String(address, radix: 16, uppercase: true)): \"\(decodedString)\" (next: 0x\(String(currentAddress, radix: 16, uppercase: true)))")
        }
        */

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

        // Debug mode flag - temporarily enable to debug abbreviation issues
        let debugDecoding = false

        while i < zchars.count {
            let zchar = zchars[i]

            if debugDecoding {
                print("🔤 Z-char[\(i)]: \(zchar) (alphabet: \(currentAlphabet))")
            }

            if zchar == 0 {
                // Null character - space
                result += " "
            } else if zchar <= 3 {
                // Abbreviations - Z-chars 1, 2, 3 followed by abbreviation number (0-31)
                if i + 1 < zchars.count {
                    let abbrevNumber = zchars[i + 1]

                    // CRITICAL FIX: Validate abbreviation number range
                    guard abbrevNumber <= 31 else {
                        if debugDecoding {
                            print("❌ Invalid abbreviation number: \(abbrevNumber) (must be 0-31)")
                        }
                        // Skip invalid abbreviation sequence entirely
                        i += 1
                        i += 1
                        continue
                    }

                    // Calculate abbreviation table index
                    // A0 (zchar 1): entries 0-31
                    // A1 (zchar 2): entries 32-63
                    // A2 (zchar 3): entries 64-95
                    let abbrevIndex = Int((zchar - 1) * 32 + abbrevNumber)

                    if debugDecoding {
                        print("📝 Abbreviation A\(zchar-1)[\(abbrevNumber)] -> index \(abbrevIndex)")
                    }

                    // CRITICAL FIX: More thorough validation
                    guard abbrevIndex >= 0 && abbrevIndex < abbreviationTable.count else {
                        if debugDecoding {
                            print("❌ Abbreviation index \(abbrevIndex) out of bounds (table size: \(abbreviationTable.count))")
                        }
                        // Skip invalid abbreviation sequence entirely
                        i += 1
                        i += 1
                        continue
                    }

                    let abbrevStringAddress = abbreviationTable[abbrevIndex]

                    // CRITICAL FIX: Check for null address
                    guard abbrevStringAddress != 0 else {
                        if debugDecoding {
                            print("❌ Abbreviation \(abbrevIndex) has null address")
                        }
                        // Skip null abbreviation sequence entirely
                        i += 1
                        i += 1
                        continue
                    }

                    do {
                        // Read and decode the abbreviated string recursively
                        let abbrevResult = try readZString(at: abbrevStringAddress)
                        if debugDecoding {
                            print("✅ Expanded abbreviation \(abbrevIndex): '\(abbrevResult.string)'")
                        }
                        result += abbrevResult.string
                    } catch {
                        if debugDecoding {
                            print("❌ Failed to expand abbreviation \(abbrevIndex): \(error)")
                        }
                        // CRITICAL FIX: Don't add anything for failed abbreviations
                        // The Z-Machine spec says invalid abbreviations should be ignored
                    }

                    i += 1  // Skip the abbreviation number
                } else {
                    // Incomplete abbreviation sequence - skip the incomplete Z-char
                    if debugDecoding {
                        print("❌ Incomplete abbreviation sequence at end of string")
                    }
                }
            } else if zchar == 4 {
                // Shift to alphabet 1
                currentAlphabet = 1
            } else if zchar == 5 {
                // Shift to alphabet 2, or ZSCII escape
                if i + 1 < zchars.count && zchars[i + 1] == 6 {
                    // ZSCII escape sequence
                    if i + 4 <= zchars.count {
                        let high = zchars[i + 2]
                        let low = zchars[i + 3]
                        let zsciiValue = (high << 5) | low

                        if debugDecoding {
                            print("🔤 ZSCII escape: \(zsciiValue)")
                        }

                        // For v5+, use Unicode translation for extended ZSCII characters
                        if version.rawValue >= 5 && zsciiValue >= 155 && zsciiValue <= 223 {
                            let unicodeValue = zsciiToUnicode(UInt8(zsciiValue))
                            if let scalar = UnicodeScalar(unicodeValue) {
                                result += String(Character(scalar))
                            }
                        } else {
                            // Direct ZSCII to Unicode mapping for standard characters
                            if let scalar = UnicodeScalar(Int(zsciiValue)) {
                                result += String(Character(scalar))
                            }
                        }

                        i += 4 // Skip entire escape sequence (continue skips normal increment)
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
                    } else {
                        // Invalid character index - add placeholder
                        result += "?"
                        if debugDecoding {
                            print("❌ Invalid alphabet0 index: \(charIndex)")
                        }
                    }
                case 1:
                    if charIndex < alphabet1.count {
                        let alphabetIndex = alphabet1.index(alphabet1.startIndex, offsetBy: charIndex)
                        result += String(alphabet1[alphabetIndex])
                    } else {
                        // Invalid character index - add placeholder
                        result += "?"
                        if debugDecoding {
                            print("❌ Invalid alphabet1 index: \(charIndex)")
                        }
                    }
                case 2:
                    if charIndex < alphabet2.count {
                        let alphabetIndex = alphabet2.index(alphabet2.startIndex, offsetBy: charIndex)
                        result += String(alphabet2[alphabetIndex])
                    } else {
                        // Invalid character index - add placeholder
                        result += "?"
                        if debugDecoding {
                            print("❌ Invalid alphabet2 index: \(charIndex)")
                        }
                    }
                default:
                    // Unknown alphabet - add placeholder
                    result += "?"
                    if debugDecoding {
                        print("❌ Unknown alphabet: \(currentAlphabet)")
                    }
                }

                // Reset to alphabet 0 after one character (shifts are temporary)
                if currentAlphabet == 1 || currentAlphabet == 2 {
                    currentAlphabet = 0
                }
            }

            i += 1
        }

        return result
    }
}

// MARK: - Debug Support for Text Decoding
extension ZMachine {

    /// Debug structure for abbreviation analysis
    public struct AbbreviationDebugInfo {
        public let index: Int
        public let tableType: String  // A0, A1, A2
        public let abbrevNumber: Int
        public let address: UInt32
        public let isValid: Bool
        public let content: String?
        public let error: String?
    }

    /// Analyze abbreviation table for debugging
    public func analyzeAbbreviationTable() -> [AbbreviationDebugInfo] {
        var results: [AbbreviationDebugInfo] = []

        for i in 0..<min(abbreviationTable.count, 96) {
            let tableType: String
            let abbrevNumber: Int

            if i < 32 {
                tableType = "A0"
                abbrevNumber = i
            } else if i < 64 {
                tableType = "A1"
                abbrevNumber = i - 32
            } else {
                tableType = "A2"
                abbrevNumber = i - 64
            }

            let address = abbreviationTable[i]
            var content: String? = nil
            var error: String? = nil
            let isValid = address != 0

            if isValid {
                do {
                    let result = try readZString(at: address)
                    content = result.string
                } catch let catchError {
                    error = "Failed to read: \(catchError)"
                }
            }

            results.append(AbbreviationDebugInfo(
                index: i,
                tableType: tableType,
                abbrevNumber: abbrevNumber,
                address: address,
                isValid: isValid,
                content: content,
                error: error
            ))
        }

        return results
    }

    /// Debug Z-string decoding with detailed tracing
    public func debugDecodeZString(_ zchars: [UInt8], verbose: Bool = true) -> (result: String, trace: [String]) {
        var result = ""
        var trace: [String] = []
        var currentAlphabet = 0
        var i = 0

        // Character sets for Z-Machine text
        let alphabet0 = "abcdefghijklmnopqrstuvwxyz"
        let alphabet1 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let alphabet2 = " \n0123456789.,!?_#'\"/\\-:()"

        trace.append("🔤 Decoding Z-string with \(zchars.count) characters: \(zchars)")

        while i < zchars.count {
            let zchar = zchars[i]
            trace.append("📍 Position \(i): Z-char=\(zchar), alphabet=\(currentAlphabet)")

            if zchar == 0 {
                result += " "
                trace.append("  ➜ Space character")
            } else if zchar <= 3 {
                if i + 1 < zchars.count {
                    let abbrevNumber = zchars[i + 1]
                    trace.append("  📝 Abbreviation: type=A\(zchar-1), number=\(abbrevNumber)")

                    if abbrevNumber > 31 {
                        trace.append("  ❌ Invalid abbreviation number \(abbrevNumber) (must be 0-31)")
                        i += 1
                        i += 1
                        continue
                    }

                    let abbrevIndex = Int((zchar - 1) * 32 + abbrevNumber)
                    trace.append("  📍 Calculated index: \(abbrevIndex)")

                    if abbrevIndex >= 0 && abbrevIndex < abbreviationTable.count {
                        let abbrevStringAddress = abbreviationTable[abbrevIndex]
                        trace.append("  📍 Address: 0x\(String(abbrevStringAddress, radix: 16))")

                        if abbrevStringAddress != 0 {
                            do {
                                let abbrevResult = try readZString(at: abbrevStringAddress)
                                result += abbrevResult.string
                                trace.append("  ✅ Expanded to: '\(abbrevResult.string)'")
                            } catch {
                                trace.append("  ❌ Expansion failed: \(error)")
                            }
                        } else {
                            trace.append("  ❌ Null address for abbreviation")
                        }
                    } else {
                        trace.append("  ❌ Index out of bounds (table size: \(abbreviationTable.count))")
                    }

                    i += 1  // Skip abbreviation number
                } else {
                    trace.append("  ❌ Incomplete abbreviation at end of string")
                }
            } else if zchar == 4 {
                currentAlphabet = 1
                trace.append("  🔄 Shift to alphabet 1 (uppercase)")
            } else if zchar == 5 {
                if i + 1 < zchars.count && zchars[i + 1] == 6 {
                    if i + 4 <= zchars.count {
                        let high = zchars[i + 2]
                        let low = zchars[i + 3]
                        let zsciiValue = (high << 5) | low
                        trace.append("  🔤 ZSCII escape: \(zsciiValue)")

                        if version.rawValue >= 5 && zsciiValue >= 155 && zsciiValue <= 223 {
                            let unicodeValue = zsciiToUnicode(UInt8(zsciiValue))
                            if let scalar = UnicodeScalar(unicodeValue) {
                                result += String(Character(scalar))
                                trace.append("  ✅ Unicode character: '\(Character(scalar))'")
                            }
                        } else {
                            if let scalar = UnicodeScalar(Int(zsciiValue)) {
                                result += String(Character(scalar))
                                trace.append("  ✅ Direct ZSCII: '\(Character(scalar))'")
                            }
                        }

                        i += 4
                        continue
                    }
                } else {
                    currentAlphabet = 2
                    trace.append("  🔄 Shift to alphabet 2 (symbols)")
                }
            } else {
                let charIndex = Int(zchar - 6)
                let alphabet: String
                var charResult = ""

                switch currentAlphabet {
                case 0:
                    alphabet = "alphabet0"
                    if charIndex < alphabet0.count {
                        let alphabetIndex = alphabet0.index(alphabet0.startIndex, offsetBy: charIndex)
                        charResult = String(alphabet0[alphabetIndex])
                        result += charResult
                    } else {
                        charResult = "?"
                        result += charResult
                        trace.append("  ❌ Invalid alphabet0 index: \(charIndex)")
                    }
                case 1:
                    alphabet = "alphabet1"
                    if charIndex < alphabet1.count {
                        let alphabetIndex = alphabet1.index(alphabet1.startIndex, offsetBy: charIndex)
                        charResult = String(alphabet1[alphabetIndex])
                        result += charResult
                    } else {
                        charResult = "?"
                        result += charResult
                        trace.append("  ❌ Invalid alphabet1 index: \(charIndex)")
                    }
                case 2:
                    alphabet = "alphabet2"
                    if charIndex < alphabet2.count {
                        let alphabetIndex = alphabet2.index(alphabet2.startIndex, offsetBy: charIndex)
                        charResult = String(alphabet2[alphabetIndex])
                        result += charResult
                    } else {
                        charResult = "?"
                        result += charResult
                        trace.append("  ❌ Invalid alphabet2 index: \(charIndex)")
                    }
                default:
                    alphabet = "unknown"
                    charResult = "?"
                    result += charResult
                    trace.append("  ❌ Unknown alphabet: \(currentAlphabet)")
                }

                trace.append("  ✅ Character '\(charResult)' from \(alphabet)[\(charIndex)]")

                // Reset alphabet after character
                if currentAlphabet == 1 || currentAlphabet == 2 {
                    currentAlphabet = 0
                    trace.append("  🔄 Reset to alphabet 0")
                }
            }

            i += 1
        }

        trace.append("🏁 Final result: '\(result)'")

        if verbose {
            for line in trace {
                print(line)
            }
        }

        return (result: result, trace: trace)
    }

    /// Validate abbreviation table consistency
    public func validateAbbreviationTable() -> [String] {
        var issues: [String] = []

        // Check table size
        if abbreviationTable.count != 96 {
            issues.append("❌ Abbreviation table has \(abbreviationTable.count) entries (should be 96)")
        }

        // Check for null entries and validate addresses
        var nullCount = 0
        var invalidAddresses = 0

        for (index, address) in abbreviationTable.enumerated() {
            if address == 0 {
                nullCount += 1
            } else {
                // Validate address is within memory bounds
                if !isValidAddress(address) {
                    invalidAddresses += 1
                    issues.append("❌ Abbreviation \(index) has invalid address: 0x\(String(address, radix: 16))")
                }
            }
        }

        if nullCount > 0 {
            issues.append("ℹ️  \(nullCount) abbreviations have null addresses (this may be normal)")
        }

        if invalidAddresses > 0 {
            issues.append("❌ \(invalidAddresses) abbreviations have invalid addresses")
        }

        return issues
    }

    /// Read object short description from property table
    ///
    /// - Parameter objectNumber: Object number (1-based)
    /// - Returns: Decoded short description string, or empty string if object not found
    /// - Throws: RuntimeError for memory access or decoding errors
    public func readObjectShortDescription(_ objectNumber: UInt16) throws -> String {
        guard let object = objectTree.getObject(objectNumber) else {
            // print("DEBUG: readObjectShortDescription - object \(objectNumber) not found")
            return ""
        }

        let propertyTableAddress = object.getPropertyTableAddress()
        guard propertyTableAddress > 0 else {
            // print("DEBUG: readObjectShortDescription - object \(objectNumber) has no property table")
            return ""
        }

        // print("DEBUG: readObjectShortDescription - property table address: 0x\(String(propertyTableAddress, radix: 16, uppercase: true))")

        // Property table address is now already absolute
        let absoluteAddress = UInt32(propertyTableAddress)
        // print("DEBUG: readObjectShortDescription - object \(objectNumber), property table at 0x\(String(absoluteAddress, radix: 16, uppercase: true))")

        // Read text length byte
        let textLength = try readByte(at: absoluteAddress)
        // print("DEBUG: readObjectShortDescription - text length: \(textLength) words")
        // print("DEBUG: readObjectShortDescription - raw byte at address: 0x\(String(textLength, radix: 16, uppercase: true))")

        // Let's examine the next few bytes to see what's really there (commented out)
        /*
        print("DEBUG: Raw bytes at property table address:")
        for i in 0..<16 {
            if absoluteAddress + UInt32(i) < UInt32(storyData.count) {
                let byte = try readByte(at: absoluteAddress + UInt32(i))
                let charRepresentation = (byte >= 32 && byte <= 126) ? " '\(Character(UnicodeScalar(byte) ?? UnicodeScalar(63)!))'" : ""
                print("DEBUG: Byte at +\(i): 0x\(String(byte, radix: 16, uppercase: true)) (\(byte))\(charRepresentation)")
            }
        }
        */

        guard textLength > 0 else {
            // print("DEBUG: readObjectShortDescription - object \(objectNumber) has empty short description")
            return ""
        }

        // Short description starts immediately after length byte
        let textAddress = absoluteAddress + 1
        // print("DEBUG: readObjectShortDescription - reading text from 0x\(String(textAddress, radix: 16, uppercase: true))")

        // Read the Z-string directly
        let result = try readZString(at: textAddress)
        // print("DEBUG: readObjectShortDescription - decoded: \"\(result.string)\"")

        return result.string
    }
    private func isValidAddress(_ address: UInt32) -> Bool {
        // Check if address is within any memory region
        if address < UInt32(dynamicMemory.count) {
            return true
        }

        let staticBase = header.staticMemoryBase
        if address >= staticBase && address < staticBase + UInt32(staticMemory.count) {
            return true
        }

        let highBase = header.highMemoryBase
        if address >= highBase && address < highBase + UInt32(highMemory.count) {
            return true
        }

        return false
    }

    /// Debug structure for high memory string analysis
    public struct HighMemoryStringInfo {
        public let index: Int
        public let address: UInt32
        public let content: String
    }

    /// Analyze strings found in high memory
    public func analyzeHighMemoryStrings() -> [HighMemoryStringInfo] {
        var results: [HighMemoryStringInfo] = []
        let highMemoryStart = header.highMemoryBase
        let highMemorySize = UInt32(storyData.count) - highMemoryStart

        var stringCount = 0
        var currentAddress = highMemoryStart

        // Scan through high memory looking for potential Z-strings
        while currentAddress < UInt32(storyData.count) - 2 {
            do {
                // Try to read a word to see if it looks like the start of a Z-string
                let word = try readWord(at: currentAddress)

                // Check if this could be the start of a Z-string
                if isLikelyZStringStart(word) {
                    do {
                        let result = try readZString(at: currentAddress)

                        // Filter out very short or suspicious strings
                        if result.string.count >= 2 && isValidString(result.string) {
                            stringCount += 1
                            results.append(HighMemoryStringInfo(
                                index: stringCount,
                                address: currentAddress,
                                content: result.string
                            ))

                            // Skip past this string to avoid overlapping reads
                            currentAddress = result.nextAddress
                            continue
                        }
                    } catch {
                        // Not a valid Z-string, continue scanning
                    }
                }

                // Move to next word boundary
                currentAddress += 2
            } catch {
                // End of memory or read error
                break
            }
        }

        return results
    }

    /// Check if a word looks like the start of a Z-string
    private func isLikelyZStringStart(_ word: UInt16) -> Bool {
        // Extract the three 5-bit Z-characters
        let char1 = UInt8((word >> 10) & 0x1F)
        let char2 = UInt8((word >> 5) & 0x1F)
        let char3 = UInt8(word & 0x1F)

        // Check if these look like reasonable Z-characters
        // Z-characters 0-5 are special (space, abbreviations, shifts)
        // Z-characters 6-31 map to alphabet characters

        // If all three characters are in the printable range (6-31) or special range (0-5), it's likely a string
        let isChar1Valid = char1 <= 31
        let isChar2Valid = char2 <= 31
        let isChar3Valid = char3 <= 31

        return isChar1Valid && isChar2Valid && isChar3Valid
    }

    /// Validate if a decoded string looks legitimate
    private func isValidString(_ string: String) -> Bool {
        // Filter out strings that are likely false positives

        // Must contain some letters
        let hasLetters = string.unicodeScalars.contains { scalar in
            CharacterSet.letters.contains(scalar)
        }

        // Must not be all control characters or whitespace
        let hasVisibleContent = string.trimmingCharacters(in: .whitespacesAndNewlines).count > 0

        // Must not contain too many unusual characters
        let unusualCharCount = string.unicodeScalars.filter { scalar in
            !CharacterSet.alphanumerics.contains(scalar) &&
            !CharacterSet.punctuationCharacters.contains(scalar) &&
            !CharacterSet.whitespaces.contains(scalar)
        }.count

        let unusualRatio = Double(unusualCharCount) / Double(string.count)

        return hasLetters && hasVisibleContent && unusualRatio < 0.3
    }

    /// Object property information for analysis
    public struct ObjectPropertyInfo {
        public let objectNumber: UInt16
        public let propertyNumber: UInt8
        public let propertyName: String
        public let rawValue: UInt16
        public let decodedString: String?
        public let addressInfo: String  // Debug info about address interpretation
    }

    /// Analyze an object's properties with decoded string content
    public func analyzeObjectProperties(_ objectNumber: UInt16) -> [ObjectPropertyInfo] {
        var properties: [ObjectPropertyInfo] = []

        // Get all properties for this object by scanning the property table directly
        // This is more accurate than assuming fixed property numbers
        let allProperties = objectTree.getAllProperties(objectNumber)

        for (propNum, value) in allProperties.sorted(by: { $0.key < $1.key }) {
            var decodedString: String? = nil
            var addressInfo = "raw=0x\(String(value, radix: 16, uppercase: true))"
            var propName = "property \(propNum)"

            // Try to determine property meaning from common Z-Machine conventions
            switch propNum {
            case 1: propName = "property 1 (often short description)"
            case 2: propName = "property 2 (often long description)"
            case 3: propName = "property 3 (often initial location)"
            case 4: propName = "property 4 (often action routine)"
            case 5: propName = "property 5 (often vocabulary)"
            case 6: propName = "property 6 (often grammar)"
            default: propName = "property \(propNum)"
            }

            // Try to decode as string with strict validation
            // First try as packed string address (most common for descriptions)
            do {
                let unpackedAddress = unpackAddress(UInt32(value), type: .string)
                addressInfo += ", unpacked=0x\(String(unpackedAddress, radix: 16, uppercase: true))"

                // Validate the unpacked address is in high memory and reasonable
                if unpackedAddress >= header.highMemoryBase && unpackedAddress < UInt32(storyData.count) {
                    let result = try readZString(at: unpackedAddress)

                    // Strict validation - only accept valid Z-Machine text strings
                    if isValidZString(result.string) {
                        decodedString = result.string
                        addressInfo += " (packed string address)"
                    }
                }
            } catch {
                // Packed address failed, try direct address (less common)
                do {
                    // Only try direct addresses that are in high memory
                    if value >= header.highMemoryBase && UInt32(value) < UInt32(storyData.count) {
                        let result = try readZString(at: UInt32(value))

                        // Same strict validation
                        if isValidZString(result.string) {
                            decodedString = result.string
                            addressInfo += " (direct string address)"
                        }
                    } else {
                        addressInfo += " (not a memory address)"
                    }
                } catch {
                    addressInfo += " (not a string address)"
                }
            }

            properties.append(ObjectPropertyInfo(
                objectNumber: objectNumber,
                propertyNumber: propNum,
                propertyName: propName,
                rawValue: value,
                decodedString: decodedString,
                addressInfo: addressInfo
            ))
        }

        return properties
    }

    /// Validate if a decoded string is a legitimate Z-Machine text string
    private func isValidZString(_ string: String) -> Bool {
        // Must have reasonable length
        guard string.count >= 1 && string.count <= 200 else { return false }

        // Must contain only valid Z-Machine text characters
        for char in string {
            let ascii = char.asciiValue ?? 0

            // Valid Z-Machine characters:
            // - Printable ASCII (32-126): space through tilde
            // - Newline (10): allowed in Z-Machine text
            // - Carriage return (13): allowed in Z-Machine text (often paired with newline)
            // - Tab (9): allowed in Z-Machine text
            if ascii == 9 || ascii == 10 || ascii == 13 || (ascii >= 32 && ascii <= 126) {
                continue
            } else {
                return false // Invalid character found
            }
        }

        // Must contain some actual letters (not just spaces and punctuation)
        let hasLetters = string.contains { $0.isLetter }
        guard hasLetters else { return false }

        // Should start with a reasonable character (letter, number, or quote)
        if let firstChar = string.first {
            let ascii = firstChar.asciiValue ?? 0
            if !(firstChar.isLetter || firstChar.isNumber || ascii == 34 || ascii == 39 || firstChar.isUppercase) { // " or '
                return false
            }
        }

        return true
    }
}

// MARK: - Unicode Translation Support (v5+)
extension ZMachine {

    /// Execute PRINT_UNICODE instruction - print a Unicode character directly
    ///
    /// - Parameter unicodeChar: Unicode code point to print
    /// - Throws: RuntimeError for invalid operations
    func executePrintUnicode(_ unicodeChar: UInt32) throws {
        // Convert Unicode code point to Character and output
        if let scalar = UnicodeScalar(unicodeChar) {
            let character = Character(scalar)
            outputText(String(character))
        } else {
            // Invalid Unicode code point - output replacement character
            outputText("�")
        }
    }

    /// Check if Unicode character can be displayed
    ///
    /// - Parameter unicodeChar: Unicode code point to check
    /// - Returns: True if character can be displayed, false otherwise
    func checkUnicodeSupport(_ unicodeChar: UInt32) -> Bool {
        // Check if it's a valid Unicode scalar
        guard UnicodeScalar(unicodeChar) != nil else {
            return false
        }

        // For now, assume all valid Unicode scalars are supported
        // Real implementations might check font availability, etc.
        return true
    }

    /// Translate ZSCII character to Unicode using translation table
    ///
    /// - Parameter zsciiChar: ZSCII character code (0-255)
    /// - Returns: Unicode code point for the character
    func zsciiToUnicode(_ zsciiChar: UInt8) -> UInt32 {
        let zscii = UInt32(zsciiChar)

        // Standard ZSCII characters (0-154) map directly to Unicode
        if zscii <= 154 {
            return zscii
        }

        // Extended ZSCII characters (155-223) use Unicode translation table
        if zscii >= 155 && zscii <= 223 {
            return unicodeTranslationTable[zscii] ?? zscii // Default to self if not in table
        }

        // Mouse click codes and other special ZSCII (224-255) have no Unicode equivalent
        return 63 // Question mark for unsupported characters
    }

    /// Translate Unicode character to ZSCII using reverse lookup
    ///
    /// - Parameter unicodeChar: Unicode code point
    /// - Returns: ZSCII character code, or nil if no mapping exists
    func unicodeToZSCII(_ unicodeChar: UInt32) -> UInt8? {
        // Direct mapping for characters 0-154
        if unicodeChar <= 154 {
            return UInt8(unicodeChar)
        }

        // Reverse lookup in Unicode translation table
        for (zscii, unicode) in unicodeTranslationTable {
            if unicode == unicodeChar {
                return UInt8(zscii)
            }
        }

        // No mapping found
        return nil
    }
}