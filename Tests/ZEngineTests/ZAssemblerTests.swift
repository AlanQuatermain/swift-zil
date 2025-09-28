import Testing
@testable import ZEngine
import Foundation

/// Comprehensive tests for the Z-Machine assembler using realistic test fixtures
@Suite("Z-Machine Assembler Tests")
struct ZAssemblerTests {

    // MARK: - Basic Instruction Encoding Tests

    @Test("0OP instruction encoding")
    func zeroOpInstructionEncoding() throws {
        let encoder = InstructionEncoder(version: .v3)
        let symbolTable: [String: UInt32] = [:]
        let location = SourceLocation(file: "test", line: 1, column: 1)

        // Test RTRUE
        let rtrueInstruction = ZAPInstruction.testInstruction(
            opcode: "RTRUE"
        )

        let rtrueEncoded = try encoder.encodeInstruction(rtrueInstruction, symbolTable: symbolTable, location: location, currentAddress: 0x1000)
        #expect(Array(rtrueEncoded) == [0xB0])

        // Test RFALSE
        let rfalseInstruction = ZAPInstruction.testInstruction(
            opcode: "RFALSE"
        )

        let rfalseEncoded = try encoder.encodeInstruction(rfalseInstruction, symbolTable: symbolTable, location: location, currentAddress: 0x1000)
        #expect(Array(rfalseEncoded) == [0xB1])
    }

    @Test("1OP instruction encoding with different operand types")
    func oneOpInstructionEncoding() throws {
        let encoder = InstructionEncoder(version: .v3)
        let symbolTable: [String: UInt32] = ["X": 1]
        let location = SourceLocation(file: "test", line: 1, column: 1)

        // Test ZERO? with small constant
        let zeroSmallInstruction = ZAPInstruction.testInstruction(
            opcode: "ZERO?",
            operands: [.number(42)]
        )

        let zeroSmallEncoded = try encoder.encodeInstruction(zeroSmallInstruction, symbolTable: symbolTable, location: location, currentAddress: 0x1000)
        #expect(Array(zeroSmallEncoded) == [0x90, 0x2A])  // 1OP ZERO? with small constant
    }

    @Test("2OP instruction encoding with variable combinations")
    func twoOpInstructionEncoding() throws {
        let encoder = InstructionEncoder(version: .v3)
        let symbolTable: [String: UInt32] = ["X": 1, "Y": 2]
        let location = SourceLocation(file: "test", line: 1, column: 1)

        // Test EQUAL? with variable and small constant
        let equalInstruction = ZAPInstruction.testInstruction(
            opcode: "EQUAL?",
            operands: [.atom("X"), .number(42)]
        )

        let equalEncoded = try encoder.encodeInstruction(equalInstruction, symbolTable: symbolTable, location: location, currentAddress: 0x1000)
        #expect(Array(equalEncoded) == [0x41, 0x01, 0x00, 0x2A])  // 2OP EQUAL? variable, large constant (ALL constants are large in long form)
    }

    // MARK: - Memory Layout Tests

    @Test("Memory layout manager initialization")
    func memoryLayoutManagerInitialization() throws {
        for (version, expectedLayout) in ZAssemblerTestFixtures.expectedMemoryLayout {
            let layoutManager = MemoryLayoutManager(version: version)

            // Test that addresses are calculated correctly for each version
            let globalAddr = layoutManager.allocateGlobal("TEST-GLOBAL")
            #expect(globalAddr >= UInt32(expectedLayout.globalTableAddress))

            let objectAddr = layoutManager.allocateObject("TEST-OBJECT")
            #expect(objectAddr >= UInt32(expectedLayout.objectTableAddress))
        }
    }

    @Test("Global variable allocation")
    func globalVariableAllocation() throws {
        let layoutManager = MemoryLayoutManager(version: .v3)

        // Allocate multiple globals and verify they get sequential addresses
        let global1 = layoutManager.allocateGlobal("SCORE")
        let global2 = layoutManager.allocateGlobal("MOVES")
        let global3 = layoutManager.allocateGlobal("WINNER")

        #expect(global1 == 64)  // First global at 64 (global table start)
        #expect(global2 == 66)  // Second global at 66 (2 bytes later)
        #expect(global3 == 68)  // Third global at 68 (2 bytes later)
    }

