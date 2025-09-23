import Testing
@testable import ZEngine

@Suite("Shared Data Structure Tests")
struct DataStructureTests {

    @Suite("ZValue Tests")
    struct ZValueTests {

        @Test("ZValue truth evaluation", arguments: [
            (ZValue.null, false),
            (ZValue.number(0), false),
            (ZValue.number(1), true),
            (ZValue.number(-1), true),
            (ZValue.string(""), true),
            (ZValue.string("test"), true),
            (ZValue.atom("TEST"), true),
            (ZValue.object(ObjectID(1)), true),
            (ZValue.routine(RoutineID(1)), true)
        ])
        func zvalueTruthEvaluation(value: ZValue, expectedTruth: Bool) {
            #expect(value.isTrue == expectedTruth)
        }

        @Test("ZValue type conversion", arguments: [
            (ZValue.number(42), 42, nil, nil),
            (ZValue.string("hello"), nil, "hello", nil),
            (ZValue.atom("ATOM"), nil, nil, "ATOM"),
            (ZValue.null, nil, nil, nil)
        ])
        func zvalueTypeConversion(value: ZValue, expectedNumber: Int16?, expectedString: String?, expectedAtom: String?) {
            #expect(value.asNumber == expectedNumber)
            #expect(value.asString == expectedString)
            #expect(value.asAtom == expectedAtom)
        }
    }

    @Suite("Identifier Tests")
    struct IdentifierTests {

        @Test("ObjectID creation and comparison")
        func objectIdCreation() {
            let obj1 = ObjectID(42)
            let obj2 = ObjectID(42)
            let obj3 = ObjectID(24)

            #expect(obj1 == obj2)
            #expect(obj1 != obj3)
            #expect(obj1.id == 42)
            #expect(ObjectID.none.id == 0)
        }

        @Test("PropertyID validation", arguments: [
            (1, true),
            (15, true),
            (31, true),
            (32, false),
            (64, false),
            (255, false)
        ])
        func propertyIdValidation(id: Int, expectedStandard: Bool) {
            let prop = PropertyID(id)
            #expect(prop.isStandard == expectedStandard)
        }

        @Test("Direction opposites", arguments: [
            (Direction.north, Direction.south),
            (Direction.east, Direction.west),
            (Direction.northeast, Direction.southwest),
            (Direction.up, Direction.down),
            (Direction.in, Direction.out)
        ])
        func directionOpposites(direction: Direction, expectedOpposite: Direction) {
            #expect(direction.opposite == expectedOpposite)
        }
    }

    @Suite("Z-Machine Version Tests")
    struct ZMachineVersionTests {

        @Test("Memory limits by version", arguments: [
            (ZMachineVersion.v3, 128 * 1024),
            (ZMachineVersion.v4, 128 * 1024),
            (ZMachineVersion.v5, 256 * 1024),
            (ZMachineVersion.v8, 256 * 1024)
        ])
        func memoryLimitsByVersion(version: ZMachineVersion, expectedLimit: Int) {
            #expect(version.maxMemory == expectedLimit)
        }

        @Test("Feature availability by version", arguments: [
            (ZMachineVersion.v3, false, false, false, false, false),
            (ZMachineVersion.v4, true, false, false, false, false),
            (ZMachineVersion.v5, true, true, false, true, true),
            (ZMachineVersion.v6, true, true, true, true, true),
            (ZMachineVersion.v8, true, true, false, true, true)
        ])
        func featureAvailabilityByVersion(
            version: ZMachineVersion,
            hasSound: Bool,
            hasColor: Bool,
            hasGraphics: Bool,
            hasUnicode: Bool,
            hasExtendedInstructions: Bool
        ) {
            #expect(version.hasSound == hasSound)
            #expect(version.hasColor == hasColor)
            #expect(version.hasGraphics == hasGraphics)
            #expect(version.hasUnicode == hasUnicode)
            #expect(version.hasExtendedInstructions == hasExtendedInstructions)
        }
    }

    @Suite("ZAddress Tests")
    struct ZAddressTests {

        @Test("Address unpacking", arguments: [
            (ZMachineVersion.v3, 100, true, 200),
            (ZMachineVersion.v4, 100, true, 400),
            (ZMachineVersion.v5, 100, true, 400),
            (ZMachineVersion.v8, 100, true, 800),
            (ZMachineVersion.v5, 400, false, 400)
        ])
        func addressUnpacking(version: ZMachineVersion, address: UInt32, packed: Bool, expectedUnpacked: UInt32) {
            let addr = ZAddress(address, packed: packed)
            #expect(addr.unpacked(for: version) == expectedUnpacked)
        }
    }
}

@Suite("Utility Function Tests")
struct UtilityTests {

    @Suite("ZUtils Tests")
    struct ZUtilsTests {

        @Test("Valid identifier creation", arguments: [
            ("hello world", "HELLO-WORLD"),
            ("test_var", "TEST-VAR"),
            ("123test", "Z-123TEST"),
            ("-test", "Z--TEST"),
            ("ROUTINE", "ROUTINE-1"),
            ("", "UNNAMED")
        ])
        func validIdentifierCreation(input: String, expected: String) {
            let result = ZUtils.makeValidIdentifier(input)
            #expect(result == expected)
        }

        @Test("Address packing/unpacking", arguments: [
            (ZMachineVersion.v3, 200, 100),
            (ZMachineVersion.v4, 400, 100),
            (ZMachineVersion.v5, 400, 100),
            (ZMachineVersion.v8, 800, 100)
        ])
        func addressPackingUnpacking(version: ZMachineVersion, address: UInt32, expectedPacked: UInt16) {
            let packed = ZUtils.packAddress(address, version: version)
            #expect(packed == expectedPacked)

            let unpacked = ZUtils.unpackAddress(packed, version: version)
            #expect(unpacked == address)
        }

        @Test("Value range checks", arguments: [
            (127, true, true, true),
            (128, false, true, true),
            (255, false, true, true),
            (256, false, false, true),
            (32767, false, false, true),
            (32768, false, false, false),
            (-1, true, false, true),
            (-128, true, false, true),
            (-129, false, false, true),
            (-32768, false, false, true),
            (-32769, false, false, false)
        ])
        func valueRangeChecks(value: Int, fitsByte: Bool, fitsUnsignedByte: Bool, fitsWord: Bool) {
            #expect(ZUtils.fitsInByte(value) == fitsByte)
            #expect(ZUtils.fitsInUnsignedByte(value) == fitsUnsignedByte)
            #expect(ZUtils.fitsInWord(value) == fitsWord)
        }
    }

    @Suite("Constants Tests")
    struct ConstantsTests {

        @Test("Standard property validation")
        func standardPropertyValidation() {
            #expect(ZConstants.StandardProperty.parent.rawValue == 1)
            #expect(ZConstants.StandardProperty.name.rawValue == 4)
            #expect(ZConstants.StandardProperty.northwest.rawValue == 31)
        }

        @Test("File extension mapping")
        func fileExtensionMapping() {
            #expect(ZConstants.fileExtensions[3] == ".z3")
            #expect(ZConstants.fileExtensions[5] == ".z5")
            #expect(ZConstants.fileExtensions[8] == ".z8")
        }

        @Test("Reserved word validation", arguments: [
            "ROUTINE", "OBJECT", "ROOM", "GLOBAL", "CONSTANT",
            "IF", "COND", "AND", "OR", "NOT", "PROG"
        ])
        func reservedWordValidation(word: String) {
            #expect(ZConstants.reservedWords.contains(word))
        }
    }
}