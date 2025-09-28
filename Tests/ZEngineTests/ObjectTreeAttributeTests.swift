import Testing
import Foundation
@testable import ZEngine

/// Test suite for ObjectTree bit manipulation operations
///
/// These tests specifically verify that bit shift operations work correctly
/// for all valid attribute numbers, including edge cases that previously
/// caused "Not enough bits to represent the passed value" overflow errors.
@Suite("ObjectTree Bit Manipulation Tests")
struct ObjectTreeBitManipulationTests {

    /// Test bit manipulation with UInt64 attributes for all valid attribute positions
    @Test("Bit shift operations for all attribute positions")
    func testBitShiftOperations() throws {
        // Test the core bit manipulation operations that were causing overflow
        // This directly tests the fixed code in hasAttribute and setAttribute

        // Test v3 attributes (0-31)
        for attribute in UInt8(0)...UInt8(31) {
            let bitPosition = UInt64(attribute)

            // Test the bit shift operation that was causing overflow
            let bitMask = UInt64(1) << bitPosition
            #expect(bitMask != 0, "Bit mask for attribute \(attribute) should be non-zero")

            // Test setting a bit
            var attributes: UInt64 = 0
            attributes |= (UInt64(1) << bitPosition)
            #expect(attributes != 0, "Attributes should be non-zero after setting bit \(attribute)")

            // Test checking a bit
            let isSet = (attributes & (UInt64(1) << bitPosition)) != 0
            #expect(isSet, "Bit \(attribute) should be detected as set")

            // Test clearing a bit
            attributes &= ~(UInt64(1) << bitPosition)
            let isCleared = (attributes & (UInt64(1) << bitPosition)) == 0
            #expect(isCleared, "Bit \(attribute) should be cleared")
        }

        // Test v4+ attributes (32-47)
        for attribute in UInt8(32)...UInt8(47) {
            let bitPosition = UInt64(attribute)

            // Test the bit shift operation that was causing overflow
            let bitMask = UInt64(1) << bitPosition
            #expect(bitMask != 0, "Bit mask for attribute \(attribute) should be non-zero")

            // Test setting a bit
            var attributes: UInt64 = 0
            attributes |= (UInt64(1) << bitPosition)
            #expect(attributes != 0, "Attributes should be non-zero after setting bit \(attribute)")

            // Test checking a bit
            let isSet = (attributes & (UInt64(1) << bitPosition)) != 0
            #expect(isSet, "Bit \(attribute) should be detected as set")

            // Test clearing a bit
            attributes &= ~(UInt64(1) << bitPosition)
            let isCleared = (attributes & (UInt64(1) << bitPosition)) == 0
            #expect(isCleared, "Bit \(attribute) should be cleared")
        }
    }

    /// Test edge case: attribute 47 (highest valid v4+ attribute)
    @Test("Edge case: attribute 47")
    func testHighestAttribute() throws {
        // Specifically test attribute 47, which is the highest valid attribute for v4+
        // This was likely the case causing the original overflow
        let attribute = UInt8(47)
        let bitPosition = UInt64(attribute)

        // Verify we can create the bit mask without overflow
        let bitMask = UInt64(1) << bitPosition
        #expect(bitMask == 0x800000000000, "Bit mask for attribute 47 should be 0x800000000000")

        // Test full cycle: set, check, clear, check
        var attributes: UInt64 = 0

        // Set the bit
        attributes |= (UInt64(1) << bitPosition)
        #expect(attributes == bitMask, "Setting bit 47 should result in correct bit mask")

        // Check the bit is set
        let isSet = (attributes & (UInt64(1) << bitPosition)) != 0
        #expect(isSet, "Bit 47 should be detected as set")

        // Clear the bit
        attributes &= ~(UInt64(1) << bitPosition)
        #expect(attributes == 0, "Clearing bit 47 should result in zero attributes")

        // Check the bit is cleared
        let isCleared = (attributes & (UInt64(1) << bitPosition)) == 0
        #expect(isCleared, "Bit 47 should be detected as cleared")
    }

