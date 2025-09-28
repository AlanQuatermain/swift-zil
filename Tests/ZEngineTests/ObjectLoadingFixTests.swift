import Testing
import Foundation
@testable import ZEngine

/// Test to verify that the bit manipulation fix resolves the object 171 loading issue
@Suite("Object Loading Fix Verification")
struct ObjectLoadingFixTests {

    /// Test that we can load a real Z-Machine story file without bit manipulation errors
    @Test("Load Zork 1 story file without bit manipulation errors")
    func testZork1Loading() throws {
        // Try to load the Zork 1 story file
        let zorkPath = "../zork1/COMPILED/ZORK1.Z3"
        let zorkURL = URL(fileURLWithPath: zorkPath)

        guard FileManager.default.fileExists(atPath: zorkPath) else {
            // Skip test if file doesn't exist
            print("Skipping test: Zork 1 story file not found at \(zorkPath)")
            return
        }

        // Create Z-Machine and load the story file
        let vm = ZMachine()

        // This should not throw the "Not enough bits to represent the passed value" error anymore
        try vm.loadStoryFile(from: zorkURL)

        // Verify basic properties
        #expect(vm.version == .v3, "Zork 1 should be Z-Machine version 3")

        // Verify memory validation passes (this involves object tree operations)
        let memoryValid = vm.validateMemoryManagement()
        #expect(memoryValid, "Memory management should be valid after loading")

        print("✓ Successfully loaded Zork 1 without bit manipulation errors")
    }
}