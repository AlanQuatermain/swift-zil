import Testing
import Foundation
@testable import ZEngine

@Suite("SourceLocation Tests")
struct SourceLocationTests {

    // MARK: - Basic SourceLocation Tests

    @Test("SourceLocation basic initialization")
    func sourceLocationBasicInitialization() throws {
        let location = ZEngine.SourceLocation(file: "test.zil", line: 42, column: 10)

        #expect(location.file == "test.zil")
        #expect(location.line == 42)
        #expect(location.column == 10)
        #expect(location.offset == nil)
    }

    @Test("SourceLocation initialization with offset")
    func sourceLocationInitializationWithOffset() throws {
        let location = ZEngine.SourceLocation(file: "test.zil", line: 15, column: 8, offset: 256)

        #expect(location.file == "test.zil")
        #expect(location.line == 15)
        #expect(location.column == 8)
        #expect(location.offset == 256)
    }

    @Test("SourceLocation initialization from URL")
    func sourceLocationInitializationFromURL() throws {
        let fileURL = URL(fileURLWithPath: "/path/to/source/game.zil")
        let location = ZEngine.SourceLocation(file: fileURL, line: 100, column: 25)

        #expect(location.file == "game.zil") // Should extract last path component
        #expect(location.line == 100)
        #expect(location.column == 25)
        #expect(location.offset == nil)
    }

    @Test("SourceLocation initialization from URL with offset")
    func sourceLocationInitializationFromURLWithOffset() throws {
        let fileURL = URL(fileURLWithPath: "/Users/developer/project/main.zil")
        let location = ZEngine.SourceLocation(file: fileURL, line: 75, column: 12, offset: 1024)

        #expect(location.file == "main.zil") // Should extract last path component
        #expect(location.line == 75)
        #expect(location.column == 12)
        #expect(location.offset == 1024)
    }

    @Test("SourceLocation static placeholders")
    func sourceLocationStaticPlaceholders() throws {
        // Test generated placeholder
        let generated = ZEngine.SourceLocation.generated
        #expect(generated.file == "<generated>")
        #expect(generated.line == 0)
        #expect(generated.column == 0)
        #expect(generated.offset == nil)

        // Test unknown placeholder
        let unknown = ZEngine.SourceLocation.unknown
        #expect(unknown.file == "<unknown>")
        #expect(unknown.line == 0)
        #expect(unknown.column == 0)
        #expect(unknown.offset == nil)

        // Test that static placeholders are distinct
        #expect(generated != unknown)
    }

    // MARK: - CustomStringConvertible Tests