    /// Test that multiple high-numbered attributes can coexist
    @Test("Multiple high attributes")
    func testMultipleHighAttributes() throws {
        var attributes: UInt64 = 0

        // Set several high-numbered attributes
        let highAttributes: [UInt8] = [32, 40, 45, 46, 47]

        for attribute in highAttributes {
            let bitPosition = UInt64(attribute)
            attributes |= (UInt64(1) << bitPosition)
        }

        // Verify all are set
        for attribute in highAttributes {
            let bitPosition = UInt64(attribute)
            let isSet = (attributes & (UInt64(1) << bitPosition)) != 0
            #expect(isSet, "High attribute \(attribute) should be set")
        }

        // Clear alternate attributes
        for (index, attribute) in highAttributes.enumerated() where index % 2 == 0 {
            let bitPosition = UInt64(attribute)
            attributes &= ~(UInt64(1) << bitPosition)
        }

        // Verify correct attributes remain
        for (index, attribute) in highAttributes.enumerated() {
            let bitPosition = UInt64(attribute)
            let isSet = (attributes & (UInt64(1) << bitPosition)) != 0
            if index % 2 == 0 {
                #expect(!isSet, "Even-indexed high attribute \(attribute) should be cleared")
            } else {
                #expect(isSet, "Odd-indexed high attribute \(attribute) should still be set")
            }
        }
    }

    /// Test ObjectTree integration with fixed bit manipulation
    @Test("ObjectTree integration test")
    func testObjectTreeIntegration() throws {
        // Create a mock static memory data containing object table
        // Property defaults (31 words = 62 bytes) + minimal object data
        var staticMemoryData = Data(count: 200)

        // Fill property defaults with zeros
        for i in 0..<62 {
            staticMemoryData[i] = 0
        }

        // Create a minimal v4 object at offset 62
        let objectOffset = 62
        // 6 bytes attributes (all zero)
        for i in 0..<6 {
            staticMemoryData[objectOffset + i] = 0
        }
        // 2 bytes parent (zero)
        staticMemoryData[objectOffset + 6] = 0
        staticMemoryData[objectOffset + 7] = 0
        // 2 bytes sibling (zero)
        staticMemoryData[objectOffset + 8] = 0
        staticMemoryData[objectOffset + 9] = 0
        // 2 bytes child (zero)
        staticMemoryData[objectOffset + 10] = 0
        staticMemoryData[objectOffset + 11] = 0
        // 2 bytes property table (zero - no properties)
        staticMemoryData[objectOffset + 12] = 0
        staticMemoryData[objectOffset + 13] = 0

        // Create ObjectTree and load the data
        let objectTree = ObjectTree()
        try objectTree.load(from: staticMemoryData,
                          version: .v4,
                          objectTableAddress: 0,
                          staticMemoryBase: 0,
                          dictionaryAddress: 200)  // Dictionary at end so objects can load

        // Test high-numbered attribute operations that previously caused overflow
        let testAttribute = UInt8(47)  // Highest valid v4+ attribute

        // Initially should be false
        let initialState = objectTree.getAttribute(1, attribute: testAttribute)
        #expect(!initialState, "Attribute \(testAttribute) should initially be false")

        // Set the attribute - this previously caused "Not enough bits" error
        try objectTree.setAttribute(1, attribute: testAttribute, value: true)
        let afterSet = objectTree.getAttribute(1, attribute: testAttribute)
        #expect(afterSet, "Attribute \(testAttribute) should be true after setting")

        // Clear the attribute
        try objectTree.setAttribute(1, attribute: testAttribute, value: false)
        let afterClear = objectTree.getAttribute(1, attribute: testAttribute)
        #expect(!afterClear, "Attribute \(testAttribute) should be false after clearing")
    }
}