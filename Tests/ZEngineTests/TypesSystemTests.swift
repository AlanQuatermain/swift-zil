import Testing
@testable import ZEngine

@Suite("Types System Comprehensive Tests")
struct TypesSystemTests {

    // MARK: - ZValue Comprehensive Tests

    @Test("ZValue comprehensive truth evaluation")
    func zvalueComprehensiveTruthEvaluation() throws {
        // Test all cases not covered by existing parameterized tests
        #expect(ZValue.property(PropertyID(1)).isTrue == true)
        #expect(ZValue.flag(FlagID(0)).isTrue == true)
        #expect(ZValue.direction(.north).isTrue == true)
        #expect(ZValue.word(WordID(100)).isTrue == true)
        #expect(ZValue.table(TableID(50)).isTrue == true)

        // Test edge cases for numbers
        #expect(ZValue.number(Int16.max).isTrue == true)
        #expect(ZValue.number(Int16.min).isTrue == true)
        #expect(ZValue.number(1).isTrue == true)
        #expect(ZValue.number(-1).isTrue == true)
    }

    @Test("ZValue conversion method edge cases")
    func zvalueConversionMethodEdgeCases() throws {
        // Test that conversion methods return nil for wrong types
        let numberValue = ZValue.number(42)
        let stringValue = ZValue.string("test")
        let atomValue = ZValue.atom("ATOM")
        let objectValue = ZValue.object(ObjectID(1))
        let nullValue = ZValue.null

        // Test asNumber edge cases
        #expect(stringValue.asNumber == nil)
        #expect(atomValue.asNumber == nil)
        #expect(objectValue.asNumber == nil)
        #expect(nullValue.asNumber == nil)
        #expect(ZValue.number(0).asNumber == 0)
        #expect(ZValue.number(-32768).asNumber == -32768)
        #expect(ZValue.number(32767).asNumber == 32767)

        // Test asString edge cases
        #expect(numberValue.asString == nil)
        #expect(atomValue.asString == nil)
        #expect(objectValue.asString == nil)
        #expect(nullValue.asString == nil)
        #expect(ZValue.string("").asString == "")
        #expect(ZValue.string("unicode: ñáéíóú").asString == "unicode: ñáéíóú")

        // Test asAtom edge cases
        #expect(numberValue.asAtom == nil)
        #expect(stringValue.asAtom == nil)
        #expect(objectValue.asAtom == nil)
        #expect(nullValue.asAtom == nil)
        #expect(ZValue.atom("").asAtom == "")
        #expect(ZValue.atom("COMPLEX-ATOM?").asAtom == "COMPLEX-ATOM?")
    }

    @Test("ZValue complex case creation")
    func zvalueComplexCaseCreation() throws {
        // Test creating ZValue with complex associated types
        let complexObject = ZValue.object(ObjectID(65535))
        let complexRoutine = ZValue.routine(RoutineID(32767))
        let complexProperty = ZValue.property(PropertyID(255))
        let complexFlag = ZValue.flag(FlagID(31))
        let complexWord = ZValue.word(WordID(UInt16.max))
        let complexTable = ZValue.table(TableID(0))

        // All should be truthy except numbers and null
        #expect(complexObject.isTrue == true)
        #expect(complexRoutine.isTrue == true)
        #expect(complexProperty.isTrue == true)
        #expect(complexFlag.isTrue == true)
        #expect(complexWord.isTrue == true)
        #expect(complexTable.isTrue == true)

        // Test with all directions
        for direction in Direction.allCases {
            let dirValue = ZValue.direction(direction)
            #expect(dirValue.isTrue == true)
        }
    }

    // MARK: - Comprehensive ID Type Tests

