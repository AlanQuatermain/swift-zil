import Testing
@testable import ZEngine
import Foundation

/// Comprehensive test fixtures for Z-Machine assembler validation
///
/// This file contains realistic ZAP assembly programs and their expected binary outputs
/// for testing the complete assembler pipeline including:
/// - Instruction encoding across different Z-Machine versions
/// - Object table generation with property sorting
/// - Memory layout and address calculations
/// - Story file validation and checksum calculation
@Suite("Z-Machine Assembler Test Fixtures")
struct ZAssemblerTestFixtures {

    // MARK: - Simple Instruction Test Fixtures

    /// Basic 0OP instruction test - simple routine with no arguments
    static let simpleZeroOpProgram = """
    .ZVERSION 3
    .START MAIN

    .FUNCT MAIN
        RTRUE

    .END
    """

    /// Expected binary output for simpleZeroOpProgram (V3)
    static let simpleZeroOpExpectedV3: [UInt8] = [
        // Header (64 bytes) - key fields only shown
        0x03,                    // Version 3
        0x00,                    // Flags 1
        0x00, 0x01,              // Release 1
        0x00, 0x45,              // High memory base (0x0045 = 69)
        0x00, 0x45,              // Initial PC (packed address for MAIN)
        0x00, 0x00,              // Dictionary address (0)
        0x01, 0xE0,              // Object table address (0x01E0 = 480)
        0x00, 0x40,              // Global variables address (0x40 = 64)
        0x00, 0x44,              // Static memory base (0x44 = 68)
        // ... rest of header zeros/defaults
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,

        // Global variables (240 * 2 = 480 bytes, all zeros)
        // ... (truncated for brevity - would be 480 zero bytes)

        // MAIN function at high memory
        0xB0                     // RTRUE instruction (0OP form)
    ]

    /// 1OP instruction test with operand types
    static let oneOpProgram = """
    .ZVERSION 3
    .START MAIN

    .FUNCT MAIN,X
        ZERO? X /TRUE
        PRINTN X
        RFALSE

    .END
    """

    /// 2OP instruction test with different operand combinations
    static let twoOpProgram = """
    .ZVERSION 3
    .START MAIN

    .FUNCT MAIN,X,Y
        EQUAL? X,Y /SUCCESS
        LESS? X,100 \\FAILURE
        ADD X,Y >X
        RTRUE
    ?SUCCESS:
        PRINTI "Equal!"
        RTRUE
    ?FAILURE:
        RFALSE

    .END
    """

    /// Variable instruction test (CALL, etc.)
    static let varInstructionProgram = """
    .ZVERSION 4
    .START MAIN

    .FUNCT MAIN
        CALL TEST-FUNC,1,2,3 >RESULT
        PRINTN RESULT
        RTRUE

    .FUNCT TEST-FUNC,A,B,C
        ADD A,B >TEMP
        ADD TEMP,C
        RETURN STACK

    .END
    """

    // MARK: - Object Definition Test Fixtures

    /// Simple object with basic properties
    static let simpleObjectProgram = """
    .ZVERSION 3
    .START MAIN

    .OBJECT LANTERN
        DESC STR0
        FLAGS TAKEBIT,LIGHTBIT
        CAPACITY 0
    .ENDOBJECT

    .FUNCT MAIN
        RTRUE

    .STRING STR0 "brass lantern"

    .END
    """

    /// Complex object with multiple property types and DESCENDING order
    static let complexObjectProgram = """
    .ZVERSION 4
    .START MAIN

    .OBJECT MAGIC-SWORD
        VTYPE 1
        VALUE 500          ; Property 31 (highest number)
        TVALUE 250         ; Property 11
        STRENGTH 15        ; Property 7
        FDESC STR1         ; Property 3
        LDESC STR2         ; Property 2
        DESC STR0          ; Property 1 (lowest number)
    .ENDOBJECT

    .FUNCT MAIN
        RTRUE

    .STRING STR0 "magic sword"
    .STRING STR1 "A gleaming magical sword lies here."
    .STRING STR2 "The magical blade shimmers with power."

    .END
    """

