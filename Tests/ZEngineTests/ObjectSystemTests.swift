/// Tests for the Object System (FlagManager, PropertyDefManager, ObjectTreeBuilder)
///
/// These tests verify the complete object compilation pipeline including:
/// - Dynamic flag/attribute assignment
/// - Dynamic property number assignment
/// - Object tree building with relationships
/// - Binary property table generation

import XCTest
@testable import ZEngine

final class ObjectSystemTests: XCTestCase {

    // MARK: - FlagManager Tests

    func testFlagManagerBasicAssignment() throws {
        var flagManager = FlagManager(zMachineVersion: 3)

        // Assign first flag
        let attr1 = try flagManager.assignAttributeNumber(for: "TAKEBIT")
        XCTAssertEqual(attr1, 0, "First flag should get attribute 0")

        // Assign second flag
        let attr2 = try flagManager.assignAttributeNumber(for: "OPENBIT")
        XCTAssertEqual(attr2, 1, "Second flag should get attribute 1")

        // Assign third flag
        let attr3 = try flagManager.assignAttributeNumber(for: "ONBIT")
        XCTAssertEqual(attr3, 2, "Third flag should get attribute 2")
    }

    func testFlagManagerDuplicateReturnsSameNumber() throws {
        var flagManager = FlagManager(zMachineVersion: 3)

        let attr1 = try flagManager.assignAttributeNumber(for: "TAKEBIT")
        let attr2 = try flagManager.assignAttributeNumber(for: "TAKEBIT")

        XCTAssertEqual(attr1, attr2, "Duplicate flag should return same attribute number")
        XCTAssertEqual(flagManager.flagCount, 1, "Flag count should be 1")
    }

    func testFlagManagerVersion3Limit() throws {
        var flagManager = FlagManager(zMachineVersion: 3)

        // Assign 32 flags (maximum for v3)
        for i in 0..<32 {
            let attrNum = try flagManager.assignAttributeNumber(for: "FLAG\(i)")
            XCTAssertEqual(attrNum, i)
        }

        // 33rd flag should throw
        XCTAssertThrowsError(try flagManager.assignAttributeNumber(for: "FLAG32")) { error in
            XCTAssertTrue(error is ParseError, "Expected ParseError but got \(type(of: error))")
            if let parseError = error as? ParseError {
                XCTAssertTrue(parseError.message.contains("Too many flags"))
            }
        }
    }

    func testFlagManagerVersion4Limit() throws {
        var flagManager = FlagManager(zMachineVersion: 4)

        // Assign 48 flags (maximum for v4+)
        for i in 0..<48 {
            let attrNum = try flagManager.assignAttributeNumber(for: "FLAG\(i)")
            XCTAssertEqual(attrNum, i)
        }

        // 49th flag should throw
        XCTAssertThrowsError(try flagManager.assignAttributeNumber(for: "FLAG48"))
    }

    func testFlagManagerReverseLookup() throws {
        var flagManager = FlagManager(zMachineVersion: 3)

        _ = try flagManager.assignAttributeNumber(for: "TAKEBIT")
        _ = try flagManager.assignAttributeNumber(for: "OPENBIT")

        XCTAssertEqual(flagManager.getFlagName(for: 0), "TAKEBIT")
        XCTAssertEqual(flagManager.getFlagName(for: 1), "OPENBIT")
        XCTAssertNil(flagManager.getFlagName(for: 2))
    }

    func testFlagManagerGetAllFlags() throws {
        var flagManager = FlagManager(zMachineVersion: 3)

        _ = try flagManager.assignAttributeNumber(for: "OPENBIT")
        _ = try flagManager.assignAttributeNumber(for: "TAKEBIT")
        _ = try flagManager.assignAttributeNumber(for: "ONBIT")

        let allFlags = flagManager.getAllFlags()

        XCTAssertEqual(allFlags.count, 3)
        XCTAssertEqual(allFlags[0].name, "OPENBIT")
        XCTAssertEqual(allFlags[0].number, 0)
        XCTAssertEqual(allFlags[1].name, "TAKEBIT")
        XCTAssertEqual(allFlags[1].number, 1)
        XCTAssertEqual(allFlags[2].name, "ONBIT")
        XCTAssertEqual(allFlags[2].number, 2)
    }

    // MARK: - PropertyDefManager Tests