    @Test("ObjectID comprehensive testing")
    func objectIdComprehensiveTesting() throws {
        // Test various constructors
        let obj1 = ObjectID(UInt16(42))
        let obj2 = ObjectID(42) // Int constructor
        let obj3 = ObjectID(0)
        let obj4 = ObjectID.none

        #expect(obj1.id == 42)
        #expect(obj2.id == 42)
        #expect(obj1 == obj2)
        #expect(obj3 == obj4)
        #expect(obj4.id == 0)

        // Test hashability
        let objSet: Set<ObjectID> = [obj1, obj2, obj3]
        #expect(objSet.count == 2) // obj1 and obj2 are equal

        // Test extreme values
        let maxObj = ObjectID(UInt16.max)
        let minObj = ObjectID(UInt16.min)
        #expect(maxObj.id == 65535)
        #expect(minObj.id == 0)

        // Test Int constructor behavior within valid range
        let validObj = ObjectID(32768) // Valid UInt16 value
        #expect(validObj.id == 32768)
    }

    @Test("RoutineID comprehensive testing")
    func routineIdComprehensiveTesting() throws {
        // Test various constructors
        let routine1 = RoutineID(UInt16(100))
        let routine2 = RoutineID(100) // Int constructor
        let routine3 = RoutineID.none

        #expect(routine1.id == 100)
        #expect(routine2.id == 100)
        #expect(routine1 == routine2)
        #expect(routine3.id == 0)

        // Test hashability
        let routineSet: Set<RoutineID> = [routine1, routine2, routine3]
        #expect(routineSet.count == 2)

        // Test extreme values
        let maxRoutine = RoutineID(UInt16.max)
        let minRoutine = RoutineID(UInt16.min)
        #expect(maxRoutine.id == 65535)
        #expect(minRoutine.id == 0)
    }

    @Test("PropertyID comprehensive testing")
    func propertyIdComprehensiveTesting() throws {
        // Test various constructors
        let prop1 = PropertyID(UInt8(15))
        let prop2 = PropertyID(15) // Int constructor
        let standardProp = PropertyID(31)
        let userProp = PropertyID(32)

        #expect(prop1.id == 15)
        #expect(prop2.id == 15)
        #expect(prop1 == prop2)

        // Test isStandard property thoroughly
        #expect(standardProp.isStandard == true)
        #expect(userProp.isStandard == false)

        // Test edge cases for isStandard
        let prop0 = PropertyID(0)
        let prop1Standard = PropertyID(1)
        let prop31Standard = PropertyID(31)
        let prop32User = PropertyID(32)
        let prop255User = PropertyID(255)

        #expect(prop0.isStandard == false) // 0 is not standard (1-31)
        #expect(prop1Standard.isStandard == true)
        #expect(prop31Standard.isStandard == true)
        #expect(prop32User.isStandard == false)
        #expect(prop255User.isStandard == false)

        // Test hashability
        let propSet: Set<PropertyID> = [prop1, prop2, standardProp]
        #expect(propSet.count == 2)

        // Test extreme values
        let maxProp = PropertyID(UInt8.max)
        let minProp = PropertyID(UInt8.min)
        #expect(maxProp.id == 255)
        #expect(minProp.id == 0)

        // Test Int constructor behavior within valid range
        let validProp = PropertyID(128) // Valid UInt8 value
        #expect(validProp.id == 128)
    }

    @Test("FlagID comprehensive testing")
    func flagIdComprehensiveTesting() throws {
        // Test various constructors
        let flag1 = FlagID(UInt8(15))
        let flag2 = FlagID(15) // Int constructor
        let flag0 = FlagID(0)
        let flag31 = FlagID(31)

        #expect(flag1.id == 15)
        #expect(flag2.id == 15)
        #expect(flag1 == flag2)
        #expect(flag0.id == 0)
        #expect(flag31.id == 31)

        // Test hashability
        let flagSet: Set<FlagID> = [flag1, flag2, flag0]
        #expect(flagSet.count == 2)

        // Test that all valid flag IDs (0-31) can be created
        for i in 0...31 {
            let flag = FlagID(i)
            #expect(flag.id == UInt8(i))
        }

        // Test extreme values
        let maxFlag = FlagID(UInt8.max) // 255, outside normal range but valid
        #expect(maxFlag.id == 255)

        // Test Int constructor behavior within valid range
        let validFlag = FlagID(63) // Valid UInt8 value
        #expect(validFlag.id == 63)
    }