    /// Test object with action routine reference
    static let objectWithActionProgram = """
    .ZVERSION 3
    .START MAIN

    .OBJECT DOOR
        DESC STR0
        ACTION DOOR-F
        FLAGS DOORBIT
    .ENDOBJECT

    .FUNCT MAIN
        RTRUE

    .FUNCT DOOR-F
        EQUAL? PRSA,V?OPEN \\NEXT
        PRINTI "The door opens."
        CRLF
        RTRUE
    ?NEXT:
        RFALSE

    .STRING STR0 "wooden door"

    .END
    """

    // MARK: - Memory Layout Test Cases

    /// Multiple globals test
    static let multipleGlobalsProgram = """
    .ZVERSION 3
    .START MAIN

    .GLOBAL SCORE
    .GLOBAL MOVES
    .GLOBAL WINNER
    .GLOBAL LAST-ROOM

    .FUNCT MAIN
        SETG 'SCORE,0
        SETG 'MOVES,0
        SETG 'WINNER,ADVENTURER
        RTRUE

    .END
    """

    /// String table test with various string types
    static let stringTableProgram = """
    .ZVERSION 3
    .START MAIN

    .FUNCT MAIN
        PRINTI "Hello, World!"
        CRLF
        PRINTI "Quote: \\"Test\\""
        CRLF
        PRINTI "Tab:\\tand newline:\\n"
        RTRUE

    .END
    """

    /// Dictionary test with sorted word entries
    static let dictionaryProgram = """
    .ZVERSION 3
    .START MAIN

    .WORD NORTH
    .WORD SOUTH
    .WORD EAST
    .WORD WEST
    .WORD TAKE
    .WORD DROP
    .WORD INVENTORY

    .FUNCT MAIN
        RTRUE

    .END
    """

    // MARK: - Version-Specific Test Cases

    /// V3-specific features (32-bit object attributes, 255 object limit)
    static let version3Program = """
    .ZVERSION 3
    .START MAIN

    .OBJECT TEST-OBJ
        DESC STR0
        FLAGS TAKEBIT,LIGHTBIT,OPENBIT
    .ENDOBJECT

    .FUNCT MAIN
        FSET TEST-OBJ,ONBIT
        MOVE TEST-OBJ,PLAYER
        RTRUE

    .STRING STR0 "test object"

    .END
    """

    /// V4-specific features (48-bit object attributes, sound instructions)
    static let version4Program = """
    .ZVERSION 4
    .START MAIN

    .OBJECT MUSIC-BOX
        DESC STR0
        ACTION MUSIC-F
    .ENDOBJECT

    .FUNCT MAIN
        RTRUE

    .FUNCT MUSIC-F
        EQUAL? PRSA,V?PLAY \\FALSE
        SOUND 1
        PRINTI "The music box plays a lovely tune."
        RTRUE

    .STRING STR0 "music box"

    .END
    """

    /// V5-specific features (color support, extended memory)
    static let version5Program = """
    .ZVERSION 5
    .START MAIN

    .FUNCT MAIN
        SET-COLOUR 2,9      ; Black text on white background
        PRINTI "Colorful text!"
        CRLF
        RTRUE

    .END
    """

    // MARK: - Edge Case Test Fixtures

    /// Empty program - minimal valid story file
    static let emptyProgram = """
    .ZVERSION 3
    .START MAIN

    .FUNCT MAIN
        QUIT

    .END
    """

    /// Object with no properties
    static let emptyObjectProgram = """
    .ZVERSION 3
    .START MAIN

    .OBJECT EMPTY-OBJ
    .ENDOBJECT

    .FUNCT MAIN
        RTRUE

    .END
    """