    func testPropertyManagerBasicAssignment() throws {
        var propManager = PropertyDefManager(zMachineVersion: 3)

        // Assign first property
        let prop1 = try propManager.assignPropertyNumber(for: "DESC")
        XCTAssertEqual(prop1, 1, "First property should get number 1")

        // Assign second property
        let prop2 = try propManager.assignPropertyNumber(for: "LDESC")
        XCTAssertEqual(prop2, 2, "Second property should get number 2")
    }

    func testPropertyManagerDuplicateReturnsSameNumber() throws {
        var propManager = PropertyDefManager(zMachineVersion: 3)

        let prop1 = try propManager.assignPropertyNumber(for: "DESC")
        let prop2 = try propManager.assignPropertyNumber(for: "DESC")

        XCTAssertEqual(prop1, prop2)
        XCTAssertEqual(propManager.propertyCount, 1)
    }

    func testPropertyManagerDefaultValues() {
        var propManager = PropertyDefManager(zMachineVersion: 3)

        // Define defaults
        propManager.definePropertyDefault(name: "SIZE", defaultValue: .integer(5))
        propManager.definePropertyDefault(name: "CAPACITY", defaultValue: .integer(10))

        // Retrieve defaults
        XCTAssertEqual(propManager.getDefaultValue(for: "SIZE"), .integer(5))
        XCTAssertEqual(propManager.getDefaultValue(for: "CAPACITY"), .integer(10))
        XCTAssertEqual(propManager.getDefaultValue(for: "NONEXISTENT"), .none)
    }

    func testPropertyManagerVersion3Limit() throws {
        var propManager = PropertyDefManager(zMachineVersion: 3)

        // Assign 31 properties (maximum for v3)
        for i in 1...31 {
            let propNum = try propManager.assignPropertyNumber(for: "PROP\(i)")
            XCTAssertEqual(propNum, i)
        }

        // 32nd property should throw
        XCTAssertThrowsError(try propManager.assignPropertyNumber(for: "PROP32"))
    }

    func testPropertyManagerVersion4Limit() throws {
        var propManager = PropertyDefManager(zMachineVersion: 4)

        // Assign 63 properties (maximum for v4+)
        for i in 1...63 {
            let propNum = try propManager.assignPropertyNumber(for: "PROP\(i)")
            XCTAssertEqual(propNum, i)
        }

        // 64th property should throw
        XCTAssertThrowsError(try propManager.assignPropertyNumber(for: "PROP64"))
    }

    func testPropertyManagerReverseLookup() throws {
        var propManager = PropertyDefManager(zMachineVersion: 3)

        _ = try propManager.assignPropertyNumber(for: "DESC")
        _ = try propManager.assignPropertyNumber(for: "LDESC")

        XCTAssertEqual(propManager.getPropertyName(for: 1), "DESC")
        XCTAssertEqual(propManager.getPropertyName(for: 2), "LDESC")
        XCTAssertNil(propManager.getPropertyName(for: 3))
    }

    // MARK: - ObjectTreeBuilder Tests

    func testObjectTreeBuilderBasicObject() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        // Add a simple object
        try builder.addObject(
            name: "LANTERN",
            parentName: nil,
            flags: ["TAKEBIT"],
            properties: ["DESC": .string("brass lantern")],
            location: .unknown
        )

        let compiled = try builder.build()

