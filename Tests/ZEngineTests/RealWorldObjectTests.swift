/// Real-World Object Tests - Validates implementation against actual ZIL objects
///
/// These tests use object definitions from actual Infocom games (zorkzero, zork1)
/// to verify that our compiler produces correct output for real-world ZIL code.

import XCTest
@testable import ZEngine

final class RealWorldObjectTests: XCTestCase {

    // MARK: - Test Objects from Zorkzero Chess

    func testBlackKnightObject() throws {
        // From zorkzero/chess.zil lines 100-109:
        // <OBJECT BLACK-KNIGHT
        //     (DESC "mounted soldier")
        //     (LDESC "There is a soldier on horseback...")
        //     (SYNONYM SOLDIER KNIGHT HORSE MAN)
        //     (ADJECTIVE MOUNTED BLACK)
        //     (FLAGS ACTORBIT CONTBIT OPENBIT SEARCHBIT BLACKBIT)
        //     (ACTION PIECE-F)>

        var flagManager = FlagManager(zMachineVersion: 3)
        var propManager = PropertyDefManager(zMachineVersion: 3)

        // Pre-assign flags to simulate GLOBAL-OBJECTS pattern
        _ = try flagManager.assignAttributeNumber(for: "ACTORBIT")   // 0
        _ = try flagManager.assignAttributeNumber(for: "CONTBIT")    // 1
        _ = try flagManager.assignAttributeNumber(for: "OPENBIT")    // 2
        _ = try flagManager.assignAttributeNumber(for: "SEARCHBIT")  // 3
        _ = try flagManager.assignAttributeNumber(for: "BLACKBIT")   // 4

        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        // Add the BLACK-KNIGHT object
        try builder.addObject(
            name: "BLACK-KNIGHT",
            parentName: nil,
            flags: ["ACTORBIT", "CONTBIT", "OPENBIT", "SEARCHBIT", "BLACKBIT"],
            properties: [
                "DESC": .string("mounted soldier"),
                "LDESC": .string("There is a soldier on horseback here. His armor is made of the dullest metals, and his steed is darker than the night."),
                "SYNONYM": .atom("SOLDIER KNIGHT HORSE MAN"),  // In real ZIL, handled by parser
                "ADJECTIVE": .atom("MOUNTED BLACK"),            // In real ZIL, handled by parser
                "ACTION": .routine("PIECE-F")
            ],
            location: .unknown
        )

        let compiled = try builder.build()

        // Verify object structure
        XCTAssertEqual(compiled.count, 1, "Should have one object")
        XCTAssertEqual(compiled[0].name, "BLACK-KNIGHT")
        XCTAssertEqual(compiled[0].id, 1)

        // Verify attributes (all 5 flags should be set)
        let attrs = compiled[0].attributes
        XCTAssertGreaterThan(attrs.count, 0, "Should have attribute bytes")

        // Verify flags are set correctly (bits 7-3 should be set in first byte)
        // ACTORBIT(0) = bit 7, CONTBIT(1) = bit 6, OPENBIT(2) = bit 5
        // SEARCHBIT(3) = bit 4, BLACKBIT(4) = bit 3
        let expectedByte0: UInt8 = 0b11111000  // bits 7,6,5,4,3 set
        XCTAssertEqual(attrs[0], expectedByte0, "All 5 flags should be set in first byte")

        // Verify short name encoding
        let shortName = compiled[0].shortName
        XCTAssertGreaterThan(shortName.count, 0, "Should have encoded short name")
        XCTAssertEqual(shortName[0], UInt8(shortName.count - 1) / 2, "First byte should be word count")

        // Verify properties are present and in descending order
        let props = compiled[0].properties
        XCTAssertGreaterThan(props.count, 0, "Should have properties")

        // Verify ACTION property is a routine reference
        let actionProp = props.first { $0.name == "ACTION" }
        XCTAssertNotNil(actionProp, "Should have ACTION property")
        if let action = actionProp {
            if case .routineReference(let name) = action.encoding {
                XCTAssertEqual(name, "PIECE-F", "ACTION should reference PIECE-F routine")
            } else {
                XCTFail("ACTION should be a routine reference")
            }
        }

        // Verify DESC property is a string reference
        let descProp = props.first { $0.name == "DESC" }
        if let desc = descProp {
            if case .stringReference(let text) = desc.encoding {
                XCTAssertEqual(text, "mounted soldier", "DESC should contain the description text")
            } else {
                XCTFail("DESC should be a string reference")
            }
        }
    }

