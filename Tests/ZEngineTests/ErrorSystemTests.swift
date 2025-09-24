import Testing
@testable import ZEngine

@Suite("Error System Tests")
struct ErrorSystemTests {

    // MARK: - ErrorSeverity Tests

    @Test("ErrorSeverity description strings")
    func errorSeverityDescriptions() throws {
        #expect(ErrorSeverity.warning.description == "warning")
        #expect(ErrorSeverity.error.description == "error")
        #expect(ErrorSeverity.fatal.description == "fatal error")
    }

    // MARK: - ParseError Tests

    @Test("ParseError unexpected token")
    func parseErrorUnexpectedToken() throws {
        let location = SourceLocation(file: "test.zil", line: 5, column: 10)
        let error = ParseError.unexpectedToken(expected: "atom", found: .leftParen, location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "expected 'atom', found 'leftParen'")
        #expect(error.description == "test.zil:5:10: error: expected 'atom', found 'leftParen'")
    }

    @Test("ParseError unexpected end of file")
    func parseErrorUnexpectedEndOfFile() throws {
        let location = SourceLocation(file: "incomplete.zil", line: 20, column: 1)
        let error = ParseError.unexpectedEndOfFile(location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "unexpected end of file")
        #expect(error.description == "incomplete.zil:20:1: error: unexpected end of file")
    }

    @Test("ParseError invalid syntax")
    func parseErrorInvalidSyntax() throws {
        let location = SourceLocation(file: "syntax.zil", line: 3, column: 15)
        let error = ParseError.invalidSyntax("missing closing bracket", location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "invalid syntax: missing closing bracket")
        #expect(error.description == "syntax.zil:3:15: error: invalid syntax: missing closing bracket")
    }

    @Test("ParseError undefined symbol")
    func parseErrorUndefinedSymbol() throws {
        let location = SourceLocation(file: "undefined.zil", line: 12, column: 8)
        let error = ParseError.undefinedSymbol("MISSING-ROUTINE", location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "undefined symbol 'MISSING-ROUTINE'")
        #expect(error.description == "undefined.zil:12:8: error: undefined symbol 'MISSING-ROUTINE'")
    }