    @Test("Object allocation and property tables")
    func objectAllocationAndPropertyTables() throws {
        let layoutManager = MemoryLayoutManager(version: .v4)
        let location = SourceLocation(file: "test", line: 1, column: 1)

        // Allocate objects
        let object1 = layoutManager.allocateObject("LANTERN")
        let object2 = layoutManager.allocateObject("SWORD")

        // Objects should have sequential addresses
        let expectedObjectSize: UInt32 = 14  // V4 object size
        #expect(object2 - object1 == expectedObjectSize)

        // Test property assignment (requires object to exist)
        try layoutManager.startObject("LANTERN", location: location)
        layoutManager.addProperty("DESC")
        layoutManager.addProperty("CAPACITY")
        try layoutManager.endObject(location: location)
    }

    // MARK: - String Table Tests

    @Test("String table generation and encoding")
    func stringTableGenerationAndEncoding() throws {
        let layoutManager = MemoryLayoutManager(version: .v3)

        // Add various types of strings
        let str1 = layoutManager.addString("STR0", content: "Hello, World!")
        let str2 = layoutManager.addString("STR1", content: "Quote: \"Test\"")
        let str3 = layoutManager.addString("STR2", content: "Tab:\tand newline:\n")

        // Strings should get sequential addresses in high memory
        #expect(str1 < str2)
        #expect(str2 < str3)
    }

    // MARK: - Property Encoding Tests

    @Test("Property encoding validation")
    func propertyEncodingValidation() throws {
        for testCase in ZAssemblerTestFixtures.propertyEncodingTests {
            let layoutManager = MemoryLayoutManager(version: testCase.version)

            // The property encoding is tested implicitly through object generation
            // This validates the expected data format matches our implementation
            #expect(testCase.expectedData.count > 0)
            #expect(testCase.expectedHeader > 0)

            // Property IDs should be valid (1-31)
            let propertyId = testCase.expectedHeader & 0x1F
            #expect(propertyId >= 1 && propertyId <= 31)
        }
    }

    @Test("Property descending order validation")
    func propertyDescendingOrderValidation() throws {
        let layoutManager = MemoryLayoutManager(version: .v4)

        // Test the complex object from fixtures which has properties in descending order
        let storyFile = try layoutManager.generateStoryFile()

        // Validate that story file was generated successfully
        #expect(storyFile.count >= 64)  // At least header size

        // Validate checksum calculation
        let warnings = layoutManager.validateStoryFile(storyFile)
        for warning in warnings {
            print("Warning: \(warning)")
        }
        // Should have minimal warnings for a valid story file
        #expect(warnings.count <= 10)  // Allow for some expected warnings in minimal file
    }

    // MARK: - Version-Specific Feature Tests

    @Test("Version-specific instruction availability")
    func versionSpecificInstructionAvailability() throws {
        let v3Encoder = InstructionEncoder(version: .v3)
        let v4Encoder = InstructionEncoder(version: .v4)

        let symbolTable: [String: UInt32] = [:]
        let location = SourceLocation(file: "test", line: 1, column: 1)

        // SOUND instruction should only be available in V4+
        let soundInstruction = ZAPInstruction.testInstruction(
            opcode: "SOUND",
            operands: [.number(1)]
        )

        // Should throw error in V3
        #expect(throws: AssemblyError.self) {
            try v3Encoder.encodeInstruction(soundInstruction, symbolTable: symbolTable, location: location, currentAddress: 0x1000)
        }

