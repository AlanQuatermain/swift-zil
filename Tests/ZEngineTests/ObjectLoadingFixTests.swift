import Testing
import Foundation
@testable import ZEngine

/// Test suite to verify the object loading fix for property table address underflow
///
/// This test verifies the fix for the bug where ObjectEntry initialization would crash
/// with "Not enough bits to represent the passed value" when the property table address
/// was less than the static memory base address, causing UInt16 underflow.
@Suite("Object Loading Integer Underflow Fix")
struct ObjectLoadingFixTests {

    @Test("Property table address less than static memory base")
    func testPropertyTableAddressUnderflow() throws {
        // Create test data that reproduces the Object 171 crash scenario
        // Object 171 had propertyTableAddress=7261, staticMemoryBase=11282
        // This would cause underflow: 7261 - 11282 = -4021 (can't fit in UInt16)

        // Create minimal static memory data
        var staticMemoryData = Data(count: 200)

        // Fill property defaults (31 words = 62 bytes) with zeros
        for i in 0..<62 {
            staticMemoryData[i] = 0
        }

        // Create a v3 object at offset 62 that reproduces the underflow scenario
        let objectOffset = 62

        // 4 bytes attributes (set attribute 25 like object 171)
        staticMemoryData[objectOffset + 0] = 0x02  // 0x02000000 = bit 25 set
        staticMemoryData[objectOffset + 1] = 0x00
        staticMemoryData[objectOffset + 2] = 0x00
        staticMemoryData[objectOffset + 3] = 0x00

        // 1 byte parent (39 like object 171)
        staticMemoryData[objectOffset + 4] = 39

        // 1 byte sibling (188 like object 171)
        staticMemoryData[objectOffset + 5] = 188

        // 1 byte child (0 like object 171)
        staticMemoryData[objectOffset + 6] = 0

        // 2 bytes property table address (7261 like object 171)
        // This is less than staticMemoryBase (11282), which previously caused underflow
        let propertyTableAddr: UInt16 = 7261
        staticMemoryData[objectOffset + 7] = UInt8(propertyTableAddr >> 8)   // High byte
        staticMemoryData[objectOffset + 8] = UInt8(propertyTableAddr & 0xFF) // Low byte

        // Set up ObjectTree with the problematic staticMemoryBase
        let objectTree = ObjectTree()
        let staticMemoryBase: UInt32 = 11282  // This is larger than propertyTableAddr

        // This should NOT crash with "Not enough bits to represent the passed value"
        #expect(throws: Never.self) {
            try objectTree.load(from: staticMemoryData,
                              version: .v3,
                              objectTableAddress: 0,
                              staticMemoryBase: staticMemoryBase,
                              dictionaryAddress: 200)
        }

        // Verify the object loaded correctly
        let object = objectTree.getObject(1)
        #expect(object != nil, "Object should load successfully")
        #expect(object?.parent == 39, "Parent should be 39")
        #expect(object?.sibling == 188, "Sibling should be 188")
        #expect(object?.child == 0, "Child should be 0")
        #expect(object?.propertyTableAddress == 7261, "Property table address should be stored as absolute address")

        // Verify the attribute is set correctly (bit 25)
        #expect(object?.hasAttribute(25) == true, "Attribute 25 should be set")
        #expect(object?.hasAttribute(24) == false, "Attribute 24 should not be set")
        #expect(object?.hasAttribute(26) == false, "Attribute 26 should not be set")
    }

    @Test("Property table address greater than static memory base (normal case)")
    func testPropertyTableAddressNormalCase() throws {
        // Test the normal case where property table address >= static memory base
        var staticMemoryData = Data(count: 200)

        // Fill property defaults with zeros
        for i in 0..<62 {
            staticMemoryData[i] = 0
        }

        let objectOffset = 62

        // 4 bytes attributes (all zero)
        for i in 0..<4 {
            staticMemoryData[objectOffset + i] = 0
        }

        // Relationships
        staticMemoryData[objectOffset + 4] = 10  // parent
        staticMemoryData[objectOffset + 5] = 20  // sibling
        staticMemoryData[objectOffset + 6] = 30  // child

        // Property table address LARGER than static memory base
        let staticMemoryBase: UInt32 = 1000
        let propertyTableAddr: UInt16 = 1500  // > staticMemoryBase
        staticMemoryData[objectOffset + 7] = UInt8(propertyTableAddr >> 8)
        staticMemoryData[objectOffset + 8] = UInt8(propertyTableAddr & 0xFF)

        let objectTree = ObjectTree()
        try objectTree.load(from: staticMemoryData,
                          version: .v3,
                          objectTableAddress: 0,
                          staticMemoryBase: staticMemoryBase,
                          dictionaryAddress: 200)

        let object = objectTree.getObject(1)
        #expect(object != nil, "Object should load successfully")
        #expect(object?.parent == 10, "Parent should be 10")
        #expect(object?.sibling == 20, "Sibling should be 20")
        #expect(object?.child == 30, "Child should be 30")

        // In this case, property address should be relative offset
        let expectedOffset = propertyTableAddr - UInt16(staticMemoryBase)  // 1500 - 1000 = 500
        #expect(object?.propertyTableAddress == expectedOffset, "Property table address should be relative offset")
    }

    @Test("Edge case: property table address equals static memory base")
    func testPropertyTableAddressEqualsBase() throws {
        var staticMemoryData = Data(count: 200)

        // Fill property defaults with zeros
        for i in 0..<62 {
            staticMemoryData[i] = 0
        }

        let objectOffset = 62

        // 4 bytes attributes (all zero)
        for i in 0..<4 {
            staticMemoryData[objectOffset + i] = 0
        }

        // Relationships
        staticMemoryData[objectOffset + 4] = 5   // parent
        staticMemoryData[objectOffset + 5] = 0   // sibling
        staticMemoryData[objectOffset + 6] = 0   // child

        // Property table address EQUAL to static memory base
        let staticMemoryBase: UInt32 = 2000
        let propertyTableAddr: UInt16 = 2000  // == staticMemoryBase
        staticMemoryData[objectOffset + 7] = UInt8(propertyTableAddr >> 8)
        staticMemoryData[objectOffset + 8] = UInt8(propertyTableAddr & 0xFF)

        let objectTree = ObjectTree()
        try objectTree.load(from: staticMemoryData,
                          version: .v3,
                          objectTableAddress: 0,
                          staticMemoryBase: staticMemoryBase,
                          dictionaryAddress: 200)

        let object = objectTree.getObject(1)
        #expect(object != nil, "Object should load successfully")
        #expect(object?.propertyTableAddress == 0, "Property table address should be 0 when equal to base")
    }

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