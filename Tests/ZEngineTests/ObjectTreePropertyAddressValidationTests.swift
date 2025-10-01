/// Unit tests for Object Tree Property Table Address Handling
import Testing
import Foundation
@testable import ZEngine

@Suite("Object Tree Property Address Validation Tests")
struct ObjectTreePropertyAddressValidationTests {

    @Test("Property table address validation - dynamic memory constraint")
    func testPropertyTableAddressDynamicMemoryConstraint() throws {
        // Test that property table addresses are properly validated to be in dynamic memory

        var staticMemoryData = Data(count: 1000)

        // Fill property defaults with zeros
        for i in 0..<62 {
            staticMemoryData[i] = 0
        }

        let objectOffset = 62

        // Create a v3 object
        for i in 0..<4 {
            staticMemoryData[objectOffset + i] = 0 // attributes
        }
        staticMemoryData[objectOffset + 4] = 0 // parent
        staticMemoryData[objectOffset + 5] = 0 // sibling
        staticMemoryData[objectOffset + 6] = 0 // child

        // Test case 1: Property table address in dynamic memory (valid)
        let validPropertyAddr: UInt16 = 150
        staticMemoryData[objectOffset + 7] = UInt8(validPropertyAddr >> 8)
        staticMemoryData[objectOffset + 8] = UInt8(validPropertyAddr & 0xFF)

        let objectTree = ObjectTree()
        let staticMemoryBase: UInt32 = 500 // Property address 150 < 500, so it's in dynamic memory

        // This should succeed
        try objectTree.load(from: staticMemoryData,
                          version: .v3,
                          objectTableAddress: 0,
                          staticMemoryBase: staticMemoryBase,
                          dictionaryAddress: 800)

        let object1 = objectTree.getObject(1)
        #expect(object1 != nil, "Object with valid property table address should load")
        #expect(object1?.propertyTableAddress == validPropertyAddr, "Property table address should be preserved")
    }

    @Test("Property table address validation - static memory rejection")
    func testPropertyTableAddressStaticMemoryRejection() throws {
        // Test that objects with property table addresses >= static memory base are rejected

        var staticMemoryData = Data(count: 1000)

        // Fill property defaults with zeros
        for i in 0..<62 {
            staticMemoryData[i] = 0
        }

        let objectOffset = 62

        // Create a v3 object
        for i in 0..<4 {
            staticMemoryData[objectOffset + i] = 0 // attributes
        }
        staticMemoryData[objectOffset + 4] = 0 // parent
        staticMemoryData[objectOffset + 5] = 0 // sibling
        staticMemoryData[objectOffset + 6] = 0 // child

        // Test case 2: Property table address >= static memory base (invalid)
        let invalidPropertyAddr: UInt16 = 600
        staticMemoryData[objectOffset + 7] = UInt8(invalidPropertyAddr >> 8)
        staticMemoryData[objectOffset + 8] = UInt8(invalidPropertyAddr & 0xFF)

        let objectTree = ObjectTree()
        let staticMemoryBase: UInt32 = 500 // Property address 600 >= 500, so it's invalid

        // Load should succeed but object should not be loaded
        try objectTree.load(from: staticMemoryData,
                          version: .v3,
                          objectTableAddress: 0,
                          staticMemoryBase: staticMemoryBase,
                          dictionaryAddress: 800)

        let object1 = objectTree.getObject(1)
        #expect(object1 == nil, "Object with invalid property table address should be rejected")
    }

