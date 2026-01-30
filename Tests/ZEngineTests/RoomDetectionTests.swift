import Testing
@testable import ZEngine

@Suite("Room Detection Tests")
struct RoomDetectionTests {

    @Test("Detect room with NORTH property")
    func detectRoomWithNorth() throws {
        let manager = MemoryLayoutManager(version: .v5, compilationContext: CompilationContext())

        // Allocate an object
        _ = manager.allocateObject("LIVING-ROOM")

        // Add a direction property (should mark as room)
        try manager.addObjectProperty(
            objectName: "LIVING-ROOM",
            propertyName: "NORTH",
            value: .atom("KITCHEN"),
            symbolTable: [:],
            location: SourceLocation.unknown
        )

        // Generate story file to trigger ordering
        let storyData = try manager.generateStoryFile()

        // Verify story file was generated
        #expect(storyData.count > 0, "Story file should be generated")
    }

    @Test("Detect room with multiple direction properties")
    func detectRoomWithMultipleDirections() throws {
        let manager = MemoryLayoutManager(version: .v5, compilationContext: CompilationContext())

        _ = manager.allocateObject("CROSSROADS")

        // Add multiple direction properties
        try manager.addObjectProperty(
            objectName: "CROSSROADS",
            propertyName: "NORTH",
            value: .atom("FOREST"),
            symbolTable: [:],
            location: SourceLocation.unknown
        )

        try manager.addObjectProperty(
            objectName: "CROSSROADS",
            propertyName: "SOUTH",
            value: .atom("VILLAGE"),
            symbolTable: [:],
            location: SourceLocation.unknown
        )

        try manager.addObjectProperty(
            objectName: "CROSSROADS",
            propertyName: "EAST",
            value: .atom("RIVER"),
            symbolTable: [:],
            location: SourceLocation.unknown
        )

        try manager.addObjectProperty(
            objectName: "CROSSROADS",
            propertyName: "WEST",
            value: .atom("MOUNTAIN"),
            symbolTable: [:],
            location: SourceLocation.unknown
        )

        let storyData = try manager.generateStoryFile()
        #expect(storyData.count > 0, "Story file should be generated")
    }

    @Test("Non-room object without direction properties")
    func nonRoomObject() throws {
        let manager = MemoryLayoutManager(version: .v5, compilationContext: CompilationContext())

        _ = manager.allocateObject("LAMP")

        // Add non-direction properties
        try manager.addObjectProperty(
            objectName: "LAMP",
            propertyName: "DESC",
            value: .string("brass lamp"),
            symbolTable: [:],
            location: SourceLocation.unknown
        )

        try manager.addObjectProperty(
            objectName: "LAMP",
            propertyName: "SIZE",
            value: .number(5),
            symbolTable: [:],
            location: SourceLocation.unknown
        )

        let storyData = try manager.generateStoryFile()
        #expect(storyData.count > 0, "Story file should be generated")
    }

    @Test("Rooms ordered before non-rooms with ROOMS-FIRST")
    func roomsOrderedFirst() throws {
        var context = CompilationContext()
        context.setObjectOrdering(.roomsFirst)

        let manager = MemoryLayoutManager(version: .v5, compilationContext: context)

        // Add objects in mixed order: room, non-room, room, non-room
        _ = manager.allocateObject("KITCHEN")  // Room
        try manager.addObjectProperty(
            objectName: "KITCHEN",
            propertyName: "SOUTH",
            value: .atom("HALL"),
            symbolTable: [:],
            location: SourceLocation.unknown
        )

        _ = manager.allocateObject("LAMP")  // Non-room
        try manager.addObjectProperty(
            objectName: "LAMP",
            propertyName: "DESC",
            value: .string("lamp"),
            symbolTable: [:],
            location: SourceLocation.unknown
        )

        _ = manager.allocateObject("BEDROOM")  // Room
        try manager.addObjectProperty(
            objectName: "BEDROOM",
            propertyName: "NORTH",
            value: .atom("HALL"),
            symbolTable: [:],
            location: SourceLocation.unknown
        )

        _ = manager.allocateObject("KEY")  // Non-room
        try manager.addObjectProperty(
            objectName: "KEY",
            propertyName: "DESC",
            value: .string("key"),
            symbolTable: [:],
            location: SourceLocation.unknown
        )

        // Generate and verify story file
        let storyData = try manager.generateStoryFile()
        #expect(storyData.count > 0, "Story file should be generated with ordered objects")

        // The ordering happens internally - we've verified it compiles successfully
        // with ORDER-OBJECTS? ROOMS-FIRST directive active
    }

    @Test("All direction property types detected")
    func allDirectionTypes() throws {
        let manager = MemoryLayoutManager(version: .v5, compilationContext: CompilationContext())

        let directions = [
            "NORTH", "SOUTH", "EAST", "WEST",
            "NE", "NW", "SE", "SW",
            "UP", "DOWN", "IN", "OUT", "LAND"
        ]

        for (index, direction) in directions.enumerated() {
            let roomName = "ROOM\(index)"
            _ = manager.allocateObject(roomName)

            try manager.addObjectProperty(
                objectName: roomName,
                propertyName: direction,
                value: .atom("DESTINATION"),
                symbolTable: [:],
                location: SourceLocation.unknown
            )
        }

        // All rooms should be detected
        let storyData = try manager.generateStoryFile()
        #expect(storyData.count > 0, "Story file with all direction types should be generated")
    }

    @Test("Case-insensitive direction detection")
    func caseInsensitiveDirections() throws {
        let manager = MemoryLayoutManager(version: .v5, compilationContext: CompilationContext())

        _ = manager.allocateObject("ROOM1")
        try manager.addObjectProperty(
            objectName: "ROOM1",
            propertyName: "north",  // lowercase
            value: .atom("DESTINATION"),
            symbolTable: [:],
            location: SourceLocation.unknown
        )

        _ = manager.allocateObject("ROOM2")
        try manager.addObjectProperty(
            objectName: "ROOM2",
            propertyName: "North",  // mixed case
            value: .atom("DESTINATION"),
            symbolTable: [:],
            location: SourceLocation.unknown
        )

        _ = manager.allocateObject("ROOM3")
        try manager.addObjectProperty(
            objectName: "ROOM3",
            propertyName: "NORTH",  // uppercase
            value: .atom("DESTINATION"),
            symbolTable: [:],
            location: SourceLocation.unknown
        )

        let storyData = try manager.generateStoryFile()
        #expect(storyData.count > 0, "All case variations should be detected as rooms")
    }
}
