import Testing
@testable import ZEngine

@Suite("CompilationContext Tests")
struct CompilationContextTests {

    // MARK: - Version Management Tests

    @Test("Default version is 3")
    func defaultVersion() {
        let context = CompilationContext()
        #expect(context.getVersion() == 3)
    }

    @Test("Can set valid versions")
    func setValidVersions() throws {
        let context = CompilationContext()

        for version in 3...8 {
            try context.setVersion(version)
            #expect(context.getVersion() == version)
        }
    }

    @Test("Cannot set invalid versions")
    func setInvalidVersions() {
        let context = CompilationContext()

        // Too low
        #expect(throws: CompilationError.self) {
            try context.setVersion(2)
        }

        // Too high
        #expect(throws: CompilationError.self) {
            try context.setVersion(9)
        }

        // Way out of range
        #expect(throws: CompilationError.self) {
            try context.setVersion(0)
        }

        #expect(throws: CompilationError.self) {
            try context.setVersion(100)
        }
    }

    @Test("Time status line setting")
    func timeStatusLine() {
        let context = CompilationContext()

        #expect(context.hasTimeStatusLine() == false)

        context.setTimeStatusLine(true)
        #expect(context.hasTimeStatusLine() == true)

        context.setTimeStatusLine(false)
        #expect(context.hasTimeStatusLine() == false)
    }

    // MARK: - ZIP Options Tests

    @Test("Default ZIP options are empty")
    func defaultZipOptions() {
        let context = CompilationContext()
        #expect(context.getZipOptions().isEmpty)
        #expect(context.hasZipOption(.undo) == false)
        #expect(context.hasZipOption(.color) == false)
    }

    @Test("Can add single ZIP option")
    func addSingleZipOption() {
        let context = CompilationContext()

        context.addZipOptions(.undo)
        #expect(context.hasZipOption(.undo) == true)
        #expect(context.hasZipOption(.color) == false)
    }

    @Test("Can add multiple ZIP options")
    func addMultipleZipOptions() {
        let context = CompilationContext()

        context.addZipOptions([.undo, .color, .mouse])

        #expect(context.hasZipOption(.undo))
        #expect(context.hasZipOption(.color))
        #expect(context.hasZipOption(.mouse))
        #expect(context.hasZipOption(.sound) == false)
    }

    @Test("ZIP options accumulate")
    func zipOptionsAccumulate() {
        let context = CompilationContext()

        context.addZipOptions(.undo)
        context.addZipOptions(.color)
        context.addZipOptions([.mouse, .sound])

        let options = context.getZipOptions()
        #expect(options.contains(.undo))
        #expect(options.contains(.color))
        #expect(options.contains(.mouse))
        #expect(options.contains(.sound))
    }

    @Test("All ZIP options")
    func allZipOptions() {
        let context = CompilationContext()

        context.addZipOptions([.color, .mouse, .undo, .display, .sound, .menu, .big])

        #expect(context.hasZipOption(.color))
        #expect(context.hasZipOption(.mouse))
        #expect(context.hasZipOption(.undo))
        #expect(context.hasZipOption(.display))
        #expect(context.hasZipOption(.sound))
        #expect(context.hasZipOption(.menu))
        #expect(context.hasZipOption(.big))
    }

    // MARK: - Object Ordering Tests

    @Test("Default object ordering is defined")
    func defaultObjectOrdering() {
        let context = CompilationContext()
        #expect(context.getObjectOrdering() == .defined)
    }

    @Test("Can set object ordering")
    func setObjectOrdering() {
        let context = CompilationContext()

        context.setObjectOrdering(.roomsFirst)
        #expect(context.getObjectOrdering() == .roomsFirst)

        context.setObjectOrdering(.roomsAndLgsFirst)
        #expect(context.getObjectOrdering() == .roomsAndLgsFirst)

        context.setObjectOrdering(.roomsLast)
        #expect(context.getObjectOrdering() == .roomsLast)

        context.setObjectOrdering(.defined)
        #expect(context.getObjectOrdering() == .defined)
    }

    // MARK: - Tree Ordering Tests

    @Test("Default tree ordering is reverseDefined")
    func defaultTreeOrdering() {
        let context = CompilationContext()
        #expect(context.getTreeOrdering() == .reverseDefined)
    }

    @Test("Can set tree ordering")
    func setTreeOrdering() {
        let context = CompilationContext()

        context.setTreeOrdering(.reverseDefined)
        #expect(context.getTreeOrdering() == .reverseDefined)
    }

    // MARK: - Flag Ordering Tests

    @Test("Default flags ordered last is empty")
    func defaultFlagsOrderedLast() {
        let context = CompilationContext()
        #expect(context.getFlagsOrderedLast().isEmpty)
    }

    @Test("Can add flags to order last")
    func addFlagsOrderedLast() {
        let context = CompilationContext()

        context.addFlagsOrderedLast(["TOUCHBIT", "TRANSBIT"])

        #expect(context.isFlagOrderedLast("TOUCHBIT"))
        #expect(context.isFlagOrderedLast("TRANSBIT"))
        #expect(context.isFlagOrderedLast("TAKEBIT") == false)
    }

    @Test("Flags ordered last accumulate")
    func flagsOrderedLastAccumulate() {
        let context = CompilationContext()

        context.addFlagsOrderedLast(["FLAG1", "FLAG2"])
        context.addFlagsOrderedLast(["FLAG3"])

        let flags = context.getFlagsOrderedLast()
        #expect(flags.contains("FLAG1"))
        #expect(flags.contains("FLAG2"))
        #expect(flags.contains("FLAG3"))
        #expect(flags.count == 3)
    }

    // MARK: - File Context Tests

    @Test("Default file context is empty")
    func defaultFileContext() {
        let context = CompilationContext()
        #expect(context.getCurrentFilePath() == nil)
        #expect(context.getCurrentFileFlags().isEmpty)
    }

    @Test("Can push file context")
    func pushFileContext() {
        let context = CompilationContext()

        context.pushFileContext("file1.zil", flags: [.cleanStack])

        #expect(context.getCurrentFilePath() == "file1.zil")
        #expect(context.getCurrentFileFlags().contains(.cleanStack))
    }

    @Test("File context stack works correctly")
    func fileContextStack() {
        let context = CompilationContext()

        context.pushFileContext("file1.zil", flags: [.cleanStack])
        #expect(context.getCurrentFilePath() == "file1.zil")
        #expect(context.getCurrentFileFlags() == [.cleanStack])

        context.pushFileContext("file2.zil", flags: [.mdlZil, .keepRoutines])
        #expect(context.getCurrentFilePath() == "file2.zil")
        #expect(context.getCurrentFileFlags() == [.mdlZil, .keepRoutines])

        context.popFileContext()
        #expect(context.getCurrentFilePath() == "file1.zil")
        #expect(context.getCurrentFileFlags() == [.cleanStack])

        context.popFileContext()
        #expect(context.getCurrentFilePath() == nil)
        #expect(context.getCurrentFileFlags().isEmpty)
    }

    @Test("Popping empty file context is safe")
    func popEmptyFileContext() {
        let context = CompilationContext()

        context.popFileContext() // Should not crash
        #expect(context.getCurrentFilePath() == nil)
    }

    // MARK: - Routine Flags Tests

    @Test("Routine flags start empty")
    func routineFlagsStartEmpty() {
        let context = CompilationContext()
        let flags = context.consumeRoutineFlags()
        #expect(flags.isEmpty)
    }

    @Test("Can set and consume routine flags")
    func setAndConsumeRoutineFlags() {
        let context = CompilationContext()

        context.setNextRoutineFlags([.cleanStack, .keep])
        let flags = context.consumeRoutineFlags()

        #expect(flags.contains(.cleanStack))
        #expect(flags.contains(.keep))
        #expect(flags.contains(.suppressUnused) == false)
    }

    @Test("Routine flags are consumed on access")
    func routineFlagsConsumed() {
        let context = CompilationContext()

        context.setNextRoutineFlags([.cleanStack])
        _ = context.consumeRoutineFlags()

        // Should be empty now
        let flags2 = context.consumeRoutineFlags()
        #expect(flags2.isEmpty)
    }

    @Test("File flags contribute to routine flags")
    func fileFlagsContributeToRoutineFlags() {
        let context = CompilationContext()

        context.pushFileContext("file.zil", flags: [.cleanStack, .keepRoutines])

        // Even with no routine flags, should get flags from file
        let flags = context.consumeRoutineFlags()
        #expect(flags.contains(.cleanStack))
        #expect(flags.contains(.keep))
    }

    @Test("Routine and file flags combine correctly")
    func routineAndFileFlagsCombine() {
        let context = CompilationContext()

        context.pushFileContext("file.zil", flags: [.cleanStack])
        context.setNextRoutineFlags([.keep, .suppressUnused])

        let flags = context.consumeRoutineFlags()

        #expect(flags.contains(.cleanStack)) // From file
        #expect(flags.contains(.keep))       // From routine
        #expect(flags.contains(.suppressUnused)) // From routine
    }

    @Test("File suppress warnings flag maps to routine flag")
    func fileSuppressWarningsMapsToRoutine() {
        let context = CompilationContext()

        context.pushFileContext("file.zil", flags: [.suppressUnusedWarnings])

        let flags = context.consumeRoutineFlags()
        #expect(flags.contains(.suppressUnused))
    }

    @Test("Multiple routine definitions consume flags independently")
    func multipleRoutineDefinitions() {
        let context = CompilationContext()

        context.pushFileContext("file.zil", flags: [.cleanStack])

        // First routine: gets cleanStack from file
        let flags1 = context.consumeRoutineFlags()
        #expect(flags1.contains(.cleanStack))

        // Second routine: set specific flags
        context.setNextRoutineFlags([.keep])
        let flags2 = context.consumeRoutineFlags()
        #expect(flags2.contains(.cleanStack)) // From file
        #expect(flags2.contains(.keep))       // Specific to this routine

        // Third routine: back to just file flags
        let flags3 = context.consumeRoutineFlags()
        #expect(flags3.contains(.cleanStack))
        #expect(flags3.contains(.keep) == false)
    }

    // MARK: - Thread Safety Tests

    @Test("Context is thread-safe for version setting")
    func threadSafeVersionSetting() async {
        let context = CompilationContext()

        await withTaskGroup(of: Void.self) { group in
            for version in 3...8 {
                group.addTask {
                    try? context.setVersion(version)
                }
            }
        }

        // Should have one of the valid versions
        let finalVersion = context.getVersion()
        #expect((3...8).contains(finalVersion))
    }

    @Test("Context is thread-safe for ZIP options")
    func threadSafeZipOptions() async {
        let context = CompilationContext()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                context.addZipOptions(.undo)
            }
            group.addTask {
                context.addZipOptions(.color)
            }
            group.addTask {
                context.addZipOptions(.mouse)
            }
        }

        // All options should be present
        #expect(context.hasZipOption(.undo))
        #expect(context.hasZipOption(.color))
        #expect(context.hasZipOption(.mouse))
    }
}

// MARK: - Error Description Tests

@Suite("CompilationError Description Tests")
struct CompilationErrorDescriptionTests {

    @Test("Invalid version error description")
    func invalidVersionDescription() {
        let error = CompilationError.invalidVersion(9)
        #expect(error.description.contains("9"))
        #expect(error.description.contains("3-8"))
    }

    @Test("Version mismatch error description")
    func versionMismatchDescription() {
        let error = CompilationError.versionMismatch(expected: 5, actual: 3)
        #expect(error.description.contains("5"))
        #expect(error.description.contains("3"))
    }

    @Test("Unsupported feature error description")
    func unsupportedFeatureDescription() {
        let error = CompilationError.unsupportedFeature("SAVE_UNDO", requiredVersion: 5)
        #expect(error.description.contains("SAVE_UNDO"))
        #expect(error.description.contains("5"))
    }

    @Test("Invalid ZIP option error description")
    func invalidZipOptionDescription() {
        let error = CompilationError.invalidZipOption("BADOPTION")
        #expect(error.description.contains("BADOPTION"))
    }
}
