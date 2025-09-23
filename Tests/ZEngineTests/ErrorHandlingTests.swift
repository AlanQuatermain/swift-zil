import Testing
@testable import ZEngine

@Suite("Error Handling Tests")
struct ErrorHandlingTests {

    @Suite("Source Location Tests")
    struct SourceLocationTests {

        @Test("Source location creation and description")
        func sourceLocationCreation() {
            let location = ZEngine.SourceLocation(file: "test.zil", line: 42, column: 10)
            #expect(location.file == "test.zil")
            #expect(location.line == 42)
            #expect(location.column == 10)
            #expect(location.description == "test.zil:42:10")
        }

        @Test("Source location comparison")
        func sourceLocationComparison() {
            let loc1 = ZEngine.SourceLocation(file: "a.zil", line: 1, column: 1)
            let loc2 = ZEngine.SourceLocation(file: "a.zil", line: 1, column: 2)
            let loc3 = ZEngine.SourceLocation(file: "b.zil", line: 1, column: 1)

            #expect(loc1 < loc2)
            #expect(loc1 < loc3)
            #expect(loc1 == loc1)
        }

        @Test("Predefined source locations", arguments: [
            ("generated", ZEngine.SourceLocation.generated, "<generated>"),
            ("unknown", ZEngine.SourceLocation.unknown, "<unknown>")
        ])
        func predefinedSourceLocations(name: String, location: ZEngine.SourceLocation, expectedFile: String) {
            #expect(location.file == expectedFile)
            #expect(location.line == 0)
            #expect(location.column == 0)
        }
    }

    @Suite("Parse Error Tests")
    struct ParseErrorTests {

        @Test("Parse error severity levels", arguments: [
            ParseError.unexpectedToken(expected: ">", found: "EOF", location: ZEngine.SourceLocation.unknown),
            ParseError.unexpectedEndOfFile(location: ZEngine.SourceLocation.unknown),
            ParseError.invalidSyntax(message: "test", location: ZEngine.SourceLocation.unknown),
            ParseError.undefinedSymbol(name: "VAR", location: ZEngine.SourceLocation.unknown),
            ParseError.duplicateDefinition(name: "VAR", location: ZEngine.SourceLocation.unknown, originalLocation: ZEngine.SourceLocation.generated),
            ParseError.typeError(message: "test", location: ZEngine.SourceLocation.unknown)
        ])
        func parseErrorSeverityLevels(error: ParseError) {
            #expect(error.severity == .error)
        }

        @Test("Parse error messages", arguments: [
            (ParseError.unexpectedToken(expected: ">", found: "EOF", location: ZEngine.SourceLocation.unknown), "expected '>', found 'EOF'"),
            (ParseError.unexpectedEndOfFile(location: ZEngine.SourceLocation.unknown), "unexpected end of file"),
            (ParseError.undefinedSymbol(name: "MISSING-VAR", location: ZEngine.SourceLocation.unknown), "undefined symbol 'MISSING-VAR'"),
            (ParseError.invalidSyntax(message: "bad syntax", location: ZEngine.SourceLocation.unknown), "invalid syntax: bad syntax")
        ])
        func parseErrorMessages(error: ParseError, expectedMessage: String) {
            #expect(error.message == expectedMessage)
        }
    }

    @Suite("Assembly Error Tests")
    struct AssemblyErrorTests {

        @Test("Assembly error types and messages", arguments: [
            (AssemblyError.invalidInstruction(name: "BADOP", location: ZEngine.SourceLocation.unknown), "invalid instruction 'BADOP'"),
            (AssemblyError.invalidOperand(instruction: "ADD", operand: "invalid", location: ZEngine.SourceLocation.unknown), "invalid operand 'invalid' for instruction 'ADD'"),
            (AssemblyError.undefinedLabel(name: "MISSING", location: ZEngine.SourceLocation.unknown), "undefined label 'MISSING'"),
            (AssemblyError.addressOutOfRange(address: 999999, location: ZEngine.SourceLocation.unknown), "address 999999 out of range"),
            (AssemblyError.versionMismatch(instruction: "UNICODE", version: 3, location: ZEngine.SourceLocation.unknown), "instruction 'UNICODE' not available in Z-Machine version 3")
        ])
        func assemblyErrorMessages(error: AssemblyError, expectedMessage: String) {
            #expect(error.message == expectedMessage)
            #expect(error.severity == .error)
        }
    }