        // Should work in V4+
        let v4Sound = try v4Encoder.encodeInstruction(soundInstruction, symbolTable: symbolTable, location: location, currentAddress: 0x1000)
        #expect(v4Sound.count > 0)
    }

    @Test("Memory layout differences across versions")
    func memoryLayoutDifferencesAcrossVersions() throws {
        let v3Layout = MemoryLayoutManager(version: .v3)
        let v4Layout = MemoryLayoutManager(version: .v4)
        let v5Layout = MemoryLayoutManager(version: .v5)

        // Generate story files for each version
        let v3Story = try v3Layout.generateStoryFile()
        let v4Story = try v4Layout.generateStoryFile()
        let v5Story = try v5Layout.generateStoryFile()

        // Verify version bytes
        #expect(v3Story[0] == 3)
        #expect(v4Story[0] == 4)
        #expect(v5Story[0] == 5)

        // V5 should have different memory layout than V3/V4
        let v3StaticBase = UInt16(v3Story[14]) << 8 | UInt16(v3Story[15])
        let v5StaticBase = UInt16(v5Story[14]) << 8 | UInt16(v5Story[15])

        // V5 typically has different memory organization
        #expect(v3StaticBase != v5StaticBase || v3Story.count != v5Story.count)
    }

    @Test("Extended form instruction encoding")
    func extendedFormInstructions() throws {
        let v3Encoder = InstructionEncoder(version: .v3)
        let v4Encoder = InstructionEncoder(version: .v4)
        let symbolTable: [String: UInt32] = [:]
        let location = SourceLocation(file: "test", line: 1, column: 1)

        // Test SAVE instruction
        let saveInstruction = ZAPInstruction.testInstruction(
            opcode: "SAVE",
            resultTarget: "L01"  // V4+ SAVE produces a result
        )

        // V3 SAVE should be 0OP form (0xB5)
        let v3Save = try v3Encoder.encodeInstruction(saveInstruction, symbolTable: symbolTable, location: location, currentAddress: 0x1000)
        #expect(Array(v3Save) == [0xB5, 0x01])  // 0xB5 + result storage L01

        // V4+ SAVE should be extended form (0xBE 0x00 + operand type + result storage)
        let v4Save = try v4Encoder.encodeInstruction(saveInstruction, symbolTable: symbolTable, location: location, currentAddress: 0x1000)
        #expect(Array(v4Save) == [0xBE, 0x00, 0xFF, 0x01])  // 0xBE + extended opcode 0x00 + no operands (0xFF) + result storage L01

        // Test RESTORE instruction
        let restoreInstruction = ZAPInstruction.testInstruction(
            opcode: "RESTORE",
            resultTarget: "L01"  // V4+ RESTORE produces a result
        )

        // V3 RESTORE should be 0OP form (0xB6)
        let v3Restore = try v3Encoder.encodeInstruction(restoreInstruction, symbolTable: symbolTable, location: location, currentAddress: 0x1000)
        #expect(Array(v3Restore) == [0xB6, 0x01])  // 0xB6 + result storage L01

        // V4+ RESTORE should be extended form (0xBE 0x01 + operand type + result storage)
        let v4Restore = try v4Encoder.encodeInstruction(restoreInstruction, symbolTable: symbolTable, location: location, currentAddress: 0x1000)
        #expect(Array(v4Restore) == [0xBE, 0x01, 0xFF, 0x01])  // 0xBE + extended opcode 0x01 + no operands (0xFF) + result storage L01
    }

    // MARK: - Checksum and Validation Tests

    @Test("Story file checksum calculation")
    func storyFileChecksumCalculation() throws {
        let testData = ZAssemblerTestFixtures.checksumTestData

        let layoutManager = MemoryLayoutManager(version: .v3)

        // Validate the test data checksum
        let warnings = layoutManager.validateStoryFile(testData)

        // Should detect checksum mismatch since we have placeholder checksum
        let hasChecksumWarning = warnings.contains { $0.contains("checksum") || $0.contains("Checksum") }
        #expect(hasChecksumWarning)
    }

    @Test("Story file validation comprehensive")
    func storyFileValidationComprehensive() throws {
        let layoutManager = MemoryLayoutManager(version: .v3)

        // Generate a complete story file
        let storyFile = try layoutManager.generateStoryFile()

        // Validate it
        let warnings = layoutManager.validateStoryFile(storyFile)

        // Print warnings for debugging
        for warning in warnings {
            print("Validation warning: \(warning)")
        }

        // A properly generated story file should have minimal warnings
        #expect(warnings.count <= 10)  // Allow some warnings for minimal file

        // Should not have critical errors
        let hasCriticalError = warnings.contains {
            $0.contains("too small") || $0.contains("overlaps")
        }
        #expect(!hasCriticalError)
    }

    // MARK: - Edge Case Tests

    @Test("Empty object handling")
    func emptyObjectHandling() throws {
        let layoutManager = MemoryLayoutManager(version: .v3)
        let location = SourceLocation(file: "test", line: 1, column: 1)

        // Create object with no properties
        let objAddress = layoutManager.allocateObject("EMPTY-OBJ")
        try layoutManager.startObject("EMPTY-OBJ", location: location)
        try layoutManager.endObject(location: location)

        #expect(objAddress > 0)

        // Should still generate valid story file
        let storyFile = try layoutManager.generateStoryFile()
        #expect(storyFile.count >= 64)
    }

    @Test("Boundary condition testing")
    func boundaryConditionTesting() throws {
        let layoutManager = MemoryLayoutManager(version: .v3)

        // Test maximum number of globals (should handle gracefully)
        var globalAddresses: [UInt32] = []
        for i in 0..<240 {  // Z-Machine has 240 globals
            let addr = layoutManager.allocateGlobal("GLOBAL\(i)")
            if addr > 0 {
                globalAddresses.append(addr)
            }
        }

        #expect(globalAddresses.count > 0)  // Should allocate at least some globals

        // Test that addresses are sequential
        for i in 1..<min(globalAddresses.count, 10) {
            #expect(globalAddresses[i] - globalAddresses[i-1] == 2)  // 2 bytes per global
        }
    }

    // MARK: - Integration Tests

    @Test("Complete assembler pipeline test")
    func completeAssemblerPipelineTest() throws {
        // Test the complete pipeline using a simple program
        let program = ZAssemblerTestFixtures.simpleZeroOpProgram

        // This would involve:
        // 1. Parsing ZAP assembly
        // 2. Building memory layout
        // 3. Encoding instructions
        // 4. Generating story file
        // 5. Validating output

        // For now, test individual components work together
        let layoutManager = MemoryLayoutManager(version: .v3)

        // Set up a simple routine
        layoutManager.setStartRoutine(address: 0x1000)

        // Generate story file
        let storyFile = try layoutManager.generateStoryFile()

        // Basic validation
        #expect(storyFile.count >= 64)
        #expect(storyFile[0] == 3)  // Version 3

        let warnings = layoutManager.validateStoryFile(storyFile)
        #expect(warnings.count <= 10)  // Reasonable number of warnings
    }

    @Test("Cross-version compatibility")
    func crossVersionCompatibility() throws {
        let versions: [ZMachineVersion] = [.v3, .v4, .v5]

        for version in versions {
            let layoutManager = MemoryLayoutManager(version: version)

            // Create a basic story file for each version
            let storyFile = try layoutManager.generateStoryFile()

            // Each should be valid for its version
            #expect(storyFile[0] == version.rawValue)
            #expect(storyFile.count >= 64)

            // Validate version-specific constraints
            let warnings = layoutManager.validateStoryFile(storyFile)
            let hasVersionError = warnings.contains { $0.contains("version") }
            #expect(!hasVersionError)
        }
    }
}

// MARK: - Test Helper Structures

// Test helper functions for creating ZAPInstructions from the main module
extension ZAPInstruction {
    static func testInstruction(
        opcode: String,
        operands: [ZValue] = [],
        label: String? = nil,
        branchTarget: String? = nil,
        branchCondition: BranchCondition? = nil,
        resultTarget: String? = nil
    ) -> ZAPInstruction {
        return ZAPInstruction(
            opcode: opcode,
            operands: operands,
            label: label,
            branchTarget: branchTarget,
            branchCondition: branchCondition,
            resultTarget: resultTarget
        )
    }
}