    @Test("ParseError duplicate definition")
    func parseErrorDuplicateDefinition() throws {
        let location = SourceLocation(file: "duplicate.zil", line: 25, column: 1)
        let originalLocation = SourceLocation(file: "duplicate.zil", line: 10, column: 1)
        let error = ParseError.duplicateDefinition(
            name: "GLOBAL-VAR",
            location: location,
            originalLocation: originalLocation
        )

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "duplicate definition of 'GLOBAL-VAR' (original at duplicate.zil:10:1)")
        #expect(error.description == "duplicate.zil:25:1: error: duplicate definition of 'GLOBAL-VAR' (original at duplicate.zil:10:1)")
    }

    @Test("ParseError type error")
    func parseErrorTypeError() throws {
        let location = SourceLocation(file: "type.zil", line: 8, column: 12)
        let error = ParseError.typeError("expected number, found string", location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "type error: expected number, found string")
        #expect(error.description == "type.zil:8:12: error: type error: expected number, found string")
    }

    @Test("ParseError expected errors")
    func parseErrorExpectedErrors() throws {
        let location = SourceLocation(file: "expected.zil", line: 1, column: 1)

        // Test all expected error types
        let expectedAtom = ParseError.expectedAtom(location: location)
        #expect(expectedAtom.message == "expected atom")
        #expect(expectedAtom.severity == .error)

        let expectedRoutineName = ParseError.expectedRoutineName(location: location)
        #expect(expectedRoutineName.message == "expected routine name")

        let expectedObjectName = ParseError.expectedObjectName(location: location)
        #expect(expectedObjectName.message == "expected object name")

        let expectedGlobalName = ParseError.expectedGlobalName(location: location)
        #expect(expectedGlobalName.message == "expected global variable name")

        let expectedPropertyName = ParseError.expectedPropertyName(location: location)
        #expect(expectedPropertyName.message == "expected property name")

        let expectedConstantName = ParseError.expectedConstantName(location: location)
        #expect(expectedConstantName.message == "expected constant name")

        let expectedFilename = ParseError.expectedFilename(location: location)
        #expect(expectedFilename.message == "expected filename string")

        let expectedVersionType = ParseError.expectedVersionType(location: location)
        #expect(expectedVersionType.message == "expected version type")

        let expectedParameterName = ParseError.expectedParameterName(location: location)
        #expect(expectedParameterName.message == "expected parameter name")

        let expectedObjectProperty = ParseError.expectedObjectProperty(location: location)
        #expect(expectedObjectProperty.message == "expected object property")
    }

    @Test("ParseError parameter section and unknown declaration")
    func parseErrorParameterAndUnknown() throws {
        let location = SourceLocation(file: "param.zil", line: 15, column: 5)

        let invalidParameterSection = ParseError.invalidParameterSection("INVALID", location: location)
        #expect(invalidParameterSection.message == "invalid parameter section 'INVALID'")
        #expect(invalidParameterSection.severity == .error)

        let unknownDeclaration = ParseError.unknownDeclaration("UNKNOWN", location: location)
        #expect(unknownDeclaration.message == "unknown declaration type 'UNKNOWN'")
        #expect(unknownDeclaration.severity == .error)
    }

    // MARK: - AssemblyError Tests

    @Test("AssemblyError invalid instruction")
    func assemblyErrorInvalidInstruction() throws {
        let location = SourceLocation(file: "assembly.zap", line: 42, column: 5)
        let error = AssemblyError.invalidInstruction("BADOP", location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "invalid instruction 'BADOP'")
        #expect(error.description == "assembly.zap:42:5: error: invalid instruction 'BADOP'")
    }

    @Test("AssemblyError invalid operand")
    func assemblyErrorInvalidOperand() throws {
        let location = SourceLocation(file: "operand.zap", line: 18, column: 12)
        let error = AssemblyError.invalidOperand(
            instruction: "ADD",
            operand: "INVALID",
            location: location
        )

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "invalid operand 'INVALID' for instruction 'ADD'")
        #expect(error.description == "operand.zap:18:12: error: invalid operand 'INVALID' for instruction 'ADD'")
    }

    @Test("AssemblyError undefined label")
    func assemblyErrorUndefinedLabel() throws {
        let location = SourceLocation(file: "labels.zap", line: 35, column: 8)
        let error = AssemblyError.undefinedLabel("MISSING_LABEL", location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "undefined label 'MISSING_LABEL'")
        #expect(error.description == "labels.zap:35:8: error: undefined label 'MISSING_LABEL'")
    }

    @Test("AssemblyError address out of range")
    func assemblyErrorAddressOutOfRange() throws {
        let location = SourceLocation(file: "memory.zap", line: 100, column: 1)
        let error = AssemblyError.addressOutOfRange(0x20000, location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "address 131072 out of range")
        #expect(error.description == "memory.zap:100:1: error: address 131072 out of range")
    }

    @Test("AssemblyError memory layout error")
    func assemblyErrorMemoryLayoutError() throws {
        let location = SourceLocation(file: "layout.zap", line: 5, column: 20)
        let error = AssemblyError.memoryLayoutError("overlapping segments", location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "memory layout error: overlapping segments")
        #expect(error.description == "layout.zap:5:20: error: memory layout error: overlapping segments")
    }

    @Test("AssemblyError version mismatch")
    func assemblyErrorVersionMismatch() throws {
        let location = SourceLocation(file: "version.zap", line: 78, column: 15)
        let error = AssemblyError.versionMismatch(instruction: "PIRACY", version: 3, location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "instruction 'PIRACY' not available in Z-Machine version 3")
        #expect(error.description == "version.zap:78:15: error: instruction 'PIRACY' not available in Z-Machine version 3")
    }

    // MARK: - RuntimeError Tests

    @Test("RuntimeError invalid memory access")
    func runtimeErrorInvalidMemoryAccess() throws {
        let location = SourceLocation(file: "runtime.z5", line: 1, column: 1)
        let error = RuntimeError.invalidMemoryAccess(0xFFFF, location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "invalid memory access at address 65535")
        #expect(error.description == "runtime.z5:1:1: error: invalid memory access at address 65535")
    }

    @Test("RuntimeError stack operations")
    func runtimeErrorStackOperations() throws {
        let location = SourceLocation(file: "stack.z5", line: 1, column: 1)

        let stackUnderflow = RuntimeError.stackUnderflow(location: location)
        #expect(stackUnderflow.location == location)
        #expect(stackUnderflow.severity == .error)
        #expect(stackUnderflow.message == "stack underflow")
        #expect(stackUnderflow.description == "stack.z5:1:1: error: stack underflow")

        let stackOverflow = RuntimeError.stackOverflow(location: location)
        #expect(stackOverflow.location == location)
        #expect(stackOverflow.severity == .error)
        #expect(stackOverflow.message == "stack overflow")
        #expect(stackOverflow.description == "stack.z5:1:1: error: stack overflow")
    }

    @Test("RuntimeError division by zero")
    func runtimeErrorDivisionByZero() throws {
        let location = SourceLocation(file: "divide.z5", line: 1, column: 1)
        let error = RuntimeError.divisionByZero(location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "division by zero")
        #expect(error.description == "divide.z5:1:1: error: division by zero")
    }

    @Test("RuntimeError object access")
    func runtimeErrorObjectAccess() throws {
        let location = SourceLocation(file: "object.z5", line: 1, column: 1)

        let invalidObject = RuntimeError.invalidObjectAccess(999, location: location)
        #expect(invalidObject.location == location)
        #expect(invalidObject.severity == .error)
        #expect(invalidObject.message == "invalid object access: object 999")
        #expect(invalidObject.description == "object.z5:1:1: error: invalid object access: object 999")

        let invalidProperty = RuntimeError.invalidPropertyAccess(objectId: 42, property: 15, location: location)
        #expect(invalidProperty.location == location)
        #expect(invalidProperty.severity == .error)
        #expect(invalidProperty.message == "invalid property access: object 42, property 15")
        #expect(invalidProperty.description == "object.z5:1:1: error: invalid property access: object 42, property 15")
    }

    @Test("RuntimeError corrupted story file")
    func runtimeErrorCorruptedStoryFile() throws {
        let location = SourceLocation(file: "corrupted.z5", line: 1, column: 1)
        let error = RuntimeError.corruptedStoryFile("invalid header checksum", location: location)

        #expect(error.location == location)
        #expect(error.severity == .fatal)
        #expect(error.message == "corrupted story file: invalid header checksum")
        #expect(error.description == "corrupted.z5:1:1: fatal: corrupted story file: invalid header checksum")
    }

    @Test("RuntimeError unsupported operation")
    func runtimeErrorUnsupportedOperation() throws {
        let location = SourceLocation(file: "unsupported.z5", line: 1, column: 1)
        let error = RuntimeError.unsupportedOperation("graphics operation", location: location)

        #expect(error.location == location)
        #expect(error.severity == .warning)
        #expect(error.message == "unsupported operation: graphics operation")
        #expect(error.description == "unsupported.z5:1:1: warning: unsupported operation: graphics operation")
    }

    // MARK: - FileError Tests

    @Test("FileError file not found")
    func fileErrorFileNotFound() throws {
        let location = SourceLocation(file: "main.zil", line: 5, column: 12)
        let error = FileError.fileNotFound("/missing/file.zil", location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "file not found: '/missing/file.zil'")
        #expect(error.description == "main.zil:5:12: error: file not found: '/missing/file.zil'")
    }

    @Test("FileError permission denied")
    func fileErrorPermissionDenied() throws {
        let location = SourceLocation(file: "secure.zil", line: 1, column: 1)
        let error = FileError.permissionDenied("/protected/file.zil", location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "permission denied: '/protected/file.zil'")
        #expect(error.description == "secure.zil:1:1: error: permission denied: '/protected/file.zil'")
    }

    @Test("FileError invalid path")
    func fileErrorInvalidPath() throws {
        let location = SourceLocation(file: "paths.zil", line: 3, column: 8)
        let error = FileError.invalidPath("invalid\0path", location: location)

        #expect(error.location == location)
        #expect(error.severity == .error)
        #expect(error.message == "invalid path: 'invalid\0path'")
        #expect(error.description == "paths.zil:3:8: error: invalid path: 'invalid\0path'")
    }

    @Test("FileError read and write errors")
    func fileErrorReadAndWriteErrors() throws {
        let location = SourceLocation(file: "io.zil", line: 10, column: 5)

        // Create mock underlying errors with custom localizedDescription
        struct MockError: Error {}
        let underlyingError = MockError()

        let readError = FileError.readError(path: "/tmp/input.zil", underlying: underlyingError, location: location)
        #expect(readError.location == location)
        #expect(readError.severity == .error)
        #expect(readError.message.contains("/tmp/input.zil"))
        #expect(readError.message.contains("failed to read"))
        #expect(readError.description.contains("io.zil:10:5: error:"))
        #expect(readError.description.contains("/tmp/input.zil"))

        let writeError = FileError.writeError(path: "/tmp/output.z5", underlying: underlyingError, location: location)
        #expect(writeError.location == location)
        #expect(writeError.severity == .error)
        #expect(writeError.message.contains("/tmp/output.z5"))
        #expect(writeError.message.contains("failed to write"))
        #expect(writeError.description.contains("io.zil:10:5: error:"))
        #expect(writeError.description.contains("/tmp/output.z5"))
    }

    // MARK: - ZILError Protocol Conformance Tests

    @Test("ZILError protocol conformance")
    func zilErrorProtocolConformance() throws {
        let location = SourceLocation(file: "protocol.zil", line: 1, column: 1)

        // Test that all error types conform to ZILError protocol
        let parseError: any ZILError = ParseError.invalidSyntax("test", location: location)
        let assemblyError: any ZILError = AssemblyError.invalidInstruction("TEST", location: location)
        let runtimeError: any ZILError = RuntimeError.divisionByZero(location: location)
        let fileError: any ZILError = FileError.fileNotFound("test.zil", location: location)

        // Test that all have required properties
        #expect(parseError.location == location)
        #expect(assemblyError.location == location)
        #expect(runtimeError.location == location)
        #expect(fileError.location == location)

        #expect(parseError.severity == .error)
        #expect(assemblyError.severity == .error)
        #expect(runtimeError.severity == .error)
        #expect(fileError.severity == .error)

        // Test that all have non-empty messages
        #expect(!parseError.message.isEmpty)
        #expect(!assemblyError.message.isEmpty)
        #expect(!runtimeError.message.isEmpty)
        #expect(!fileError.message.isEmpty)

        // Test that all have proper descriptions
        #expect(parseError.description.contains("protocol.zil:1:1"))
        #expect(assemblyError.description.contains("protocol.zil:1:1"))
        #expect(runtimeError.description.contains("protocol.zil:1:1"))
        #expect(fileError.description.contains("protocol.zil:1:1"))
    }

    // MARK: - Error Severity Distribution Tests

    @Test("Error severity distribution")
    func errorSeverityDistribution() throws {
        let location = SourceLocation(file: "severity.zil", line: 1, column: 1)

        // Test that different error types have appropriate severity levels
        var errorCount = 0
        var warningCount = 0
        var fatalCount = 0

        let errors: [any ZILError] = [
            ParseError.invalidSyntax("test", location: location),
            AssemblyError.invalidInstruction("test", location: location),
            RuntimeError.invalidMemoryAccess(0, location: location),
            RuntimeError.corruptedStoryFile("test", location: location),
            RuntimeError.unsupportedOperation("test", location: location),
            FileError.fileNotFound("test", location: location)
        ]

        for error in errors {
            switch error.severity {
            case .error:
                errorCount += 1
            case .warning:
                warningCount += 1
            case .fatal:
                fatalCount += 1
            }
        }

        #expect(errorCount == 4) // ParseError, AssemblyError, RuntimeError.invalidMemoryAccess, FileError
        #expect(warningCount == 1) // RuntimeError.unsupportedOperation
        #expect(fatalCount == 1) // RuntimeError.corruptedStoryFile
    }

    // MARK: - Error Message Consistency Tests

    @Test("Error message consistency and formatting")
    func errorMessageConsistency() throws {
        let location = SourceLocation(file: "consistency.zil", line: 1, column: 1)

        // Test that error messages follow consistent formatting patterns
        let parseError = ParseError.undefinedSymbol("SYMBOL", location: location)
        let assemblyError = AssemblyError.undefinedLabel("LABEL", location: location)
        let runtimeError = RuntimeError.invalidObjectAccess(42, location: location)
        let fileError = FileError.fileNotFound("file.zil", location: location)

        // All messages should be lowercase and descriptive
        #expect(parseError.message == "undefined symbol 'SYMBOL'")
        #expect(assemblyError.message == "undefined label 'LABEL'")
        #expect(runtimeError.message == "invalid object access: object 42")
        #expect(fileError.message == "file not found: 'file.zil'")

        // All descriptions should follow the format: location: severity: message
        #expect(parseError.description == "consistency.zil:1:1: error: undefined symbol 'SYMBOL'")
        #expect(assemblyError.description == "consistency.zil:1:1: error: undefined label 'LABEL'")
        #expect(runtimeError.description == "consistency.zil:1:1: error: invalid object access: object 42")
        #expect(fileError.description == "consistency.zil:1:1: error: file not found: 'file.zil'")
    }

    // MARK: - Error Uniqueness and Equality Tests

    @Test("Error equality and uniqueness")
    func errorEqualityAndUniqueness() throws {
        let location1 = SourceLocation(file: "test1.zil", line: 1, column: 1)
        let location2 = SourceLocation(file: "test2.zil", line: 2, column: 2)

        // Test that errors with same content but different locations are different
        let error1 = ParseError.undefinedSymbol("SYMBOL", location: location1)
        let error2 = ParseError.undefinedSymbol("SYMBOL", location: location2)
        let error3 = ParseError.undefinedSymbol("OTHER", location: location1)

        // Errors should have different locations but same type
        #expect(error1.location != error2.location)
        #expect(type(of: error1) == type(of: error2))

        // Errors should have different messages
        #expect(error1.message == error2.message)
        #expect(error1.message != error3.message)

        // Descriptions should be different due to location
        #expect(error1.description != error2.description)
        #expect(error1.description != error3.description)
    }
}