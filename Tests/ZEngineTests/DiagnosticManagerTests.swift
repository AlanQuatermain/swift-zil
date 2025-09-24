import Testing
@testable import ZEngine

@Suite("Diagnostic Manager Tests")
struct DiagnosticManagerTests {

    @Test("Basic diagnostic collection")
    func basicDiagnosticCollection() throws {
        let manager = DiagnosticManager()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Initially should be empty
        #expect(manager.count == 0)
        #expect(manager.hasErrors == false)
        #expect(manager.hasWarnings == false)
        #expect(manager.hasFatalErrors == false)

        // Add a warning (using RuntimeError.unsupportedOperation for warning severity)
        let warning = RuntimeError.unsupportedOperation("test warning", location: location)
        manager.add(warning)

        #expect(manager.count == 1)
        #expect(manager.hasWarnings == true)
        #expect(manager.hasErrors == false)
        #expect(manager.hasFatalErrors == false)
        #expect(manager.warningCount == 1)
        #expect(manager.errorCount == 0)

        // Add an error
        let error = ParseError.undefinedSymbol("MISSING", location: location)
        manager.add(error)

        #expect(manager.count == 2)
        #expect(manager.hasWarnings == true)
        #expect(manager.hasErrors == true)
        #expect(manager.hasFatalErrors == false)
        #expect(manager.warningCount == 1)
        #expect(manager.errorCount == 1)

        // Add a fatal error (using RuntimeError for fatal since ParseError only does .error)
        let fatal = RuntimeError.corruptedStoryFile("unexpected end of file", location: location)
        manager.add(fatal)

        #expect(manager.count == 3)
        #expect(manager.hasFatalErrors == true)
        #expect(manager.errorCount == 2) // Fatal errors count as errors too
    }

    @Test("Bulk diagnostic operations")
    func bulkDiagnosticOperations() throws {
        let manager = DiagnosticManager()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Create multiple errors
        let errors = [
            ParseError.undefinedSymbol("SYMBOL1", location: location),
            ParseError.undefinedSymbol("SYMBOL2", location: location),
            ParseError.invalidSyntax("syntax error", location: location)
        ]

        // Add all at once
        manager.add(contentsOf: errors)

        #expect(manager.count == 3)
        #expect(manager.errorCount == 3)

        // Verify all diagnostics are retrievable
        let allDiagnostics = manager.allDiagnostics()
        #expect(allDiagnostics.count == 3)

        // Clear all
        manager.clear()
        #expect(manager.count == 0)
        #expect(manager.hasErrors == false)
        #expect(manager.allDiagnostics().isEmpty)
    }

    @Test("Severity-based filtering")
    func severityBasedFiltering() throws {
        let manager = DiagnosticManager()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Add diagnostics of different severities
        manager.add(RuntimeError.unsupportedOperation("warning1", location: location))
        manager.add(RuntimeError.unsupportedOperation("warning2", location: location))
        manager.add(ParseError.undefinedSymbol("ERROR1", location: location))
        manager.add(RuntimeError.corruptedStoryFile("unexpected end of file", location: location))

        // Test filtering by severity
        let warnings = manager.diagnostics(withSeverity: .warning)
        let errors = manager.diagnostics(withSeverity: .error)
        let fatals = manager.diagnostics(withSeverity: .fatal)

        #expect(warnings.count == 2)
        #expect(errors.count == 1)
        #expect(fatals.count == 1)

        // Verify content
        for warning in warnings {
            #expect(warning.severity == .warning)
        }
        for error in errors {
            #expect(error.severity == .error)
        }
        for fatal in fatals {
            #expect(fatal.severity == .fatal)
        }
    }

    @Test("File-based filtering")
    func fileBasedFiltering() throws {
        let manager = DiagnosticManager()

        let file1Location = SourceLocation(file: "file1.zil", line: 1, column: 1)
        let file2Location = SourceLocation(file: "file2.zil", line: 1, column: 1)
        let file3Location = SourceLocation(file: "file1.zil", line: 5, column: 10)

        // Add diagnostics from different files
        manager.add(ParseError.undefinedSymbol("A", location: file1Location))
        manager.add(ParseError.undefinedSymbol("B", location: file2Location))
        manager.add(ParseError.undefinedSymbol("C", location: file3Location))
        manager.add(ParseError.undefinedSymbol("D", location: file1Location))

        // Test file-based filtering
        let file1Diagnostics = manager.diagnostics(forFile: "file1.zil")
        let file2Diagnostics = manager.diagnostics(forFile: "file2.zil")
        let file3Diagnostics = manager.diagnostics(forFile: "nonexistent.zil")

        #expect(file1Diagnostics.count == 3) // Two from file1.zil
        #expect(file2Diagnostics.count == 1) // One from file2.zil
        #expect(file3Diagnostics.count == 0) // None from nonexistent file

        // Verify all file1 diagnostics are from the correct file
        for diagnostic in file1Diagnostics {
            #expect(diagnostic.location.file == "file1.zil")
        }
    }

