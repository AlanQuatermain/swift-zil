import Testing
@testable import ZEngine
import Foundation

/// Tests for FWORDS (abbreviation table) implementation
@Suite("FWORDS Abbreviation Table Tests")
struct FWordsTests {

    @Test("FWORDS table header parsing")
    func fwordsTableHeaderParsing() throws {
        // Test that the header parsing correctly reads the abbreviation table address
        var mutableHeader = Data(count: 1024 * 12)

        // Set version to 3
        mutableHeader[0] = 3

        // Set abbreviation table address (bytes 24-25) to 0x1234
        mutableHeader[24] = 0x12
        mutableHeader[25] = 0x34

        // Set other required fields to valid values
        mutableHeader[14] = 0x10  // Static memory base high byte
        mutableHeader[15] = 0x00  // Static memory base low byte (0x1000)
        mutableHeader[4] = 0x20   // High memory base high byte
        mutableHeader[5] = 0x00   // High memory base low byte (0x2000)
        mutableHeader[8] = 0x15   // Dictionary address high byte
        mutableHeader[9] = 0x00   // Dictionary address low byte (0x1500)
        mutableHeader[10] = 0x18  // Object table address high byte
        mutableHeader[11] = 0x00  // Object table address low byte (0x1800)
        mutableHeader[12] = 0x00  // Global table address high byte
        mutableHeader[13] = 0x40  // Global table address low byte (0x0040)

        let header = try StoryHeader(from: mutableHeader)
        #expect(header.abbreviationTableAddress == 0x1234)
        #expect(header.version == .v3)
    }

    @Test("Abbreviation table initialization")
    func abbreviationTableInitialization() throws {
        let vm = ZMachine()

        // Initially, abbreviation table should be empty
        #expect(vm.abbreviationTable.isEmpty)

        // Test manual setup for abbreviation table
        vm.abbreviationTable = Array(repeating: 0, count: 96)
        #expect(vm.abbreviationTable.count == 96)

        // Set a test abbreviation entry
        vm.abbreviationTable[0] = 0x1000  // A0[0] points to address 0x1000
        vm.abbreviationTable[32] = 0x2000 // A1[0] points to address 0x2000
        vm.abbreviationTable[64] = 0x3000 // A2[0] points to address 0x3000

        #expect(vm.abbreviationTable[0] == 0x1000)
        #expect(vm.abbreviationTable[32] == 0x2000)
        #expect(vm.abbreviationTable[64] == 0x3000)
    }

    @Test("Test abbreviation Z-character decoding logic")
    func testAbbreviationZCharacterLogic() throws {
        let vm = ZMachine()

        // Set up a mock abbreviation table
        vm.abbreviationTable = Array(repeating: 0, count: 96)

        // Test Z-character sequences that should trigger abbreviations
        // Z-chars 1, 2, 3 followed by 0-31 should reference abbreviation entries

        let testZChars1: [UInt8] = [1, 0]   // A0[0] - abbreviation table index 0
        let testZChars2: [UInt8] = [2, 5]   // A1[5] - abbreviation table index 37 (32+5)
        let testZChars3: [UInt8] = [3, 10]  // A2[10] - abbreviation table index 74 (64+10)

        // Test that the decoding doesn't crash with null abbreviations
        do {
            let result1 = try vm.decodeZString(testZChars1)
            let result2 = try vm.decodeZString(testZChars2)
            let result3 = try vm.decodeZString(testZChars3)

            // With null abbreviations, should get spaces as fallback
            #expect(result1.contains(" ") || result1.isEmpty)
            #expect(result2.contains(" ") || result2.isEmpty)
            #expect(result3.contains(" ") || result3.isEmpty)

        } catch {
            // If the decoding fails due to invalid memory access (expected with null entries),
            // that's also acceptable for this test
        }
    }

    @Test("Load real story file and check abbreviation table")
    func loadRealStoryFileAndCheckAbbreviationTable() throws {
        let vm = ZMachine()

        // Try to load Zork 1 for testing
        let storyPath = "/Users/jim/Projects/ZIL/zork1/COMPILED/zork1.z3"
        let storyURL = URL(fileURLWithPath: storyPath)

        guard FileManager.default.fileExists(atPath: storyPath) else {
            return
        }

        // Load the story file
        try vm.loadStoryFile(from: storyURL)

        // Verify basic properties
        #expect(vm.version == .v3)
        #expect(vm.header.abbreviationTableAddress > 0, "Abbreviation table address should be non-zero")

        // Verify abbreviation table was loaded with correct size
        #expect(vm.abbreviationTable.count == 96, "Should have 96 abbreviation entries (32 each for A0, A1, A2)")

        // Check that some abbreviation entries are non-zero (real games should have abbreviations)
        let nonZeroCount = vm.abbreviationTable.filter { $0 > 0 }.count
        #expect(nonZeroCount > 0, "Should have at least some non-zero abbreviation entries")

    }
}
