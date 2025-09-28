import Testing
@testable import ZEngine
import Foundation

/// Comprehensive tests for Z-Machine Extended instructions (v5+)
@Suite("Z-Machine Extended Instructions Tests")
struct ZMachineExtendedInstructionsTests {

    // MARK: - Test Helpers

    /// Creates a minimal test story file with Extended instruction for testing
    private func createTestStoryFile(
        version: ZMachineVersion = .v5,
        extendedOpcode: UInt8 = 0x00,
        operands: [Int16] = [],
        expectStore: Bool = false,
        expectBranch: Bool = false
    ) throws -> (URL, Data) {
        let tempDir = FileManager.default.temporaryDirectory
        let storyFile = tempDir.appendingPathComponent("test_extended_\(extendedOpcode)_\(UUID().uuidString).z\(version.rawValue)")

        // Create minimal Z-Machine story file
        var storyData = Data(count: 1024)

        // Set up minimal valid header
        storyData[0] = UInt8(version.rawValue)  // Version
        storyData[1] = 0x00  // Flags 1
        storyData[2] = 0x00  // Release (high byte)
        storyData[3] = 0x01  // Release (low byte) - release 1
        storyData[4] = 0x02  // High memory base (high byte)
        storyData[5] = 0x00  // High memory base (low byte) - 512 bytes

        // Initial PC - needs to be packed address. For v5, 512 actual / 4 = 128 packed
        let packedPC: UInt16
        switch version {
        case .v3:
            packedPC = 512 / 2  // v3 uses factor of 2
        case .v4, .v5:
            packedPC = 512 / 4  // v4/v5 use factor of 4
        case .v6, .v7:
            packedPC = 512 / 4  // v6/v7 use factor of 4
        case .v8:
            packedPC = 512 / 8  // v8 uses factor of 8
        }
        storyData[6] = UInt8((packedPC >> 8) & 0xFF)  // Initial PC (high byte)
        storyData[7] = UInt8(packedPC & 0xFF)         // Initial PC (low byte)

        storyData[8] = 0x01  // Dictionary location (high byte)
        storyData[9] = 0x80  // Dictionary location (low byte) - 384
        storyData[10] = 0x01 // Object table location (high byte)
        storyData[11] = 0x00 // Object table location (low byte) - 256
        storyData[12] = 0x00 // Global variables (high byte)
        storyData[13] = 0x40 // Global variables (low byte) - 64
        storyData[14] = 0x00 // Static memory base (high byte)
        storyData[15] = 0xF0 // Static memory base (low byte) - 240

        // Zero out global variables area (64-240)
        for i in 64..<240 {
            storyData[i] = 0x00
        }

        // Create minimal object table at offset 256
        // Object table starts with property defaults (31 words for v1-3, 63 for v4+)
        let defaultCount = version.rawValue <= 3 ? 31 : 63
        for i in 0..<defaultCount {
            let offset = 256 + i * 2
            storyData[offset] = 0x00
            storyData[offset + 1] = 0x00
        }

        // Create minimal dictionary at offset 384
        storyData[384] = 0x00  // Input separator count
        storyData[385] = 0x04  // Word length (4 bytes)
        storyData[386] = 0x00  // Dictionary entry count (high byte)
        storyData[387] = 0x00  // Dictionary entry count (low byte) - 0 entries

        // Write Extended instruction at PC (offset 512)
        var offset = 512
        storyData[offset] = 0xBE     // EXTENDED prefix
        storyData[offset + 1] = extendedOpcode
        offset += 2

        // Operand type byte
        var operandTypeByte: UInt8 = 0xFF  // Mark all as omitted
        if !operands.isEmpty {
            operandTypeByte = 0x00  // Large constant for all operands
            if operands.count > 1 {
                operandTypeByte |= 0x00 << 2
            }
            if operands.count > 2 {
                operandTypeByte |= 0x00 << 4
            }
            if operands.count > 3 {
                operandTypeByte |= 0x00 << 6
            }
        }

        storyData[offset] = operandTypeByte
        offset += 1

        // Write operand values (as 16-bit words)
        for operand in operands {
            let word = UInt16(bitPattern: operand)
            storyData[offset] = UInt8((word >> 8) & 0xFF)
            storyData[offset + 1] = UInt8(word & 0xFF)
            offset += 2
        }

        // Add store variable if needed
        if expectStore {
            storyData[offset] = 0x00  // Store in G00
            offset += 1
        }

        // Add branch info if needed
        if expectBranch {
            storyData[offset] = 0x40  // Branch on true, offset 0 (RTRUE)
            offset += 1
        }

        // Write QUIT instruction to end
        storyData[offset] = 0xBA  // QUIT

        try storyData.write(to: storyFile)
        return (storyFile, storyData)
    }