    @Test("SourceLocation string description")
    func sourceLocationStringDescription() throws {
        let location1 = ZEngine.SourceLocation(file: "main.zil", line: 1, column: 1)
        #expect(location1.description == "main.zil:1:1")

        let location2 = ZEngine.SourceLocation(file: "game.zil", line: 42, column: 15)
        #expect(location2.description == "game.zil:42:15")

        let location3 = ZEngine.SourceLocation(file: "library.zil", line: 999, column: 80)
        #expect(location3.description == "library.zil:999:80")

        // Test with offset (should not affect description)
        let locationWithOffset = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 5, offset: 200)
        #expect(locationWithOffset.description == "test.zil:10:5")
    }

    @Test("SourceLocation special file names")
    func sourceLocationSpecialFileNames() throws {
        let generatedLocation = ZEngine.SourceLocation(file: "<generated>", line: 0, column: 0)
        #expect(generatedLocation.description == "<generated>:0:0")

        let unknownLocation = ZEngine.SourceLocation(file: "<unknown>", line: 0, column: 0)
        #expect(unknownLocation.description == "<unknown>:0:0")

        let emptyFileLocation = ZEngine.SourceLocation(file: "", line: 1, column: 1)
        #expect(emptyFileLocation.description == ":1:1")

        let spaceInFileName = ZEngine.SourceLocation(file: "my file.zil", line: 5, column: 10)
        #expect(spaceInFileName.description == "my file.zil:5:10")
    }

    // MARK: - Equatable Tests

    @Test("SourceLocation equality comparison")
    func sourceLocationEqualityComparison() throws {
        let location1 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 5)
        let location2 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 5)
        let location3 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 6) // Different column
        let location4 = ZEngine.SourceLocation(file: "test.zil", line: 11, column: 5) // Different line
        let location5 = ZEngine.SourceLocation(file: "other.zil", line: 10, column: 5) // Different file

        // Test equality
        #expect(location1 == location2)
        #expect(location2 == location1) // Symmetric

        // Test inequality
        #expect(location1 != location3)
        #expect(location1 != location4)
        #expect(location1 != location5)

        // Test reflexivity
        #expect(location1 == location1)
    }

    @Test("SourceLocation equality ignores offset")
    func sourceLocationEqualityIgnoresOffset() throws {
        let location1 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 5, offset: nil)
        let location2 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 5, offset: 100)
        let location3 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 5, offset: 200)

        // Equality should ignore offset (based on the implementation)
        #expect(location1 == location2)
        #expect(location2 == location3)
        #expect(location1 == location3)
    }

    // MARK: - Comparable Tests

    @Test("SourceLocation file comparison")
    func sourceLocationFileComparison() throws {
        let locationA = ZEngine.SourceLocation(file: "a.zil", line: 10, column: 10)
        let locationB = ZEngine.SourceLocation(file: "b.zil", line: 5, column: 5)
        let locationZ = ZEngine.SourceLocation(file: "z.zil", line: 1, column: 1)

        #expect(locationA < locationB)
        #expect(locationB < locationZ)
        #expect(locationA < locationZ)

        // Test that file comparison takes precedence over line/column
        let earlierInB = ZEngine.SourceLocation(file: "b.zil", line: 1, column: 1)
        let laterInA = ZEngine.SourceLocation(file: "a.zil", line: 999, column: 999)
        #expect(laterInA < earlierInB) // File "a" comes before "b"
    }

    @Test("SourceLocation line comparison within same file")
    func sourceLocationLineComparisonWithinSameFile() throws {
        let location1 = ZEngine.SourceLocation(file: "test.zil", line: 1, column: 99)
        let location2 = ZEngine.SourceLocation(file: "test.zil", line: 2, column: 1)
        let location10 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 1)

        #expect(location1 < location2)
        #expect(location2 < location10)
        #expect(location1 < location10)

        // Test that line comparison takes precedence over column
        let line5Col99 = ZEngine.SourceLocation(file: "test.zil", line: 5, column: 99)
        let line6Col1 = ZEngine.SourceLocation(file: "test.zil", line: 6, column: 1)
        #expect(line5Col99 < line6Col1)
    }

    @Test("SourceLocation column comparison within same line")
    func sourceLocationColumnComparisonWithinSameLine() throws {
        let col1 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 1)
        let col5 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 5)
        let col10 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 10)
        let col99 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 99)

        #expect(col1 < col5)
        #expect(col5 < col10)
        #expect(col10 < col99)
        #expect(col1 < col99)

        // Test edge cases
        let col0 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 0)
        #expect(col0 < col1)
    }

    @Test("SourceLocation comprehensive comparison")
    func sourceLocationComprehensiveComparison() throws {
        // Create locations in expected order
        let locations = [
            ZEngine.SourceLocation(file: "a.zil", line: 1, column: 1),
            ZEngine.SourceLocation(file: "a.zil", line: 1, column: 10),
            ZEngine.SourceLocation(file: "a.zil", line: 2, column: 1),
            ZEngine.SourceLocation(file: "a.zil", line: 10, column: 5),
            ZEngine.SourceLocation(file: "b.zil", line: 1, column: 1),
            ZEngine.SourceLocation(file: "z.zil", line: 999, column: 999)
        ]

        // Test that each location is less than all subsequent ones
        for i in 0..<locations.count {
            for j in (i+1)..<locations.count {
                #expect(locations[i] < locations[j], "locations[\(i)] should be < locations[\(j)]")
                #expect(!(locations[j] < locations[i]), "locations[\(j)] should not be < locations[\(i)]")
            }
        }

        // Test sorting
        let shuffled = locations.shuffled()
        let sorted = shuffled.sorted()
        #expect(sorted == locations)
    }

    // MARK: - Hashable Tests

    @Test("SourceLocation hash consistency")
    func sourceLocationHashConsistency() throws {
        let location1 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 5)
        let location2 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 5)

        // Equal objects must have equal hash values
        #expect(location1 == location2)
        #expect(location1.hashValue == location2.hashValue)
    }

    @Test("SourceLocation hash uniqueness")
    func sourceLocationHashUniqueness() throws {
        let location1 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 5)
        let location2 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 6) // Different column
        let location3 = ZEngine.SourceLocation(file: "test.zil", line: 11, column: 5) // Different line
        let location4 = ZEngine.SourceLocation(file: "other.zil", line: 10, column: 5) // Different file

        // Different objects should typically have different hash values
        // (Not guaranteed by protocol, but good implementation should try)
        let hashes = [
            location1.hashValue,
            location2.hashValue,
            location3.hashValue,
            location4.hashValue
        ]

        let uniqueHashes = Set(hashes)
        #expect(uniqueHashes.count > 1) // At least some should be different
    }

    @Test("SourceLocation hash ignores offset")
    func sourceLocationHashIgnoresOffset() throws {
        let location1 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 5, offset: nil)
        let location2 = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 5, offset: 100)

        // Hash should be consistent with equality (both ignore offset)
        #expect(location1 == location2)
        #expect(location1.hashValue == location2.hashValue)
    }

    // MARK: - Sendable Conformance Tests

    @Test("SourceLocation sendable conformance")
    func sourceLocationSendableConformance() throws {
        // Test that ZEngine.SourceLocation conforms to Sendable
        let location: ZEngine.SourceLocation = ZEngine.SourceLocation(file: "test.zil", line: 1, column: 1)

        // This test verifies that ZEngine.SourceLocation is Sendable by compilation
        // If ZEngine.SourceLocation didn't conform to Sendable, this would be a compile error
        let sendableCheck: any Sendable = location
        #expect(sendableCheck is ZEngine.SourceLocation)

        // Test that static placeholders are also sendable
        let generatedSendable: any Sendable = ZEngine.SourceLocation.generated
        let unknownSendable: any Sendable = ZEngine.SourceLocation.unknown
        #expect(generatedSendable is ZEngine.SourceLocation)
        #expect(unknownSendable is ZEngine.SourceLocation)
    }

    // MARK: - Edge Cases and Special Values

    @Test("SourceLocation edge case values")
    func sourceLocationEdgeCaseValues() throws {
        // Test with zero values
        let zeroLocation = ZEngine.SourceLocation(file: "test.zil", line: 0, column: 0)
        #expect(zeroLocation.description == "test.zil:0:0")

        // Test with negative values (allowed by implementation)
        let negativeLocation = ZEngine.SourceLocation(file: "test.zil", line: -1, column: -1)
        #expect(negativeLocation.description == "test.zil:-1:-1")

        // Test with large values
        let largeLocation = ZEngine.SourceLocation(file: "huge.zil", line: Int.max, column: Int.max)
        #expect(largeLocation.file == "huge.zil")
        #expect(largeLocation.line == Int.max)
        #expect(largeLocation.column == Int.max)

        // Test with negative offset
        let negativeOffset = ZEngine.SourceLocation(file: "test.zil", line: 1, column: 1, offset: -100)
        #expect(negativeOffset.offset == -100)

        // Test with zero offset
        let zeroOffset = ZEngine.SourceLocation(file: "test.zil", line: 1, column: 1, offset: 0)
        #expect(zeroOffset.offset == 0)
    }

    @Test("SourceLocation special characters in filename")
    func sourceLocationSpecialCharactersInFilename() throws {
        // Test various special characters that might appear in file names
        let specialNames = [
            "test-file.zil",
            "test_file.zil",
            "test.backup.zil",
            "test (copy).zil",
            "test@home.zil",
            "test#1.zil",
            "test$var.zil",
            "test%complete.zil",
            "test&more.zil",
            "file with spaces.zil",
            "数字.zil", // Unicode characters
            "файл.zil", // Cyrillic
            "αβγ.zil"   // Greek
        ]

        for fileName in specialNames {
            let location = ZEngine.SourceLocation(file: fileName, line: 1, column: 1)
            #expect(location.file == fileName)
            #expect(location.description == "\(fileName):1:1")
        }
    }

    // MARK: - URL Path Extraction Tests

    @Test("SourceLocation URL path extraction comprehensive")
    func sourceLocationURLPathExtractionComprehensive() throws {
        // Test various URL formats
        let testCases = [
            ("/path/to/file.zil", "file.zil"),
            ("/single/file.zil", "file.zil"),
            ("/file.zil", "file.zil"),
            ("file.zil", "file.zil"), // Just filename
            ("/path/to/dir/", "dir"), // Directory ending with slash - lastPathComponent returns "dir"
            ("/", "/"), // Root directory - lastPathComponent returns "/"
            ("", "swift-zil"), // Empty path - lastPathComponent returns current directory name
            ("/path/to/file with spaces.zil", "file with spaces.zil"),
            ("/path/to/file-with-dashes.zil", "file-with-dashes.zil"),
            ("/path/to/file_with_underscores.zil", "file_with_underscores.zil"),
            ("/very/long/deeply/nested/path/structure/file.zil", "file.zil")
        ]

        for (path, expectedName) in testCases {
            let url = URL(fileURLWithPath: path)
            let location = ZEngine.SourceLocation(file: url, line: 42, column: 10)

            #expect(location.file == expectedName, "Path '\(path)' should extract to '\(expectedName)'")
            #expect(location.line == 42)
            #expect(location.column == 10)
        }
    }

    // MARK: - Performance and Memory Tests

    @Test("SourceLocation creation performance")
    func sourceLocationCreationPerformance() throws {
        // Test that creating many source locations is efficient
        let startTime = CFAbsoluteTimeGetCurrent()

        var locations: [ZEngine.SourceLocation] = []
        for i in 1...1000 {
            let location = ZEngine.SourceLocation(file: "file\(i).zil", line: i, column: i % 80 + 1)
            locations.append(location)
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        #expect(locations.count == 1000)
        #expect(duration < 1.0) // Should complete in less than 1 second

        // Verify some locations were created correctly
        #expect(locations.first?.file == "file1.zil")
        #expect(locations.last?.file == "file1000.zil")
    }

    @Test("SourceLocation memory efficiency")
    func sourceLocationMemoryEfficiency() throws {
        // Test that ZEngine.SourceLocation doesn't have unexpected memory overhead
        let location1 = ZEngine.SourceLocation(file: "a" + String(repeating: "b", count: 1000), line: 1, column: 1)
        let location2 = ZEngine.SourceLocation(file: "test.zil", line: Int.max, column: Int.max, offset: Int.max)

        // Verify large values are handled correctly
        #expect(location1.file.count == 1001)
        #expect(location2.line == Int.max)
        #expect(location2.column == Int.max)
        #expect(location2.offset == Int.max)
    }

    // MARK: - Integration Tests

    @Test("SourceLocation integration with collections")
    func sourceLocationIntegrationWithCollections() throws {
        // Test using ZEngine.SourceLocation as dictionary keys (requires Hashable)
        var locationCounts: [ZEngine.SourceLocation: Int] = [:]

        let location1 = ZEngine.SourceLocation(file: "test.zil", line: 1, column: 1)
        let location2 = ZEngine.SourceLocation(file: "test.zil", line: 2, column: 1)
        let location1Duplicate = ZEngine.SourceLocation(file: "test.zil", line: 1, column: 1)

        locationCounts[location1] = 5
        locationCounts[location2] = 3
        locationCounts[location1Duplicate] = 10 // Should overwrite location1

        #expect(locationCounts.count == 2)
        #expect(locationCounts[location1] == 10) // Updated value
        #expect(locationCounts[location2] == 3)

        // Test using ZEngine.SourceLocation in Sets (requires Hashable)
        let locationSet: Set<ZEngine.SourceLocation> = [location1, location2, location1Duplicate]
        #expect(locationSet.count == 2) // location1 and location1Duplicate are equal

        // Test sorting (requires Comparable)
        let unsorted = [location2, location1]
        let sorted = unsorted.sorted()
        #expect(sorted == [location1, location2])
    }

    @Test("SourceLocation comprehensive protocol conformance")
    func sourceLocationComprehensiveProtocolConformance() throws {
        let location = ZEngine.SourceLocation(file: "test.zil", line: 42, column: 10, offset: 256)

        // Test CustomStringConvertible
        let description = location.description
        #expect(description == "test.zil:42:10")

        // Test that it can be used as Any
        let anyLocation: Any = location
        #expect(anyLocation is ZEngine.SourceLocation)

        // Test that it can be used in generic contexts
        func processLocation<T: CustomStringConvertible & Hashable & Comparable>(_ item: T) -> String {
            return item.description
        }

        let result = processLocation(location)
        #expect(result == "test.zil:42:10")
    }
}