    @Test("Property table address boundary condition")
    func testPropertyTableAddressBoundaryCondition() throws {
        // Test the exact boundary condition where property address equals static memory base

        var staticMemoryData = Data(count: 1000)

        // Fill property defaults with zeros
        for i in 0..<62 {
            staticMemoryData[i] = 0
        }

        let objectOffset = 62

        // Create a v3 object
        for i in 0..<4 {
            staticMemoryData[objectOffset + i] = 0 // attributes
        }
        staticMemoryData[objectOffset + 4] = 0 // parent
        staticMemoryData[objectOffset + 5] = 0 // sibling
        staticMemoryData[objectOffset + 6] = 0 // child

        // Test case 3: Property table address == static memory base (boundary - should be invalid)
        let staticMemoryBase: UInt32 = 500
        let boundaryPropertyAddr: UInt16 = 500 // Equal to static memory base
        staticMemoryData[objectOffset + 7] = UInt8(boundaryPropertyAddr >> 8)
        staticMemoryData[objectOffset + 8] = UInt8(boundaryPropertyAddr & 0xFF)

        let objectTree = ObjectTree()

        // Load should succeed but object should not be loaded (boundary case)
        try objectTree.load(from: staticMemoryData,
                          version: .v3,
                          objectTableAddress: 0,
                          staticMemoryBase: staticMemoryBase,
                          dictionaryAddress: 800)

        let object1 = objectTree.getObject(1)
        #expect(object1 == nil, "Object with property table address equal to static memory base should be rejected")
    }

    @Test("Multiple objects with mixed property addresses")
    func testMultipleObjectsWithMixedPropertyAddresses() throws {
        // Test that validation works correctly when some objects are valid and others aren't

        var staticMemoryData = Data(count: 1000)

        // Fill property defaults with zeros
        for i in 0..<62 {
            staticMemoryData[i] = 0
        }

        let staticMemoryBase: UInt32 = 400

        // Object 1: Valid property address (< static memory base)
        let object1Offset = 62
        for i in 0..<4 {
            staticMemoryData[object1Offset + i] = 0 // attributes
        }
        staticMemoryData[object1Offset + 4] = 0 // parent
        staticMemoryData[object1Offset + 5] = 0 // sibling
        staticMemoryData[object1Offset + 6] = 0 // child
        let validPropertyAddr: UInt16 = 200 // < 400 (valid)
        staticMemoryData[object1Offset + 7] = UInt8(validPropertyAddr >> 8)
        staticMemoryData[object1Offset + 8] = UInt8(validPropertyAddr & 0xFF)

        // Object 2: Invalid property address (>= static memory base)
        let object2Offset = 71 // 62 + 9 bytes for first object
        for i in 0..<4 {
            staticMemoryData[object2Offset + i] = 0 // attributes
        }
        staticMemoryData[object2Offset + 4] = 0 // parent
        staticMemoryData[object2Offset + 5] = 0 // sibling
        staticMemoryData[object2Offset + 6] = 0 // child
        let invalidPropertyAddr: UInt16 = 500 // >= 400 (invalid)
        staticMemoryData[object2Offset + 7] = UInt8(invalidPropertyAddr >> 8)
        staticMemoryData[object2Offset + 8] = UInt8(invalidPropertyAddr & 0xFF)

        let objectTree = ObjectTree()

        try objectTree.load(from: staticMemoryData,
                          version: .v3,
                          objectTableAddress: 0,
                          staticMemoryBase: staticMemoryBase,
                          dictionaryAddress: 800)

        // Object 1 should load successfully
        let object1 = objectTree.getObject(1)
        #expect(object1 != nil, "Object 1 with valid property address should load")
        #expect(object1?.propertyTableAddress == validPropertyAddr, "Object 1 should have correct property address")

        // Object 2 should be rejected (loading should stop at first invalid object)
        let object2 = objectTree.getObject(2)
        #expect(object2 == nil, "Object 2 with invalid property address should not load")
    }