    func testWhitePawnObject() throws {
        // From zorkzero/chess.zil lines 163-173:
        // <OBJECT WHITE-PAWN
        //     (DESC "infantryman")
        //     (LDESC "...")
        //     (SYNONYM INFANTRYMAN PAWN SOLDIER MAN)
        //     (ADJECTIVE WHITE)
        //     (FLAGS ACTORBIT CONTBIT OPENBIT SEARCHBIT WHITEBIT)
        //     (ACTION PIECE-F)>

        var flagManager = FlagManager(zMachineVersion: 3)
        var propManager = PropertyDefManager(zMachineVersion: 3)

        // Pre-assign flags
        _ = try flagManager.assignAttributeNumber(for: "ACTORBIT")
        _ = try flagManager.assignAttributeNumber(for: "CONTBIT")
        _ = try flagManager.assignAttributeNumber(for: "OPENBIT")
        _ = try flagManager.assignAttributeNumber(for: "SEARCHBIT")
        _ = try flagManager.assignAttributeNumber(for: "WHITEBIT")

        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        try builder.addObject(
            name: "WHITE-PAWN",
            parentName: nil,
            flags: ["ACTORBIT", "CONTBIT", "OPENBIT", "SEARCHBIT", "WHITEBIT"],
            properties: [
                "DESC": .string("infantryman"),
                "LDESC": .string("A foot soldier stands here, armed only with a pike and shield."),
                "ACTION": .routine("PIECE-F")
            ],
            location: .unknown
        )

        let compiled = try builder.build()

        XCTAssertEqual(compiled.count, 1)
        XCTAssertEqual(compiled[0].name, "WHITE-PAWN")

        // Verify short name
        let shortName = compiled[0].shortName
        XCTAssertGreaterThan(shortName.count, 0)

        // Verify properties
        let props = compiled[0].properties
        XCTAssertGreaterThan(props.count, 0)

        // Verify all properties are in descending order
        for i in 1..<props.count {
            XCTAssertGreaterThan(props[i-1].number, props[i].number,
                               "Properties should be in descending order")
        }
    }

    // MARK: - Multiple Objects with Relationships

    func testChessPieceHierarchy() throws {
        // Test a simple hierarchy: CHESSBOARD contains pieces
        var flagManager = FlagManager(zMachineVersion: 3)
        var propManager = PropertyDefManager(zMachineVersion: 3)

        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        // Add board first
        try builder.addObject(
            name: "CHESSBOARD",
            parentName: nil,
            flags: [],
            properties: [
                "DESC": .string("chessboard")
            ],
            location: .unknown
        )

        // Add pieces as children
        try builder.addObject(
            name: "WHITE-KING",
            parentName: "CHESSBOARD",
            flags: [],
            properties: [
                "DESC": .string("white king")
            ],
            location: .unknown
        )

        try builder.addObject(
            name: "BLACK-KING",
            parentName: "CHESSBOARD",
            flags: [],
            properties: [
                "DESC": .string("black king")
            ],
            location: .unknown
        )

        let compiled = try builder.build()

        XCTAssertEqual(compiled.count, 3)

        // CHESSBOARD should have WHITE-KING as first child
        XCTAssertEqual(compiled[0].name, "CHESSBOARD")
        XCTAssertEqual(compiled[0].childID, 2, "First child should be WHITE-KING (id 2)")

        // WHITE-KING should have BLACK-KING as sibling
        XCTAssertEqual(compiled[1].name, "WHITE-KING")
        XCTAssertEqual(compiled[1].parentID, 1, "Parent should be CHESSBOARD (id 1)")
        XCTAssertEqual(compiled[1].siblingID, 3, "Sibling should be BLACK-KING (id 3)")

        // BLACK-KING should have no sibling
        XCTAssertEqual(compiled[2].name, "BLACK-KING")
        XCTAssertEqual(compiled[2].parentID, 1, "Parent should be CHESSBOARD (id 1)")
        XCTAssertEqual(compiled[2].siblingID, 0, "Should have no sibling")
    }