    @Suite("Runtime Error Tests")
    struct RuntimeErrorTests {

        @Test("Runtime error severity levels", arguments: [
            (RuntimeError.invalidMemoryAccess(address: 0, location: nil), ErrorSeverity.error),
            (RuntimeError.stackUnderflow(location: nil), ErrorSeverity.error),
            (RuntimeError.stackOverflow(location: nil), ErrorSeverity.error),
            (RuntimeError.divisionByZero(location: nil), ErrorSeverity.error),
            (RuntimeError.corruptedStoryFile(message: "bad header", location: nil), ErrorSeverity.fatal),
            (RuntimeError.unsupportedOperation(operation: "test", location: nil), ErrorSeverity.warning)
        ])
        func runtimeErrorSeverities(error: RuntimeError, expectedSeverity: ErrorSeverity) {
            #expect(error.severity == expectedSeverity)
        }

        @Test("Runtime error messages", arguments: [
            (RuntimeError.stackOverflow(location: nil), "stack overflow"),
            (RuntimeError.stackUnderflow(location: nil), "stack underflow"),
            (RuntimeError.divisionByZero(location: nil), "division by zero"),
            (RuntimeError.invalidMemoryAccess(address: 12345, location: nil), "invalid memory access at address 12345"),
            (RuntimeError.invalidObjectAccess(objectId: 42, location: nil), "invalid object access: object 42")
        ])
        func runtimeErrorMessages(error: RuntimeError, expectedMessage: String) {
            #expect(error.message == expectedMessage)
        }
    }

    @Suite("File Error Tests")
    struct FileErrorTests {

        @Test("File error types", arguments: [
            "nonexistent.zil",
            "/invalid/path/file.zil",
            "restricted.zil"
        ])
        func fileErrorCreation(filename: String) {
            let fileNotFound = FileError.fileNotFound(path: filename, location: nil)
            let permissionDenied = FileError.permissionDenied(path: filename, location: nil)

            #expect(fileNotFound.message.contains(filename))
            #expect(permissionDenied.message.contains(filename))
            #expect(fileNotFound.severity == .error)
            #expect(permissionDenied.severity == .error)
        }
    }

    @Suite("Diagnostic Manager Tests")
    struct DiagnosticManagerTests {

        @Test("Error severity counting", arguments: [
            (ErrorSeverity.warning, "hasWarnings"),
            (ErrorSeverity.error, "hasErrors"),
            (ErrorSeverity.fatal, "hasFatalErrors")
        ])
        func errorSeverityCounting(severity: ErrorSeverity, propertyName: String) {
            let manager = DiagnosticManager()
            let location = ZEngine.SourceLocation(file: "test.zil", line: 1, column: 1)

            // Create an error with the specified severity
            let error: any ZILError
            switch severity {
            case .warning:
                error = RuntimeError.unsupportedOperation(operation: "test", location: location)
            case .error:
                error = ParseError.invalidSyntax(message: "test", location: location)
            case .fatal:
                error = RuntimeError.corruptedStoryFile(message: "test", location: location)
            }

            manager.add(error)

            // Verify the appropriate property is true
            switch severity {
            case .warning:
                #expect(manager.hasWarnings)
                #expect(!manager.hasErrors)
                #expect(!manager.hasFatalErrors)
            case .error:
                #expect(manager.hasErrors)
                #expect(!manager.hasWarnings)
                #expect(!manager.hasFatalErrors)
            case .fatal:
                #expect(manager.hasFatalErrors)
                #expect(manager.hasErrors) // Fatal errors also count as errors
                #expect(!manager.hasWarnings)
            }
        }