    @Test("Property table address with version 4+ objects")
    func testPropertyTableAddressWithV4Objects() throws {
        // Test property table address validation with v4+ objects (different structure)

        var staticMemoryData = Data(count: 1000)

        // Fill property defaults with zeros
        for i in 0..<62 {
            staticMemoryData[i] = 0
        }

        let objectOffset = 62

        // Create a v4 object (14 bytes total)
        for i in 0..<6 {
            staticMemoryData[objectOffset + i] = 0 // 6 bytes attributes
        }
        staticMemoryData[objectOffset + 6] = 0 // parent high
        staticMemoryData[objectOffset + 7] = 0 // parent low
        staticMemoryData[objectOffset + 8] = 0 // sibling high
        staticMemoryData[objectOffset + 9] = 0 // sibling low
        staticMemoryData[objectOffset + 10] = 0 // child high
        staticMemoryData[objectOffset + 11] = 0 // child low

        // Property table address in dynamic memory
        let validPropertyAddr: UInt16 = 250
        staticMemoryData[objectOffset + 12] = UInt8(validPropertyAddr >> 8)
        staticMemoryData[objectOffset + 13] = UInt8(validPropertyAddr & 0xFF)

        let objectTree = ObjectTree()
        let staticMemoryBase: UInt32 = 500

        try objectTree.load(from: staticMemoryData,
                          version: .v4,
                          objectTableAddress: 0,
                          staticMemoryBase: staticMemoryBase,
                          dictionaryAddress: 800)

        let object1 = objectTree.getObject(1)
        #expect(object1 != nil, "V4 object with valid property address should load")
        #expect(object1?.propertyTableAddress == validPropertyAddr, "V4 object should have correct property address")
    }

    @Test("Zero property table address handling")
    func testZeroPropertyTableAddress() throws {
        // Test that objects with zero property table addresses are rejected (indicates invalid/uninitialized objects)
        // This uses a minimal but complete object table structure

        var staticMemoryData = Data(count: 1000)

        // Fill property defaults with zeros (31 words = 62 bytes)
        for i in 0..<62 {
            staticMemoryData[i] = 0
        }

        // Object 1: Valid property table address at 200 (needed to establish boundary)
        let object1Offset = 62
        // Attributes (4 bytes)
        staticMemoryData[object1Offset + 0] = 0x00
        staticMemoryData[object1Offset + 1] = 0x00
        staticMemoryData[object1Offset + 2] = 0x00
        staticMemoryData[object1Offset + 3] = 0x00
        // Parent (1 byte in v3)
        staticMemoryData[object1Offset + 4] = 0
        // Sibling (1 byte in v3)
        staticMemoryData[object1Offset + 5] = 0
        // Child (1 byte in v3)
        staticMemoryData[object1Offset + 6] = 0
        // Property table address (2 bytes, big-endian)
        let validPropertyAddr: UInt16 = 200
        staticMemoryData[object1Offset + 7] = UInt8((validPropertyAddr >> 8) & 0xFF)
        staticMemoryData[object1Offset + 8] = UInt8(validPropertyAddr & 0xFF)

        // Object 2: Zero property table address
        let object2Offset = object1Offset + 9  // Next object (v3 objects are 9 bytes)
        // Attributes (4 bytes)
        staticMemoryData[object2Offset + 0] = 0x00
        staticMemoryData[object2Offset + 1] = 0x00
        staticMemoryData[object2Offset + 2] = 0x00
        staticMemoryData[object2Offset + 3] = 0x00
        // Parent (1 byte in v3)
        staticMemoryData[object2Offset + 4] = 0
        // Sibling (1 byte in v3)
        staticMemoryData[object2Offset + 5] = 0
        // Child (1 byte in v3)
        staticMemoryData[object2Offset + 6] = 0
        // Property table address (2 bytes, big-endian) - ZERO
        staticMemoryData[object2Offset + 7] = 0
        staticMemoryData[object2Offset + 8] = 0

        // Ensure we have some property data at offset 200 to satisfy the boundary calculation
        staticMemoryData[200] = 0  // Short name length
        staticMemoryData[201] = 0  // End of properties marker

        let objectTree = ObjectTree()

        try objectTree.load(from: staticMemoryData,
                          version: .v3,
                          objectTableAddress: 0,
                          staticMemoryBase: 500,
                          dictionaryAddress: 800)

        let object1 = objectTree.getObject(1)
        let object2 = objectTree.getObject(2)

        #expect(object1 != nil, "Object 1 should load with valid property address")
        if let obj1 = object1 {
            #expect(obj1.propertyTableAddress == validPropertyAddr, "Object 1 should have valid property address")
        }

        #expect(object2 == nil, "Object with zero property table address should NOT load (indicates invalid/uninitialized object)")
    }
}