    @Test("Diagnostic sorting by location")
    func diagnosticSortingByLocation() throws {
        let manager = DiagnosticManager()

        // Create diagnostics in non-sorted order
        let diagnostics = [
            ParseError.undefinedSymbol("D", location: SourceLocation(file: "file2.zil", line: 1, column: 1)),
            ParseError.undefinedSymbol("A", location: SourceLocation(file: "file1.zil", line: 1, column: 1)),
            ParseError.undefinedSymbol("C", location: SourceLocation(file: "file1.zil", line: 2, column: 5)),
            ParseError.undefinedSymbol("B", location: SourceLocation(file: "file1.zil", line: 1, column: 10)),
            ParseError.undefinedSymbol("E", location: SourceLocation(file: "file2.zil", line: 1, column: 5))
        ]

        // Add in random order
        for diagnostic in diagnostics {
            manager.add(diagnostic)
        }

        // Get sorted diagnostics
        let sorted = manager.sortedDiagnostics()

        #expect(sorted.count == 5)

        // Verify sorting order: file1.zil:1:1, file1.zil:1:10, file1.zil:2:5, file2.zil:1:1, file2.zil:1:5
        #expect(sorted[0].location.file == "file1.zil" && sorted[0].location.line == 1 && sorted[0].location.column == 1)
        #expect(sorted[1].location.file == "file1.zil" && sorted[1].location.line == 1 && sorted[1].location.column == 10)
        #expect(sorted[2].location.file == "file1.zil" && sorted[2].location.line == 2 && sorted[2].location.column == 5)
        #expect(sorted[3].location.file == "file2.zil" && sorted[3].location.line == 1 && sorted[3].location.column == 1)
        #expect(sorted[4].location.file == "file2.zil" && sorted[4].location.line == 1 && sorted[4].location.column == 5)
    }

    @Test("Diagnostic formatting without color")
    func diagnosticFormattingWithoutColor() throws {
        let manager = DiagnosticManager()
        let location = SourceLocation(file: "test.zil", line: 5, column: 10)

        let error = ParseError.undefinedSymbol("MISSING-SYMBOL", location: location)
        manager.add(error)

        // Test single diagnostic formatting
        let singleFormatted = manager.formatDiagnostic(error, colorOutput: false)
        #expect(singleFormatted.contains("test.zil:5:10"))
        #expect(singleFormatted.contains("error"))
        #expect(singleFormatted.contains("MISSING-SYMBOL"))
        #expect(!singleFormatted.contains("\u{001B}")) // No ANSI color codes

        // Test bulk formatting
        let warning = RuntimeError.unsupportedOperation("test warning", location: location)
        manager.add(warning)

        let allFormatted = manager.formatDiagnostics(colorOutput: false)
        let lines = allFormatted.components(separatedBy: "\n")
        #expect(lines.count == 2) // Two diagnostics
        #expect(!allFormatted.contains("\u{001B}")) // No ANSI color codes
    }

    @Test("Diagnostic formatting with color")
    func diagnosticFormattingWithColor() throws {
        let manager = DiagnosticManager()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Test different severities with color
        let warning = RuntimeError.unsupportedOperation("warning", location: location)
        let error = ParseError.undefinedSymbol("ERROR", location: location)
        let fatal = RuntimeError.corruptedStoryFile("unexpected end of file", location: location)

        let warningFormatted = manager.formatDiagnostic(warning, colorOutput: true)
        let errorFormatted = manager.formatDiagnostic(error, colorOutput: true)
        let fatalFormatted = manager.formatDiagnostic(fatal, colorOutput: true)

        // Check for ANSI color codes
        #expect(warningFormatted.contains("\u{001B}[33m")) // Yellow for warnings
        #expect(errorFormatted.contains("\u{001B}[31m"))   // Red for errors
        #expect(fatalFormatted.contains("\u{001B}[91m"))   // Bright red for fatal

        // Check for reset codes
        #expect(warningFormatted.contains("\u{001B}[0m"))
        #expect(errorFormatted.contains("\u{001B}[0m"))
        #expect(fatalFormatted.contains("\u{001B}[0m"))
    }

    @Test("Empty manager formatting")
    func emptyManagerFormatting() throws {
        let manager = DiagnosticManager()

        // Test formatting empty manager
        let formatted = manager.formatDiagnostics()
        #expect(formatted.isEmpty)

        let formattedWithColor = manager.formatDiagnostics(colorOutput: true)
        #expect(formattedWithColor.isEmpty)
    }