    /// Helper to execute a single Extended instruction and return VM state
    private func executeExtendedInstruction(
        _ opcode: UInt8,
        operands: [Int16] = [],
        version: ZMachineVersion = .v5,
        expectStore: Bool = false,
        expectBranch: Bool = false
    ) throws -> ZMachine {
        let (storyFile, _) = try createTestStoryFile(
            version: version,
            extendedOpcode: opcode,
            operands: operands,
            expectStore: expectStore,
            expectBranch: expectBranch
        )

        defer {
            try? FileManager.default.removeItem(at: storyFile)
        }

        let machine = ZMachine()
        try machine.loadStoryFile(from: storyFile)

        // Execute the Extended instruction
        try machine.executeInstruction()

        return machine
    }

    // MARK: - Basic Extended Instructions Tests (EXT:0-3)

    @Test("EXT:0 SAVE instruction")
    func saveInstruction() throws {
        let machine = try executeExtendedInstruction(0x00, expectStore: true)

        // Should store success value (1) in G00
        let result = try machine.readVariable(0x00)
        #expect(result == 1)
    }

    @Test("EXT:1 RESTORE instruction")
    func restoreInstruction() throws {
        let machine = try executeExtendedInstruction(0x01, expectStore: true)

        // Should store failure value (0) in G00
        let result = try machine.readVariable(0x00)
        #expect(result == 0)
    }

    @Test("EXT:2 LOG_SHIFT instruction")
    func logicalShiftInstruction() throws {
        // Test left shift
        let leftShift = try executeExtendedInstruction(0x02, operands: [8, 2], expectStore: true)
        let leftResult = try leftShift.readVariable(0x00)
        #expect(leftResult == 32)  // 8 << 2 = 32

        // Test right shift
        let rightShift = try executeExtendedInstruction(0x02, operands: [32, -2], expectStore: true)
        let rightResult = try rightShift.readVariable(0x00)
        #expect(rightResult == 8)  // 32 >> 2 = 8

        // Test zero shift
        let zeroShift = try executeExtendedInstruction(0x02, operands: [42, 0], expectStore: true)
        let zeroResult = try zeroShift.readVariable(0x00)
        #expect(zeroResult == 42)  // 42 << 0 = 42
    }

    @Test("EXT:3 ART_SHIFT instruction")
    func arithmeticShiftInstruction() throws {
        // Test left shift (same as logical)
        let leftShift = try executeExtendedInstruction(0x03, operands: [8, 2], expectStore: true)
        let leftResult = try leftShift.readVariable(0x00)
        #expect(leftResult == 32)  // 8 << 2 = 32

        // Test right shift with positive number
        let rightShift = try executeExtendedInstruction(0x03, operands: [32, -2], expectStore: true)
        let rightResult = try rightShift.readVariable(0x00)
        #expect(rightResult == 8)  // 32 >> 2 = 8

        // Test right shift with negative number (sign preservation)
        let negativeShift = try executeExtendedInstruction(0x03, operands: [-32, -2], expectStore: true)
        let negativeResult = try negativeShift.readVariable(0x00)
        #expect(negativeResult == -8)  // -32 >> 2 = -8 (sign preserved)
    }

    // MARK: - Font and Display Instructions (EXT:4)