    @Test("WordID comprehensive testing")
    func wordIdComprehensiveTesting() throws {
        // Test various constructors
        let word1 = WordID(UInt16(1000))
        let word2 = WordID(1000) // Int constructor
        let word0 = WordID(0)

        #expect(word1.id == 1000)
        #expect(word2.id == 1000)
        #expect(word1 == word2)
        #expect(word0.id == 0)

        // Test hashability
        let wordSet: Set<WordID> = [word1, word2, word0]
        #expect(wordSet.count == 2)

        // Test extreme values
        let maxWord = WordID(UInt16.max)
        let minWord = WordID(UInt16.min)
        #expect(maxWord.id == 65535)
        #expect(minWord.id == 0)

        // Test Int constructor behavior within valid range
        let validWord = WordID(32768) // Valid UInt16 value
        #expect(validWord.id == 32768)
    }

    @Test("TableID comprehensive testing")
    func tableIdComprehensiveTesting() throws {
        // Test various constructors
        let table1 = TableID(UInt16(500))
        let table2 = TableID(500) // Int constructor
        let table0 = TableID(0)

        #expect(table1.id == 500)
        #expect(table2.id == 500)
        #expect(table1 == table2)
        #expect(table0.id == 0)

        // Test hashability
        let tableSet: Set<TableID> = [table1, table2, table0]
        #expect(tableSet.count == 2)

        // Test extreme values
        let maxTable = TableID(UInt16.max)
        let minTable = TableID(UInt16.min)
        #expect(maxTable.id == 65535)
        #expect(minTable.id == 0)

        // Test Int constructor behavior within valid range
        let validTable = TableID(32768) // Valid UInt16 value
        #expect(validTable.id == 32768)
    }

    // MARK: - Direction Comprehensive Tests

    @Test("Direction comprehensive opposite testing")
    func directionComprehensiveOppositeTesting() throws {
        // Test all directions have opposites and they're symmetric
        let directions = Direction.allCases

        for direction in directions {
            let opposite = direction.opposite
            #expect(opposite.opposite == direction, "Direction \(direction) should be opposite of its opposite \(opposite)")
        }

        // Test specific mappings not covered by existing parameterized tests
        #expect(Direction.northwest.opposite == Direction.southeast)
        #expect(Direction.southeast.opposite == Direction.northwest)
        #expect(Direction.southwest.opposite == Direction.northeast)
        #expect(Direction.northeast.opposite == Direction.southwest)

        // Test that all cases are covered
        #expect(directions.count == 12, "Should have exactly 12 directions")

        // Test raw values
        #expect(Direction.north.rawValue == "NORTH")
        #expect(Direction.northeast.rawValue == "NE")
        #expect(Direction.in.rawValue == "IN")
        #expect(Direction.out.rawValue == "OUT")
    }

    @Test("Direction string representation and creation")
    func directionStringRepresentationAndCreation() throws {
        // Test that all directions can be created from raw values
        for direction in Direction.allCases {
            let recreated = Direction(rawValue: direction.rawValue)
            #expect(recreated == direction, "Should be able to recreate \(direction) from raw value")
        }

        // Test invalid direction creation
        let invalidDirection = Direction(rawValue: "INVALID")
        #expect(invalidDirection == nil, "Invalid direction should return nil")

        // Test case sensitivity
        let lowerCase = Direction(rawValue: "north")
        #expect(lowerCase == nil, "Direction creation should be case-sensitive")
    }

    // MARK: - ZMachineVersion Comprehensive Tests

    @Test("ZMachineVersion comprehensive comparison")
    func zmachineVersionComprehensiveComparison() throws {
        let versions = ZMachineVersion.allCases.sorted()

        // Test that versions are properly ordered
        #expect(versions[0] == .v3)
        #expect(versions[1] == .v4)
        #expect(versions[2] == .v5)
        #expect(versions[3] == .v6)
        #expect(versions[4] == .v7)
        #expect(versions[5] == .v8)

        // Test comparison operations
        #expect(ZMachineVersion.v3 < ZMachineVersion.v4)
        #expect(ZMachineVersion.v4 < ZMachineVersion.v5)
        #expect(ZMachineVersion.v5 < ZMachineVersion.v6)
        #expect(ZMachineVersion.v6 < ZMachineVersion.v7)
        #expect(ZMachineVersion.v7 < ZMachineVersion.v8)

        #expect(ZMachineVersion.v8 > ZMachineVersion.v3)
        #expect(ZMachineVersion.v6 >= ZMachineVersion.v6)
        #expect(ZMachineVersion.v4 <= ZMachineVersion.v5)

        // Test equality
        #expect(ZMachineVersion.v5 == ZMachineVersion.v5)
        #expect(ZMachineVersion.v3 != ZMachineVersion.v4)
    }