        @Test("Diagnostic filtering by file", arguments: [
            "main.zil",
            "objects.zil",
            "verbs.zil",
            "rooms.zil"
        ])
        func diagnosticFilteringByFile(filename: String) {
            let manager = DiagnosticManager()
            let location = ZEngine.SourceLocation(file: filename, line: 1, column: 1)
            let otherLocation = ZEngine.SourceLocation(file: "other.zil", line: 1, column: 1)

            let error1 = ParseError.invalidSyntax(message: "error in \(filename)", location: location)
            let error2 = ParseError.invalidSyntax(message: "error in other file", location: otherLocation)

            manager.add(error1)
            manager.add(error2)

            let filtered = manager.diagnostics(forFile: filename)
            #expect(filtered.count == 1)
            #expect(filtered[0].location?.file == filename)
        }
    }

    @Suite("Error Suggestion Tests")
    struct ErrorSuggestionTests {

        @Test("Parse error suggestions", arguments: [
            (ParseError.undefinedSymbol(name: "MISSING-VAR", location: ZEngine.SourceLocation.unknown), "Define 'MISSING-VAR'"),
            (ParseError.duplicateDefinition(name: "DUPLICATE", location: ZEngine.SourceLocation.unknown, originalLocation: ZEngine.SourceLocation.generated), "Rename one of the 'DUPLICATE'"),
            (ParseError.unexpectedToken(expected: ">", found: "EOF", location: ZEngine.SourceLocation.unknown), "Add missing '>'")
        ])
        func parseErrorSuggestions(error: ParseError, expectedSuggestionPart: String) {
            let suggestions = ErrorUtils.suggestFixes(for: error)
            #expect(!suggestions.isEmpty)
            #expect(suggestions.contains { $0.contains(expectedSuggestionPart) })
        }

        @Test("Assembly error suggestions", arguments: [
            (AssemblyError.versionMismatch(instruction: "UNICODE", version: 3, location: ZEngine.SourceLocation.unknown), "Use Z-Machine version 5"),
            (AssemblyError.undefinedLabel(name: "MISSING-LABEL", location: ZEngine.SourceLocation.unknown), "Define label 'MISSING-LABEL'")
        ])
        func assemblyErrorSuggestions(error: AssemblyError, expectedSuggestionPart: String) {
            let suggestions = ErrorUtils.suggestFixes(for: error)
            #expect(!suggestions.isEmpty)
            #expect(suggestions.contains { $0.contains(expectedSuggestionPart) })
        }

        @Test("Runtime error suggestions", arguments: [
            (RuntimeError.divisionByZero(location: nil), "Check divisor before division"),
            (RuntimeError.stackOverflow(location: nil), "Reduce recursion depth")
        ])
        func runtimeErrorSuggestions(error: RuntimeError, expectedSuggestionPart: String) {
            let suggestions = ErrorUtils.suggestFixes(for: error)
            #expect(!suggestions.isEmpty)
            #expect(suggestions.contains { $0.contains(expectedSuggestionPart) })
        }
    }

    @Suite("Error Context Formatting Tests")
    struct ErrorContextTests {

        @Test("Context line formatting", arguments: [
            (1, 0), // First line, no lines before
            (2, 1), // Second line, one line before
            (5, 2), // Middle line, two lines before
            (10, 3) // Later line, three lines before
        ])
        func contextLineFormatting(errorLine: Int, contextLines: Int) {
            let sourceLines = (1...10).map { "line \($0)" }
            let sourceText = sourceLines.joined(separator: "\n")
            let location = ZEngine.SourceLocation(file: "test.zil", line: errorLine, column: 5)
            let error = ParseError.invalidSyntax(message: "test error", location: location)

            let formatted = ErrorUtils.formatErrorWithContext(error, sourceText: sourceText, contextLines: contextLines)

            #expect(formatted.contains("line \(errorLine)"))
            #expect(formatted.contains("^"))
            #expect(formatted.contains("test.zil:\(errorLine):5"))
        }
    }
}