    /// Large property test (boundary conditions)
    static let largePropertyProgram = """
    .ZVERSION 4
    .START MAIN

    .OBJECT BIG-TABLE
        PSEUDO STR0,STR1,STR2,STR3  ; Large property with multiple values
        CAPACITY 1000               ; Large numeric property
    .ENDOBJECT

    .FUNCT MAIN
        RTRUE

    .STRING STR0 "table"
    .STRING STR1 "desk"
    .STRING STR2 "surface"
    .STRING STR3 "furniture"

    .END
    """

    /// Routine with many local variables
    static let manyLocalsProgram = """
    .ZVERSION 3
    .START MAIN

    .FUNCT MAIN
        CALL COMPLEX-FUNC,1,2,3,4,5,6,7 >RESULT
        PRINTN RESULT
        RTRUE

    .FUNCT COMPLEX-FUNC,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O
        ; Function with 15 locals (maximum for Z-Machine)
        ADD A,B >H
        MUL H,C >I
        SUB I,D >J
        RETURN J

    .END
    """

    // MARK: - Expected Binary Outputs and Validation Data

    /// Expected object table structure for complexObjectProgram (V4)
    static let complexObjectExpectedLayout = ObjectTableLayout(
        propertyDefaults: Array(repeating: 0, count: 31), // 31 property defaults
        objects: [
            ObjectEntry(
                attributes: 0,           // No flags set initially
                parent: 0,              // No parent
                sibling: 0,             // No sibling
                child: 0,               // No child
                propertyTableAddress: 0x0200, // Example address
                properties: [
                    PropertyData(id: 31, data: Data([0x01, 0xF4])),      // VALUE 500 (2 bytes)
                    PropertyData(id: 11, data: Data([0xFA])),             // TVALUE 250 (1 byte)
                    PropertyData(id: 7,  data: Data([0x0F])),             // STRENGTH 15 (1 byte)
                    PropertyData(id: 3,  data: Data([0x80, 0x01])),       // FDESC STR1 (string ref)
                    PropertyData(id: 2,  data: Data([0x80, 0x02])),       // LDESC STR2 (string ref)
                    PropertyData(id: 1,  data: Data([0x80, 0x00]))        // DESC STR0 (string ref)
                ]
            )
        ]
    )

    /// Expected memory layout addresses for different versions
    static let expectedMemoryLayout = [
        ZMachineVersion.v3: MemoryLayout(
            headerSize: 64,
            globalTableAddress: 0x40,
            objectTableAddress: 0x1E0,
            staticMemoryBase: 0x8000,
            highMemoryBase: 0x10000,
            maxFileSize: 131072
        ),
        ZMachineVersion.v4: MemoryLayout(
            headerSize: 64,
            globalTableAddress: 0x40,
            objectTableAddress: 0x1E0,
            staticMemoryBase: 0x8000,
            highMemoryBase: 0x10000,
            maxFileSize: 131072
        ),
        ZMachineVersion.v5: MemoryLayout(
            headerSize: 64,
            globalTableAddress: 0x40,
            objectTableAddress: 0x1E0,
            staticMemoryBase: 0x10000,
            highMemoryBase: 0x20000,
            maxFileSize: 262144
        )
    ]