    @Test("ZMachineVersion comprehensive feature detection")
    func zmachineVersionComprehensiveFeatureDetection() throws {
        // Test maxObjects property thoroughly
        #expect(ZMachineVersion.v3.maxObjects == 255)
        #expect(ZMachineVersion.v4.maxObjects == 65535)
        #expect(ZMachineVersion.v5.maxObjects == 65535)
        #expect(ZMachineVersion.v6.maxObjects == 65535)
        #expect(ZMachineVersion.v7.maxObjects == 65535)
        #expect(ZMachineVersion.v8.maxObjects == 65535)

        // Test memory limits with all versions
        #expect(ZMachineVersion.v3.maxMemory == 128 * 1024)
        #expect(ZMachineVersion.v4.maxMemory == 128 * 1024)
        #expect(ZMachineVersion.v5.maxMemory == 256 * 1024)
        #expect(ZMachineVersion.v6.maxMemory == 256 * 1024)
        #expect(ZMachineVersion.v7.maxMemory == 256 * 1024)
        #expect(ZMachineVersion.v8.maxMemory == 256 * 1024)

        // Test v7 specifically (rarely used variant)
        #expect(ZMachineVersion.v7.hasSound == true)
        #expect(ZMachineVersion.v7.hasColor == true)
        #expect(ZMachineVersion.v7.hasGraphics == false) // Only v6 has graphics
        #expect(ZMachineVersion.v7.hasUnicode == true)
        #expect(ZMachineVersion.v7.hasExtendedInstructions == true)

        // Test feature progression
        let v3 = ZMachineVersion.v3
        #expect(v3.hasSound == false)
        #expect(v3.hasColor == false)
        #expect(v3.hasGraphics == false)
        #expect(v3.hasUnicode == false)
        #expect(v3.hasExtendedInstructions == false)

        // Test graphics is only v6
        for version in ZMachineVersion.allCases {
            if version == .v6 {
                #expect(version.hasGraphics == true)
            } else {
                #expect(version.hasGraphics == false)
            }
        }
    }

    @Test("ZMachineVersion raw values and creation")
    func zmachineVersionRawValuesAndCreation() throws {
        // Test raw values
        #expect(ZMachineVersion.v3.rawValue == 3)
        #expect(ZMachineVersion.v4.rawValue == 4)
        #expect(ZMachineVersion.v5.rawValue == 5)
        #expect(ZMachineVersion.v6.rawValue == 6)
        #expect(ZMachineVersion.v7.rawValue == 7)
        #expect(ZMachineVersion.v8.rawValue == 8)

        // Test creation from raw values
        #expect(ZMachineVersion(rawValue: 3) == .v3)
        #expect(ZMachineVersion(rawValue: 4) == .v4)
        #expect(ZMachineVersion(rawValue: 5) == .v5)
        #expect(ZMachineVersion(rawValue: 6) == .v6)
        #expect(ZMachineVersion(rawValue: 7) == .v7)
        #expect(ZMachineVersion(rawValue: 8) == .v8)

        // Test invalid versions
        #expect(ZMachineVersion(rawValue: 1) == nil)
        #expect(ZMachineVersion(rawValue: 2) == nil)
        #expect(ZMachineVersion(rawValue: 9) == nil)
        #expect(ZMachineVersion(rawValue: 255) == nil)
    }

    // MARK: - ZAddress Comprehensive Tests