    @Test("Print operations")
    func printOperations() throws {
        let manager = DiagnosticManager()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Add some diagnostics
        manager.add(ParseError.undefinedSymbol("ERROR1", location: location))
        manager.add(ParseError.undefinedSymbol("ERROR2", location: location))
        manager.add(RuntimeError.unsupportedOperation("warning", location: location))

        // Note: printDiagnostics() and printSummary() output to stderr
        // We can't easily test the actual output, but we can verify they don't crash
        // and that the underlying formatting works correctly

        manager.printDiagnostics(colorOutput: false)
        manager.printDiagnostics(colorOutput: true)
        manager.printSummary()

        // Test empty manager printing
        let emptyManager = DiagnosticManager()
        emptyManager.printDiagnostics() // Should not print anything
        emptyManager.printSummary()     // Should not print anything

        // Test passes if no exceptions are thrown
        #expect(Bool(true))
    }

    @Test("Error count validation")
    func errorCountValidation() throws {
        let manager = DiagnosticManager()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Test various combinations of error severities
        #expect(manager.errorCount == 0)
        #expect(manager.warningCount == 0)

        // Add warnings (should not count as errors)
        manager.add(RuntimeError.unsupportedOperation("warn1", location: location))
        manager.add(RuntimeError.unsupportedOperation("warn2", location: location))

        #expect(manager.errorCount == 0)
        #expect(manager.warningCount == 2)
        #expect(manager.hasErrors == false)
        #expect(manager.hasWarnings == true)

        // Add regular errors
        manager.add(ParseError.undefinedSymbol("ERR1", location: location))

        #expect(manager.errorCount == 1)
        #expect(manager.warningCount == 2)
        #expect(manager.hasErrors == true)

        // Add fatal errors (should count as errors)
        manager.add(RuntimeError.corruptedStoryFile("unexpected end of file", location: location))

        #expect(manager.errorCount == 2) // Regular error + fatal error
        #expect(manager.warningCount == 2)
        #expect(manager.hasFatalErrors == true)
        #expect(manager.hasErrors == true)
    }

    @Test("Multiple file complex scenario")
    func multipleFileComplexScenario() throws {
        let manager = DiagnosticManager()

        // Create a complex scenario with multiple files and error types
        let mainFile = "main.zil"
        let libFile = "library.zil"
        let testFile = "test.zil"

        // Add all errors individually
        manager.add(ParseError.undefinedSymbol("MAIN-FUNC", location: SourceLocation(file: mainFile, line: 10, column: 5)))
        manager.add(ParseError.duplicateDefinition(name: "GLOBAL-VAR", location: SourceLocation(file: mainFile, line: 15, column: 1), originalLocation: SourceLocation(file: mainFile, line: 1, column: 1)))
        manager.add(RuntimeError.unsupportedOperation("missing >", location: SourceLocation(file: mainFile, line: 25, column: 20)))
        manager.add(ParseError.expectedAtom(location: SourceLocation(file: libFile, line: 5, column: 3)))
        manager.add(RuntimeError.unsupportedOperation("expected number", location: SourceLocation(file: libFile, line: 12, column: 8)))
        manager.add(RuntimeError.corruptedStoryFile("unexpected end of file", location: SourceLocation(file: testFile, line: 1, column: 1)))

        // Validate counts
        #expect(manager.count == 6)
        #expect(manager.errorCount == 4) // 3 errors + 1 fatal
        #expect(manager.warningCount == 2)
        #expect(manager.hasFatalErrors == true)

        // Test file filtering
        let mainFileErrors = manager.diagnostics(forFile: mainFile)
        let libFileErrors = manager.diagnostics(forFile: libFile)
        let testFileErrors = manager.diagnostics(forFile: testFile)

        #expect(mainFileErrors.count == 3)
        #expect(libFileErrors.count == 2)
        #expect(testFileErrors.count == 1)

        // Test severity filtering
        let warnings = manager.diagnostics(withSeverity: .warning)
        let regularErrors = manager.diagnostics(withSeverity: .error)
        let fatalErrors = manager.diagnostics(withSeverity: .fatal)

        #expect(warnings.count == 2)
        #expect(regularErrors.count == 3)
        #expect(fatalErrors.count == 1)

        // Test sorting preserves file-line-column order
        let sorted = manager.sortedDiagnostics()
        #expect(sorted.count == 6)

        // First should be library.zil:5:3, then library.zil:12:8, then main.zil:10:5, etc.
        #expect(sorted[0].location.file == libFile && sorted[0].location.line == 5)
        #expect(sorted[1].location.file == libFile && sorted[1].location.line == 12)
        #expect(sorted[2].location.file == mainFile && sorted[2].location.line == 10)

        // Test comprehensive formatting
        let formatted = manager.formatDiagnostics(colorOutput: false)
        #expect(!formatted.isEmpty)
        #expect(formatted.contains(mainFile))
        #expect(formatted.contains(libFile))
        #expect(formatted.contains(testFile))
    }
}