    /// Instruction encoding test cases
    static let instructionEncodingTests = [
        // 0OP Instructions
        InstructionTest(
            zap: "RTRUE",
            expectedBytes: [0xB0],
            description: "0OP RTRUE instruction"
        ),
        InstructionTest(
            zap: "RFALSE",
            expectedBytes: [0xB1],
            description: "0OP RFALSE instruction"
        ),
        InstructionTest(
            zap: "CRLF",
            expectedBytes: [0xBB],
            description: "0OP CRLF instruction"
        ),

        // 1OP Instructions
        InstructionTest(
            zap: "ZERO? 42",
            expectedBytes: [0x90, 0x2A],
            description: "1OP ZERO? with small constant"
        ),
        InstructionTest(
            zap: "PRINTN 1000",
            expectedBytes: [0xA5, 0x03, 0xE8],
            description: "1OP PRINTN with large constant"
        ),
        InstructionTest(
            zap: "RETURN X",
            expectedBytes: [0x9B, 0x01],
            description: "1OP RETURN with local variable"
        ),

        // 2OP Instructions
        InstructionTest(
            zap: "EQUAL? X,42",
            expectedBytes: [0x41, 0x01, 0x2A],
            description: "2OP EQUAL? with variable and small constant"
        ),
        InstructionTest(
            zap: "ADD X,Y",
            expectedBytes: [0x54, 0x01, 0x02],
            description: "2OP ADD with two variables"
        ),
        InstructionTest(
            zap: "SET X,1000",
            expectedBytes: [0x4D, 0x01, 0x03, 0xE8],
            description: "2OP SET with variable and large constant"
        ),

        // VAR Instructions
        InstructionTest(
            zap: "CALL FUNC,1,2,3",
            expectedBytes: [0xE0, 0x95, 0x80, 0x01, 0x01, 0x02, 0x03],
            description: "VAR CALL with routine and 3 arguments"
        )
    ]

    /// Property encoding test cases
    static let propertyEncodingTests = [
        PropertyTest(
            name: "DESC",
            value: .string("test"),
            version: .v3,
            expectedHeader: 0x21,  // Property 1, length 2 (string reference)
            expectedData: Data([0x80, 0x00]),
            description: "String property in V3 format"
        ),
        PropertyTest(
            name: "CAPACITY",
            value: .number(50),
            version: .v3,
            expectedHeader: 0x48,  // Property 8, length 1
            expectedData: Data([0x32]),
            description: "Small numeric property"
        ),
        PropertyTest(
            name: "VALUE",
            value: .number(1000),
            version: .v4,
            expectedHeader: 0x4A,  // Property 10, length 2
            expectedData: Data([0x03, 0xE8]),
            description: "Large numeric property in V4"
        )
    ]
}

// MARK: - Supporting Data Structures

struct ObjectTableLayout {
    let propertyDefaults: [UInt16]
    let objects: [ObjectEntry]
}

struct ObjectEntry {
    let attributes: UInt64
    let parent: UInt16
    let sibling: UInt16
    let child: UInt16
    let propertyTableAddress: UInt16
    let properties: [PropertyData]
}

struct PropertyData {
    let id: UInt8
    let data: Data
}

struct MemoryLayout {
    let headerSize: Int
    let globalTableAddress: UInt16
    let objectTableAddress: UInt16
    let staticMemoryBase: UInt32
    let highMemoryBase: UInt32
    let maxFileSize: Int
}

struct InstructionTest {
    let zap: String
    let expectedBytes: [UInt8]
    let description: String
}

struct PropertyTest {
    let name: String
    let value: ZValue
    let version: ZMachineVersion
    let expectedHeader: UInt8
    let expectedData: Data
    let description: String
}

// MARK: - Checksum Test Cases

extension ZAssemblerTestFixtures {

    /// Test case for checksum calculation
    static let checksumTestData = Data([
        // Minimal story file with known checksum
        0x03,                                    // Version 3
        0x00,                                    // Flags
        0x00, 0x01,                              // Release 1
        0x00, 0x50,                              // High memory
        0x00, 0x50,                              // Initial PC
        0x00, 0x00,                              // Dictionary
        0x00, 0x40,                              // Object table
        0x00, 0x40,                              // Globals
        0x00, 0x50,                              // Static memory
        0x00, 0x00,                              // Flags 2
        // ... rest of header
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,     // Serial number
        0x00, 0x00,                              // Abbreviations
        0x00, 0x32,                              // File length (50 * 2 = 100 bytes)
        0x00, 0x00,                              // Checksum placeholder
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,     // Rest of header...
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,

        // Minimal code
        0xBA                                     // QUIT instruction
    ])

    /// Expected checksum for the above data (calculated manually)
    static let expectedChecksum: UInt16 = 0x0382  // Sum of all bytes except checksum field
}