    @Test("EXT:4 SET_FONT instruction")
    func setFontInstruction() throws {
        let machine = try executeExtendedInstruction(0x04, operands: [1], expectStore: true)

        // Should return previous font (0 = default)
        let result = try machine.readVariable(0x00)
        #expect(result == 0)
    }

    // MARK: - Unicode Instructions (EXT:B-C)

    @Test("EXT:B PRINT_UNICODE instruction")
    func printUnicodeInstruction() throws {
        // Test valid Unicode character (A) - should not crash
        _ = try executeExtendedInstruction(0x0B, operands: [65])  // 'A'

        // Test invalid Unicode character - should not crash (use -1 as invalid)
        _ = try executeExtendedInstruction(0x0B, operands: [-1])  // Invalid Unicode
    }

    @Test("EXT:C CHECK_UNICODE instruction")
    func checkUnicodeInstruction() throws {
        // Test valid Unicode character
        let validMachine = try executeExtendedInstruction(0x0C, operands: [65], expectStore: true)  // 'A'
        let validResult = try validMachine.readVariable(0x00)
        #expect(validResult == 1)  // Can display

        // Test invalid Unicode character (use -1 as invalid)
        let invalidMachine = try executeExtendedInstruction(0x0C, operands: [-1], expectStore: true)  // Invalid
        let invalidResult = try invalidMachine.readVariable(0x00)
        #expect(invalidResult == 0)  // Cannot display
    }

    // MARK: - Save/Undo Instructions (EXT:9-A)

    @Test("EXT:9 SAVE_UNDO instruction")
    func saveUndoInstruction() throws {
        let machine = try executeExtendedInstruction(0x09, expectStore: true)

        // Should return success (1)
        let result = try machine.readVariable(0x00)
        #expect(result == 1)
    }

    @Test("EXT:A RESTORE_UNDO instruction")
    func restoreUndoInstruction() throws {
        let machine = try executeExtendedInstruction(0x0A, expectStore: true)

        // Should return failure (0)
        let result = try machine.readVariable(0x00)
        #expect(result == 0)
    }

    // MARK: - Graphics Instructions (V6 Only) - Basic Validation

    @Test("Graphics instructions work in V6")
    func graphicsInstructionsV6() throws {
        // EXT:5 DRAW_PICTURE - should work in v6 without crashing
        _ = try executeExtendedInstruction(0x05, operands: [1, 100, 200], version: .v6)

        // EXT:6 PICTURE_DATA - should work in v6
        _ = try executeExtendedInstruction(0x06, operands: [1], version: .v6, expectBranch: true)

        // EXT:7 ERASE_PICTURE - should work in v6
        _ = try executeExtendedInstruction(0x07, operands: [1], version: .v6)
    }

    @Test("Graphics instructions fail in V5")
    func graphicsInstructionsV5Fail() throws {
        // All graphics instructions should fail in v5
        #expect(throws: (any Error).self) {
            _ = try executeExtendedInstruction(0x05, operands: [1, 100, 200], version: .v5)
        }

        #expect(throws: (any Error).self) {
            _ = try executeExtendedInstruction(0x06, operands: [1], version: .v5, expectBranch: true)
        }

        #expect(throws: (any Error).self) {
            _ = try executeExtendedInstruction(0x07, operands: [1], version: .v5)
        }
    }

    // MARK: - Error Handling Tests

    @Test("Extended instruction with insufficient operands")
    func insufficientOperands() throws {
        #expect(throws: (any Error).self) {
            // LOG_SHIFT requires 2 operands, provide only 1
            _ = try executeExtendedInstruction(0x02, operands: [8])
        }

        #expect(throws: (any Error).self) {
            // ART_SHIFT requires 2 operands, provide none
            _ = try executeExtendedInstruction(0x03, operands: [])
        }
    }

    @Test("Unsupported extended opcode")
    func unsupportedExtendedOpcode() throws {
        #expect(throws: (any Error).self) {
            // Use an unimplemented Extended opcode
            _ = try executeExtendedInstruction(0xFF)
        }
    }
}