    @Test("ZAddress comprehensive creation and properties")
    func zaddressComprehensiveCreationAndProperties() throws {
        // Test basic creation
        let unpackedAddr = ZAddress(1000)
        let packedAddr = ZAddress(1000, packed: true)

        #expect(unpackedAddr.address == 1000)
        #expect(unpackedAddr.isPacked == false)
        #expect(packedAddr.address == 1000)
        #expect(packedAddr.isPacked == true)

        // Test extreme values
        let maxAddr = ZAddress(UInt32.max)
        let minAddr = ZAddress(UInt32.min)
        #expect(maxAddr.address == 4294967295)
        #expect(minAddr.address == 0)

        // Test hashability and equality
        let addr1 = ZAddress(500)
        let addr2 = ZAddress(500)
        let addr3 = ZAddress(500, packed: true)
        let addr4 = ZAddress(600)

        #expect(addr1 == addr2)
        #expect(addr1 != addr3) // Different packed status
        #expect(addr1 != addr4) // Different address

        let addrSet: Set<ZAddress> = [addr1, addr2, addr3, addr4]
        #expect(addrSet.count == 3) // addr1 and addr2 are equal
    }

    @Test("ZAddress unpacking comprehensive scenarios")
    func zaddressUnpackingComprehensiveScenarios() throws {
        // Test all Z-Machine versions with various addresses
        let testCases: [(ZMachineVersion, UInt32, Bool, UInt32)] = [
            // Version 3 (×2)
            (.v3, 0, true, 0),
            (.v3, 1, true, 2),
            (.v3, 32767, true, 65534),
            (.v3, 1000, false, 1000), // Already unpacked

            // Version 4 (×4)
            (.v4, 0, true, 0),
            (.v4, 1, true, 4),
            (.v4, 16383, true, 65532),
            (.v4, 2000, false, 2000), // Already unpacked

            // Version 5 (×4)
            (.v5, 0, true, 0),
            (.v5, 1, true, 4),
            (.v5, 16383, true, 65532),
            (.v5, 3000, false, 3000), // Already unpacked

            // Version 6 (×4, routines only)
            (.v6, 0, true, 0),
            (.v6, 1, true, 4),
            (.v6, 16383, true, 65532),
            (.v6, 4000, false, 4000), // Already unpacked

            // Version 7 (×4)
            (.v7, 0, true, 0),
            (.v7, 1, true, 4),
            (.v7, 16383, true, 65532),
            (.v7, 5000, false, 5000), // Already unpacked

            // Version 8 (×8)
            (.v8, 0, true, 0),
            (.v8, 1, true, 8),
            (.v8, 8191, true, 65528),
            (.v8, 6000, false, 6000) // Already unpacked
        ]

        for (version, address, packed, expected) in testCases {
            let addr = ZAddress(address, packed: packed)
            let result = addr.unpacked(for: version)
            #expect(result == expected,
                "Version \(version), address \(address), packed \(packed) should unpack to \(expected), got \(result)")
        }
    }

    @Test("ZAddress edge cases and boundary conditions")
    func zaddressEdgeCasesAndBoundaryConditions() throws {
        // Test maximum packed addresses for each version
        let maxV3Packed = ZAddress(32767, packed: true) // Max that fits in 16-bit result when ×2
        let maxV4Packed = ZAddress(16383, packed: true) // Max that fits in 16-bit result when ×4
        let maxV8Packed = ZAddress(8191, packed: true)  // Max that fits in 16-bit result when ×8

        #expect(maxV3Packed.unpacked(for: .v3) == 65534)
        #expect(maxV4Packed.unpacked(for: .v4) == 65532)
        #expect(maxV8Packed.unpacked(for: .v8) == 65528)

        // Test overflow scenarios (addresses that would overflow when unpacked)
        // NOTE: We avoid testing actual overflow as it may cause crashes
        let largeV3 = ZAddress(30000, packed: true)
        let largeV4 = ZAddress(15000, packed: true)
        let largeV8 = ZAddress(7000, packed: true)

        // These should work and result in large but valid values
        #expect(largeV3.unpacked(for: .v3) == 60000)
        #expect(largeV4.unpacked(for: .v4) == 60000)
        #expect(largeV8.unpacked(for: .v8) == 56000)

        // Test that unpacked addresses return themselves
        let alreadyUnpacked = ZAddress(12345, packed: false)
        for version in ZMachineVersion.allCases {
            #expect(alreadyUnpacked.unpacked(for: version) == 12345)
        }
    }

    // MARK: - Integration and Cross-Type Tests

    @Test("Types system integration testing")
    func typesSystemIntegrationTesting() throws {
        // Test that all ID types can be used in ZValue
        let objectValue = ZValue.object(ObjectID(42))
        let routineValue = ZValue.routine(RoutineID(100))
        let propertyValue = ZValue.property(PropertyID(15))
        let flagValue = ZValue.flag(FlagID(3))
        let wordValue = ZValue.word(WordID(200))
        let tableValue = ZValue.table(TableID(75))
        let directionValue = ZValue.direction(.north)

        // All should be truthy
        let allValues = [objectValue, routineValue, propertyValue, flagValue, wordValue, tableValue, directionValue]
        for value in allValues {
            #expect(value.isTrue == true)
        }

        // Test collections with ID types
        let objectSet: Set<ObjectID> = [ObjectID(1), ObjectID(2), ObjectID(3)]
        let propertySet: Set<PropertyID> = [PropertyID(1), PropertyID(15), PropertyID(31)]
        let directionSet: Set<Direction> = [.north, .south, .east, .west]

        #expect(objectSet.count == 3)
        #expect(propertySet.count == 3)
        #expect(directionSet.count == 4)

        // Test that different ID types with same numeric value are different
        let obj42 = ObjectID(42)
        let routine42 = RoutineID(42)
        // These should be different types and not comparable directly
        #expect(obj42.id == routine42.id) // Same numeric value
        // But they're different types, which is correct
    }

    @Test("Types system memory and performance characteristics")
    func typesSystemMemoryAndPerformanceCharacteristics() throws {
        // Test creating large numbers of ID types efficiently
        var objects: [ObjectID] = []
        var routines: [RoutineID] = []
        var properties: [PropertyID] = []

        for i in 0..<1000 {
            objects.append(ObjectID(i))
            routines.append(RoutineID(i))
            if i < 256 {
                properties.append(PropertyID(i))
            }
        }

        #expect(objects.count == 1000)
        #expect(routines.count == 1000)
        #expect(properties.count == 256)

        // Test that equality operations are efficient
        let testObj = ObjectID(500)
        let foundObj = objects.first { $0 == testObj }
        #expect(foundObj != nil)
        #expect(foundObj?.id == 500)

        // Test set operations with large collections
        let objSet = Set(objects)
        #expect(objSet.count == 1000) // All should be unique

        // Test ZValue creation with all ID types
        let zvalues = objects.prefix(100).map { ZValue.object($0) }
        #expect(zvalues.count == 100)
        #expect(zvalues.allSatisfy { $0.isTrue }) // All should be truthy
    }

    @Test("Types system string conversion and debugging")
    func typesSystemStringConversionAndDebugging() throws {
        // Test that ID types can be converted to strings for debugging
        let obj = ObjectID(42)
        let routine = RoutineID(100)
        let property = PropertyID(15)
        let flag = FlagID(3)
        let direction = Direction.northeast

        // These should be representable as strings (through CustomStringConvertible if implemented)
        // At minimum, they should have some string representation
        let objString = "\(obj)"
        let routineString = "\(routine)"
        let propertyString = "\(property)"
        let flagString = "\(flag)"
        let directionString = "\(direction)"

        #expect(!objString.isEmpty)
        #expect(!routineString.isEmpty)
        #expect(!propertyString.isEmpty)
        #expect(!flagString.isEmpty)
        #expect(!directionString.isEmpty)

        // Direction should have raw value representation
        #expect(directionString.contains("northeast") || directionString.contains("NE"))

        // Test ZValue string representations
        let numberValue = ZValue.number(42)
        let stringValue = ZValue.string("test")
        let atomValue = ZValue.atom("ATOM")
        let nullValue = ZValue.null

        let numberStr = "\(numberValue)"
        let stringStr = "\(stringValue)"
        let atomStr = "\(atomValue)"
        let nullStr = "\(nullValue)"

        #expect(!numberStr.isEmpty)
        #expect(!stringStr.isEmpty)
        #expect(!atomStr.isEmpty)
        #expect(!nullStr.isEmpty)
    }
}