    // MARK: - Property Encoding Validation

    func testRealWorldPropertyTypes() throws {
        // Test various property value types as they appear in real ZIL
        var flagManager = FlagManager(zMachineVersion: 3)
        var propManager = PropertyDefManager(zMachineVersion: 3)

        var builder = ObjectTreeBuilder(
            zMachineVersion: 3,
            flagManager: flagManager,
            propertyManager: propManager
        )

        try builder.addObject(
            name: "TEST-OBJECT",
            parentName: nil,
            flags: [],
            properties: [
                "SIZE": .integer(10),              // Numeric property
                "CAPACITY": .integer(5),           // Another numeric
                "ACTION": .routine("TEST-F"),      // Routine reference
                "DESCFCN": .routine("DESC-FCN"),   // Description function
                "TEXT": .string("test message")   // String property
            ],
            location: .unknown
        )

        let compiled = try builder.build()
        let props = compiled[0].properties

        // Verify we have all properties
        XCTAssertEqual(props.count, 5, "Should have 5 properties")

        // Check integer encoding
        let sizeProp = props.first { $0.name == "SIZE" }
        XCTAssertNotNil(sizeProp)
        if let size = sizeProp {
            if case .bytes(let data) = size.encoding {
                XCTAssertEqual(data.count, 2, "Integer should be 2 bytes")
                let value = (Int(data[0]) << 8) | Int(data[1])
                XCTAssertEqual(value, 10, "Should decode to 10")
            } else {
                XCTFail("SIZE should have bytes encoding")
            }
        }

        // Check routine references
        let actionProp = props.first { $0.name == "ACTION" }
        if let action = actionProp {
            if case .routineReference(let name) = action.encoding {
                XCTAssertEqual(name, "TEST-F")
            } else {
                XCTFail("ACTION should be routine reference")
            }
        }

        // Check string reference
        let textProp = props.first { $0.name == "TEXT" }
        if let text = textProp {
            if case .stringReference(let content) = text.encoding {
                XCTAssertEqual(content, "test message")
            } else {
                XCTFail("TEXT should be string reference")
            }
        }
    }

    // MARK: - Edge Cases from Real Games

    func testGlobalObjectsPattern() throws {
        // From zork1/gglobals.zil - the GLOBAL-OBJECTS pattern
        // This object defines all flags used in the game
        var flagManager = FlagManager(zMachineVersion: 3)
        let propManager = PropertyDefManager(zMachineVersion: 3)

        let globalFlags = [
            "RMUNGBIT", "INVISIBLE", "TOUCHBIT", "SURFACEBIT",
            "TRYTAKEBIT", "OPENBIT", "SEARCHBIT", "TRANSBIT",
            "ONBIT", "RLANDBIT", "FIGHTBIT", "STAGGERED",
            "WEARBIT"
        ]

        // Pre-assign all flags
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
            properties: [:],
            location: .unknown
        )

        let compiled = try builder.build()

        // Verify all flags are assigned sequentially
        let updatedFlags = builder.getFlagManager()
        for (index, flag) in globalFlags.enumerated() {
            let attrNum = updatedFlags.getAttributeNumber(for: flag)
            XCTAssertEqual(attrNum, index, "\(flag) should have attribute \(index)")
        }

        // Verify attribute bits are set correctly
        let attrs = compiled[0].attributes
        XCTAssertGreaterThan(attrs.count, 0)

        // With 13 flags, first byte should have all 8 bits set
        XCTAssertEqual(attrs[0], 0xFF, "First byte should have all bits set")

        // Second byte should have 5 bits set (flags 8-12)
        XCTAssertEqual(attrs[1], 0xF8, "Second byte should have top 5 bits set")
    }
}