        XCTAssertEqual(compiled.count, 1)
        XCTAssertEqual(compiled[0].id, 1)
        XCTAssertEqual(compiled[0].name, "LANTERN")
        XCTAssertEqual(compiled[0].parentID, 0)
        XCTAssertEqual(compiled[0].siblingID, 0)
        XCTAssertEqual(compiled[0].childID, 0)
    }

    func testObjectTreeBuilderParentChildRelationship() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        // Add parent object
        try builder.addObject(
            name: "ROOM",
            parentName: nil,
            flags: [],
            properties: [:],
            location: .unknown
        )

        // Add child object
        try builder.addObject(
            name: "TABLE",
            parentName: "ROOM",
            flags: [],
            properties: [:],
            location: .unknown
        )

        let compiled = try builder.build()

        XCTAssertEqual(compiled.count, 2)

        // ROOM should be object 1
        XCTAssertEqual(compiled[0].name, "ROOM")
        XCTAssertEqual(compiled[0].parentID, 0)
        XCTAssertEqual(compiled[0].childID, 2)  // TABLE is first child

        // TABLE should be object 2
        XCTAssertEqual(compiled[1].name, "TABLE")
        XCTAssertEqual(compiled[1].parentID, 1)  // Parent is ROOM
        XCTAssertEqual(compiled[1].childID, 0)   // No children
    }

    func testObjectTreeBuilderSiblingChain() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        // Add parent
        try builder.addObject(name: "ROOM", parentName: nil, flags: [], properties: [:], location: .unknown)

        // Add three children
        try builder.addObject(name: "TABLE", parentName: "ROOM", flags: [], properties: [:], location: .unknown)
        try builder.addObject(name: "CHAIR", parentName: "ROOM", flags: [], properties: [:], location: .unknown)
        try builder.addObject(name: "LAMP", parentName: "ROOM", flags: [], properties: [:], location: .unknown)

        let compiled = try builder.build()

        XCTAssertEqual(compiled.count, 4)

        // ROOM (id=1) should have TABLE (id=2) as first child
        XCTAssertEqual(compiled[0].childID, 2)

        // TABLE (id=2) should have CHAIR (id=3) as sibling
        XCTAssertEqual(compiled[1].siblingID, 3)

        // CHAIR (id=3) should have LAMP (id=4) as sibling
        XCTAssertEqual(compiled[2].siblingID, 4)

        // LAMP (id=4) should have no sibling
        XCTAssertEqual(compiled[3].siblingID, 0)
    }

    func testObjectTreeBuilderAttributeGeneration() throws {
        var flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)

        // Pre-assign some flags to establish order
        _ = try flagManager.assignAttributeNumber(for: "TAKEBIT")
        _ = try flagManager.assignAttributeNumber(for: "OPENBIT")
        _ = try flagManager.assignAttributeNumber(for: "ONBIT")

        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        try builder.addObject(
            name: "LANTERN",
            parentName: nil,
            flags: ["TAKEBIT", "ONBIT"],
            properties: [:],
            location: .unknown
        )

        let compiled = try builder.build()

        // Check attributes: TAKEBIT (0) and ONBIT (2) should be set
        // Bit layout: MSB first in each byte
        // Byte 0: bits 7-0 correspond to attributes 0-7
        // TAKEBIT=0 means bit 7, ONBIT=2 means bit 5
        let expectedByte0: UInt8 = 0b10100000  // bits 7 and 5 set
        XCTAssertEqual(compiled[0].attributes[0], expectedByte0)
    }

    func testObjectTreeBuilderPropertyTableDescendingOrder() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        var propManager = PropertyDefManager(zMachineVersion: 3)

        // Pre-assign property numbers
        _ = try propManager.assignPropertyNumber(for: "SIZE")      // 1
        _ = try propManager.assignPropertyNumber(for: "CAPACITY")  // 2
        _ = try propManager.assignPropertyNumber(for: "VALUE")     // 3

        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        try builder.addObject(
            name: "BOX",
            parentName: nil,
            flags: [],
            properties: [
                "SIZE": .integer(10),
                "CAPACITY": .integer(20),
                "VALUE": .integer(5)
            ],
            location: .unknown
        )

        let compiled = try builder.build()
        let propTable = compiled[0].propertyTable

        // Property table format (v3):
        // Byte 0: text length (0)
        // Then properties in DESCENDING order: VALUE(3), CAPACITY(2), SIZE(1)
        // Each property: size/number byte + data bytes

        XCTAssertEqual(propTable[0], 0)  // Text length = 0

        // Parse properties (they should be in descending order: 3, 2, 1)
        var offset = 1
        var foundProps: [Int] = []

        while offset < propTable.count && propTable[offset] != 0 {
            let header = propTable[offset]
            let propNum = Int(header & 0x1F)
            let size = Int((header >> 5) & 0x0F) + 1
            foundProps.append(propNum)
            offset += 1 + size
        }

        XCTAssertEqual(foundProps, [3, 2, 1], "Properties should be in descending order")
    }

    func testObjectTreeBuilderDuplicateObjectError() {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        XCTAssertNoThrow(try builder.addObject(name: "LAMP", parentName: nil, flags: [], properties: [:], location: .unknown))

        XCTAssertThrowsError(try builder.addObject(name: "LAMP", parentName: nil, flags: [], properties: [:], location: .unknown)) { error in
            XCTAssertTrue(error is ParseError)
            if let parseError = error as? ParseError {
                XCTAssertTrue(parseError.message.contains("Duplicate object"))
            }
        }
    }

    func testObjectTreeBuilderUndefinedParentError() {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        XCTAssertNoThrow(try builder.addObject(name: "LAMP", parentName: "NONEXISTENT", flags: [], properties: [:], location: .unknown))

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertTrue(error is ParseError)
            if let parseError = error as? ParseError {
                XCTAssertTrue(parseError.message.contains("Undefined object"))
            }
        }
    }

    func testObjectTreeBuilderGlobalObjectsPattern() throws {
        var flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)

        // Simulate GLOBAL-OBJECTS pattern (defines all flags early)
        let globalFlags = [
            "RMUNGBIT", "INVISIBLE", "TOUCHBIT", "SURFACEBIT",
            "TRYTAKEBIT", "OPENBIT", "SEARCHBIT", "TRANSBIT",
            "ONBIT", "RLANDBIT", "FIGHTBIT", "STAGGERED",
            "WEARBIT", "KLUDGEBIT", "MAZEBIT", "READBIT"
        ]

        for flag in globalFlags {
            _ = try flagManager.assignAttributeNumber(for: flag)
        }

        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        try builder.addObject(
            name: "GLOBAL-OBJECTS",
            parentName: nil,
            flags: globalFlags,
            properties: ["DESC": .string("it")],
            location: .unknown
        )

        // Now add a regular object
        try builder.addObject(
            name: "LANTERN",
            parentName: nil,
            flags: ["TAKEBIT", "ONBIT"],
            properties: [:],
            location: .unknown
        )

        let compiled = try builder.build()
        XCTAssertEqual(compiled.count, 2)

        // Get the updated flag manager from the builder
        let updatedFlagManager = builder.getFlagManager()

        // Verify TAKEBIT got attribute 16 (next after GLOBAL-OBJECTS flags)
        let takebitAttr = updatedFlagManager.getAttributeNumber(for: "TAKEBIT")
        XCTAssertEqual(takebitAttr, 16)

        // Verify ONBIT already has attribute 8 (from GLOBAL-OBJECTS)
        let onbitAttr = updatedFlagManager.getAttributeNumber(for: "ONBIT")
        XCTAssertEqual(onbitAttr, 8)
    }

    // MARK: - Short Name Encoding Tests

    func testShortNameEncoding() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        try builder.addObject(
            name: "LANTERN",
            parentName: nil,
            flags: [],
            properties: ["DESC": .string("brass lantern")],
            location: .unknown
        )

        let compiled = try builder.build()

        // Short name should be Z-encoded with length prefix
        let shortName = compiled[0].shortName
        XCTAssertGreaterThan(shortName.count, 1, "Short name should have length prefix and data")

        // First byte is length in words
        let lengthInWords = Int(shortName[0])
        XCTAssertGreaterThan(lengthInWords, 0, "Length should be greater than 0")

        // Total bytes should be 1 (length) + (lengthInWords * 2)
        XCTAssertEqual(shortName.count, 1 + (lengthInWords * 2), "Short name byte count should match length")
    }

    func testShortNameEmptyWhenNoDesc() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        try builder.addObject(
            name: "OBJECT",
            parentName: nil,
            flags: [],
            properties: [:],  // No DESC property
            location: .unknown
        )

        let compiled = try builder.build()

        // Short name should be empty (just length byte = 0)
        XCTAssertEqual(compiled[0].shortName, [0], "Empty short name should be [0]")
    }

    // MARK: - Property Value Encoding Tests

    func testPropertyValueIntegerEncoding() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        try builder.addObject(
            name: "BOX",
            parentName: nil,
            flags: [],
            properties: [
                "SIZE": .integer(1000)
            ],
            location: .unknown
        )

        let compiled = try builder.build()
        let properties = compiled[0].properties

        XCTAssertEqual(properties.count, 1)

        // Integer 1000 = 0x03E8 → bytes [0x03, 0xE8]
        if case .bytes(let data) = properties[0].encoding {
            XCTAssertEqual(data.count, 2, "Integer should encode to 2 bytes")
            XCTAssertEqual(data[0], 0x03, "High byte should be 0x03")
            XCTAssertEqual(data[1], 0xE8, "Low byte should be 0xE8")
        } else {
            XCTFail("Expected .bytes encoding for integer")
        }
    }

    func testPropertyValueRoutineReference() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        try builder.addObject(
            name: "DOOR",
            parentName: nil,
            flags: [],
            properties: [
                "ACTION": .routine("DOOR-FCN")
            ],
            location: .unknown
        )

        let compiled = try builder.build()
        let properties = compiled[0].properties

        XCTAssertEqual(properties.count, 1)

        // Should generate symbolic routine reference
        if case .routineReference(let name) = properties[0].encoding {
            XCTAssertEqual(name, "DOOR-FCN", "Routine name should be preserved")
        } else {
            XCTFail("Expected .routineReference encoding for routine")
        }
    }

    func testPropertyValueStringReference() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        try builder.addObject(
            name: "SIGN",
            parentName: nil,
            flags: [],
            properties: [
                "TEXT": .string("Welcome to Zork!")
            ],
            location: .unknown
        )

        let compiled = try builder.build()
        let properties = compiled[0].properties

        XCTAssertEqual(properties.count, 1)

        // Should generate symbolic string reference
        if case .stringReference(let text) = properties[0].encoding {
            XCTAssertEqual(text, "Welcome to Zork!", "String content should be preserved")
        } else {
            XCTFail("Expected .stringReference encoding for string")
        }
    }

    func testPropertyValueTableReference() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        try builder.addObject(
            name: "CONTAINER",
            parentName: nil,
            flags: [],
            properties: [
                "CONTFCN": .table("CONTAINER-TABLE")
            ],
            location: .unknown
        )

        let compiled = try builder.build()
        let properties = compiled[0].properties

        XCTAssertEqual(properties.count, 1)

        // Should generate symbolic table reference
        if case .tableReference(let name) = properties[0].encoding {
            XCTAssertEqual(name, "CONTAINER-TABLE", "Table name should be preserved")
        } else {
            XCTFail("Expected .tableReference encoding for table")
        }
    }

    func testPropertyValueObjectReferenceV3() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        // Create two objects
        try builder.addObject(
            name: "ROOM",
            parentName: nil,
            flags: [],
            properties: [:],
            location: .unknown
        )

        try builder.addObject(
            name: "KEY",
            parentName: nil,
            flags: [],
            properties: [
                "DOOR-TO": .object("ROOM")
            ],
            location: .unknown
        )

        let compiled = try builder.build()
        let keyProps = compiled[1].properties

        XCTAssertEqual(keyProps.count, 1)

        // v3: Object references are 1 byte
        if case .bytes(let data) = keyProps[0].encoding {
            XCTAssertEqual(data.count, 1, "v3 object reference should be 1 byte")
            XCTAssertEqual(data[0], 1, "ROOM is object ID 1")
        } else {
            XCTFail("Expected .bytes encoding for object reference")
        }
    }

    func testPropertyValueObjectReferenceV4() throws {
        let flagManager = FlagManager(zMachineVersion: 4)
        let propManager = PropertyDefManager(zMachineVersion: 4)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 4,
            flagManager: flagManager,
            propertyManager: propManager
        )

        // Create two objects
        try builder.addObject(
            name: "ROOM",
            parentName: nil,
            flags: [],
            properties: [:],
            location: .unknown
        )

        try builder.addObject(
            name: "KEY",
            parentName: nil,
            flags: [],
            properties: [
                "DOOR-TO": .object("ROOM")
            ],
            location: .unknown
        )

        let compiled = try builder.build()
        let keyProps = compiled[1].properties

        XCTAssertEqual(keyProps.count, 1)

        // v4+: Object references are 2 bytes
        if case .bytes(let data) = keyProps[0].encoding {
            XCTAssertEqual(data.count, 2, "v4+ object reference should be 2 bytes")
            XCTAssertEqual(data[0], 0, "High byte should be 0")
            XCTAssertEqual(data[1], 1, "Low byte should be 1 (ROOM is object ID 1)")
        } else {
            XCTFail("Expected .bytes encoding for object reference")
        }
    }

    func testPropertyValueNoneEncoding() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        try builder.addObject(
            name: "THING",
            parentName: nil,
            flags: [],
            properties: [
                "VALUE": .none
            ],
            location: .unknown
        )

        let compiled = try builder.build()
        let properties = compiled[0].properties

        XCTAssertEqual(properties.count, 1)

        // .none should encode as [0, 0]
        if case .bytes(let data) = properties[0].encoding {
            XCTAssertEqual(data, [0, 0], ".none should encode as two zero bytes")
        } else {
            XCTFail("Expected .bytes encoding for .none")
        }
    }

    // MARK: - CompiledProperty Tests

    func testCompiledPropertiesDescendingOrder() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        var propManager = PropertyDefManager(zMachineVersion: 3)

        // Pre-assign property numbers
        _ = try propManager.assignPropertyNumber(for: "ALPHA")   // 1
        _ = try propManager.assignPropertyNumber(for: "BETA")    // 2
        _ = try propManager.assignPropertyNumber(for: "GAMMA")   // 3
        _ = try propManager.assignPropertyNumber(for: "DELTA")   // 4

        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        try builder.addObject(
            name: "TEST",
            parentName: nil,
            flags: [],
            properties: [
                "BETA": .integer(2),
                "DELTA": .integer(4),
                "ALPHA": .integer(1),
                "GAMMA": .integer(3)
            ],
            location: .unknown
        )

        let compiled = try builder.build()
        let props = compiled[0].properties

        XCTAssertEqual(props.count, 4)

        // Properties should be in DESCENDING order by number
        XCTAssertEqual(props[0].number, 4, "First should be DELTA (4)")
        XCTAssertEqual(props[1].number, 3, "Second should be GAMMA (3)")
        XCTAssertEqual(props[2].number, 2, "Third should be BETA (2)")
        XCTAssertEqual(props[3].number, 1, "Fourth should be ALPHA (1)")

        // Verify names match
        XCTAssertEqual(props[0].name, "DELTA")
        XCTAssertEqual(props[1].name, "GAMMA")
        XCTAssertEqual(props[2].name, "BETA")
        XCTAssertEqual(props[3].name, "ALPHA")
    }

    func testSpecialPropertiesExcluded() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        try builder.addObject(
            name: "THING",
            parentName: nil,
            flags: ["TAKEBIT"],
            properties: [
                "DESC": .string("a thing"),        // Special - becomes short name
                "FLAGS": .atom("OPENBIT"),         // Special - handled separately
                "IN": .object("ROOM"),             // Special - determines parent
                "SYNONYM": .atom("OBJECT"),        // Special - dictionary entry
                "ADJECTIVE": .atom("SMALL"),       // Special - dictionary entry
                "SIZE": .integer(10)               // Regular property
            ],
            location: .unknown
        )

        let compiled = try builder.build()
        let props = compiled[0].properties

        // Only SIZE should be in the properties list
        XCTAssertEqual(props.count, 1, "Only regular properties should be included")
        XCTAssertEqual(props[0].name, "SIZE")
    }

    func testMixedPropertyTypes() throws {
        let flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)
        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        // Create referenced object first
        try builder.addObject(
            name: "TARGET",
            parentName: nil,
            flags: [],
            properties: [:],
            location: .unknown
        )

        try builder.addObject(
            name: "COMPLEX",
            parentName: nil,
            flags: [],
            properties: [
                "NUM": .integer(42),
                "ROUTINE": .routine("HANDLER"),
                "TEXT": .string("hello"),
                "TABLE": .table("DATA"),
                "OBJ": .object("TARGET")
            ],
            location: .unknown
        )

        let compiled = try builder.build()
        let props = compiled[1].properties

        XCTAssertEqual(props.count, 5, "Should have all 5 properties")

        // Verify each encoding type
        var foundInteger = false
        var foundRoutine = false
        var foundString = false
        var foundTable = false
        var foundObject = false

        for prop in props {
            switch prop.encoding {
            case .bytes:
                if prop.name == "NUM" || prop.name == "OBJ" {
                    if prop.name == "NUM" { foundInteger = true }
                    if prop.name == "OBJ" { foundObject = true }
                }
            case .routineReference(let name):
                XCTAssertEqual(name, "HANDLER")
                foundRoutine = true
            case .stringReference(let text):
                XCTAssertEqual(text, "hello")
                foundString = true
            case .tableReference(let name):
                XCTAssertEqual(name, "DATA")
                foundTable = true
            }
        }

        XCTAssertTrue(foundInteger, "Should have integer encoding")
        XCTAssertTrue(foundRoutine, "Should have routine reference")
        XCTAssertTrue(foundString, "Should have string reference")
        XCTAssertTrue(foundTable, "Should have table reference")
        XCTAssertTrue(foundObject, "Should have object encoding")
    }
}
