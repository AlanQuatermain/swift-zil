import Foundation

/// Base protocol for all ZIL-related errors.
///
/// This protocol provides a common interface for all errors that can occur during
/// ZIL compilation, assembly, or execution. It includes source location tracking,
/// human-readable error messages, and severity levels for proper error reporting.
///
/// ## Conforming Types
/// - `ParseError`: Errors during ZIL source code parsing
/// - `AssemblyError`: Errors during ZAP assembly and bytecode generation
/// - `RuntimeError`: Errors during Z-Machine execution
/// - `FileError`: File system and I/O related errors
public protocol ZILError: Error, CustomStringConvertible {
    /// The source location where this error occurred
    var location: SourceLocation { get }

    /// A human-readable description of the error
    var message: String { get }

    /// The severity level of this error
    var severity: ErrorSeverity { get }
}

/// Represents the severity level of an error or diagnostic message.
///
/// Severity levels help categorize the importance of diagnostic messages and
/// determine how the compilation process should respond to them.
public enum ErrorSeverity: Sendable {
    /// A warning that doesn't prevent compilation but indicates potential issues
    case warning

    /// An error that prevents successful compilation or execution
    case error

    /// A fatal error that immediately terminates the process
    case fatal

    public var description: String {
        switch self {
        case .warning: return "warning"
        case .error: return "error"
        case .fatal: return "fatal error"
        }
    }
}

/// Errors that occur during ZIL source code parsing and compilation.
///
/// `ParseError` represents various syntax and semantic errors that can be encountered
/// while parsing ZIL source files, including unexpected tokens, undefined symbols,
/// and type mismatches.
public struct ParseError: ZILError {
    /// The source location where this error occurred
    public let location: SourceLocation

    /// The specific error code and associated data
    let code: ErrorCode

    /// Specific error codes for parse errors
    enum ErrorCode: Sendable, Equatable {
        /// An unexpected token was encountered during parsing
        case unexpectedToken(expected: String, found: TokenType)

        /// The source file ended unexpectedly
        case unexpectedEndOfFile

        /// Invalid ZIL syntax was encountered
        case invalidSyntax(String)

        /// Reference to an undefined symbol
        case undefinedSymbol(String)

        /// A symbol was defined more than once
        case duplicateDefinition(name: String, originalLocation: SourceLocation)

        /// A type-related error occurred
        case typeError(String)

        /// Expected an atom but found something else
        case expectedAtom

        /// Expected a routine name
        case expectedRoutineName

        /// Expected an object name
        case expectedObjectName

        /// Expected a global variable name
        case expectedGlobalName

        /// Expected a property name
        case expectedPropertyName

        /// Expected a constant name
        case expectedConstantName

        /// Expected a filename string
        case expectedFilename

        /// Expected a version type
        case expectedVersionType

        /// Expected a parameter name in routine declaration
        case expectedParameterName

        /// Invalid parameter section marker
        case invalidParameterSection(String)

        /// Expected an object property
        case expectedObjectProperty

        /// Unknown top-level declaration
        case unknownDeclaration(String)

        /// Circular file inclusion detected
        case circularInclude(path: String, stack: [String])

        /// Referenced file could not be found
        case fileNotFound(String, currentPath: String?)
    }

    private init(_ code: ErrorCode, location: SourceLocation) {
        self.code = code
        self.location = location
    }

    // MARK: - Static Factory Methods

    /// Creates an unexpected token error.
    public static func unexpectedToken(expected: String, found: TokenType, location: SourceLocation) -> ParseError {
        return ParseError(.unexpectedToken(expected: expected, found: found), location: location)
    }

    /// Creates an unexpected end of file error.
    public static func unexpectedEndOfFile(location: SourceLocation) -> ParseError {
        return ParseError(.unexpectedEndOfFile, location: location)
    }

    /// Creates an invalid syntax error.
    public static func invalidSyntax(_ message: String, location: SourceLocation) -> ParseError {
        return ParseError(.invalidSyntax(message), location: location)
    }

    /// Creates an undefined symbol error.
    public static func undefinedSymbol(_ name: String, location: SourceLocation) -> ParseError {
        return ParseError(.undefinedSymbol(name), location: location)
    }

    /// Creates a duplicate definition error.
    public static func duplicateDefinition(name: String, location: SourceLocation, originalLocation: SourceLocation) -> ParseError {
        return ParseError(.duplicateDefinition(name: name, originalLocation: originalLocation), location: location)
    }

    /// Creates a type error.
    public static func typeError(_ message: String, location: SourceLocation) -> ParseError {
        return ParseError(.typeError(message), location: location)
    }

    /// Creates an expected atom error.
    public static func expectedAtom(location: SourceLocation) -> ParseError {
        return ParseError(.expectedAtom, location: location)
    }

    /// Creates an expected routine name error.
    public static func expectedRoutineName(location: SourceLocation) -> ParseError {
        return ParseError(.expectedRoutineName, location: location)
    }

    /// Creates an expected object name error.
    public static func expectedObjectName(location: SourceLocation) -> ParseError {
        return ParseError(.expectedObjectName, location: location)
    }

    /// Creates an expected global variable name error.
    public static func expectedGlobalName(location: SourceLocation) -> ParseError {
        return ParseError(.expectedGlobalName, location: location)
    }

    /// Creates an expected property name error.
    public static func expectedPropertyName(location: SourceLocation) -> ParseError {
        return ParseError(.expectedPropertyName, location: location)
    }

    /// Creates an expected constant name error.
    public static func expectedConstantName(location: SourceLocation) -> ParseError {
        return ParseError(.expectedConstantName, location: location)
    }

    /// Creates an expected filename error.
    public static func expectedFilename(location: SourceLocation) -> ParseError {
        return ParseError(.expectedFilename, location: location)
    }

    /// Creates an expected version type error.
    public static func expectedVersionType(location: SourceLocation) -> ParseError {
        return ParseError(.expectedVersionType, location: location)
    }

    /// Creates an expected parameter name error.
    public static func expectedParameterName(location: SourceLocation) -> ParseError {
        return ParseError(.expectedParameterName, location: location)
    }

    /// Creates an invalid parameter section error.
    public static func invalidParameterSection(_ section: String, location: SourceLocation) -> ParseError {
        return ParseError(.invalidParameterSection(section), location: location)
    }

    /// Creates an expected object property error.
    public static func expectedObjectProperty(location: SourceLocation) -> ParseError {
        return ParseError(.expectedObjectProperty, location: location)
    }

    /// Creates an unknown declaration error.
    public static func unknownDeclaration(_ keyword: String, location: SourceLocation) -> ParseError {
        return ParseError(.unknownDeclaration(keyword), location: location)
    }

    /// Creates a circular include error.
    public static func circularInclude(path: String, stack: [String], location: SourceLocation) -> ParseError {
        return ParseError(.circularInclude(path: path, stack: stack), location: location)
    }

    /// Creates a file not found error.
    public static func fileNotFound(_ filename: String, currentPath: String?) -> ParseError {
        return ParseError(.fileNotFound(filename, currentPath: currentPath), location: SourceLocation(file: currentPath ?? "<unknown>", line: 0, column: 0))
    }

    public var message: String {
        switch code {
        case .unexpectedToken(let expected, let found):
            return "expected '\(expected)', found '\(found)'"
        case .unexpectedEndOfFile:
            return "unexpected end of file"
        case .invalidSyntax(let msg):
            return "invalid syntax: \(msg)"
        case .undefinedSymbol(let name):
            return "undefined symbol '\(name)'"
        case .duplicateDefinition(let name, let original):
            return "duplicate definition of '\(name)' (original at \(original))"
        case .typeError(let msg):
            return "type error: \(msg)"
        case .expectedAtom:
            return "expected atom"
        case .expectedRoutineName:
            return "expected routine name"
        case .expectedObjectName:
            return "expected object name"
        case .expectedGlobalName:
            return "expected global variable name"
        case .expectedPropertyName:
            return "expected property name"
        case .expectedConstantName:
            return "expected constant name"
        case .expectedFilename:
            return "expected filename string"
        case .expectedVersionType:
            return "expected version type"
        case .expectedParameterName:
            return "expected parameter name"
        case .invalidParameterSection(let section):
            return "invalid parameter section '\(section)'"
        case .expectedObjectProperty:
            return "expected object property"
        case .unknownDeclaration(let keyword):
            return "unknown declaration type '\(keyword)'"
        case .circularInclude(let path, let stack):
            return "circular include detected: '\(path)' (inclusion stack: \(stack.joined(separator: " -> ")))"
        case .fileNotFound(let filename, let currentPath):
            if let currentPath = currentPath {
                return "file not found: '\(filename)' (searching from '\(currentPath)')"
            } else {
                return "file not found: '\(filename)'"
            }
        }
    }

    public var severity: ErrorSeverity {
        return .error
    }

    public var description: String {
        return "\(location): \(severity): \(message)"
    }
}

/// Errors that occur during Z-Machine assembly and bytecode generation.
///
/// `AssemblyError` represents issues encountered while converting ZAP assembly
/// language into Z-Machine bytecode, including invalid instructions, operands,
/// and version compatibility problems.
public struct AssemblyError: ZILError {
    /// The source location where this error occurred
    public let location: SourceLocation

    /// The specific error code and associated data
    let code: ErrorCode

    /// Specific error codes for assembly errors
    enum ErrorCode: Sendable, Equatable {
        /// An invalid or unrecognized instruction was encountered
        case invalidInstruction(String)

        /// An invalid operand was provided for an instruction
        case invalidOperand(instruction: String, operand: String)

        /// Reference to an undefined label
        case undefinedLabel(String)

        /// A memory address is out of the valid range
        case addressOutOfRange(Int)

        /// A branch target is out of the valid offset range
        case branchTargetOutOfRange(target: String, offset: Int)

        /// An error occurred in memory layout or organization
        case memoryLayoutError(String)

        /// An instruction is not available in the target Z-Machine version
        case versionMismatch(instruction: String, version: Int)
    }

    private init(_ code: ErrorCode, location: SourceLocation) {
        self.code = code
        self.location = location
    }

    // MARK: - Static Factory Methods

    /// Creates an invalid instruction error.
    public static func invalidInstruction(_ name: String, location: SourceLocation) -> AssemblyError {
        return AssemblyError(.invalidInstruction(name), location: location)
    }

    /// Creates an invalid operand error.
    public static func invalidOperand(instruction: String, operand: String, location: SourceLocation) -> AssemblyError {
        return AssemblyError(.invalidOperand(instruction: instruction, operand: operand), location: location)
    }

    /// Creates an undefined label error.
    public static func undefinedLabel(_ name: String, location: SourceLocation) -> AssemblyError {
        return AssemblyError(.undefinedLabel(name), location: location)
    }

    /// Creates an address out of range error.
    public static func addressOutOfRange(_ address: Int, location: SourceLocation) -> AssemblyError {
        return AssemblyError(.addressOutOfRange(address), location: location)
    }

    /// Creates a memory layout error.
    public static func memoryLayoutError(_ message: String, location: SourceLocation) -> AssemblyError {
        return AssemblyError(.memoryLayoutError(message), location: location)
    }

    /// Creates a version mismatch error.
    public static func versionMismatch(instruction: String, version: Int, location: SourceLocation) -> AssemblyError {
        return AssemblyError(.versionMismatch(instruction: instruction, version: version), location: location)
    }

    /// Creates a branch target out of range error.
    public static func branchTargetOutOfRange(target: String, offset: Int, location: SourceLocation) -> AssemblyError {
        return AssemblyError(.branchTargetOutOfRange(target: target, offset: offset), location: location)
    }

    public var message: String {
        switch code {
        case .invalidInstruction(let name):
            return "invalid instruction '\(name)'"
        case .invalidOperand(let instruction, let operand):
            return "invalid operand '\(operand)' for instruction '\(instruction)'"
        case .undefinedLabel(let name):
            return "undefined label '\(name)'"
        case .addressOutOfRange(let address):
            return "address \(address) out of range"
        case .branchTargetOutOfRange(let target, let offset):
            return "branch target '\(target)' out of range (offset \(offset), must be -8192 to +8191)"
        case .memoryLayoutError(let msg):
            return "memory layout error: \(msg)"
        case .versionMismatch(let instruction, let version):
            return "instruction '\(instruction)' not available in Z-Machine version \(version)"
        }
    }

    public var severity: ErrorSeverity {
        return .error
    }

    public var description: String {
        return "\(location): \(severity): \(message)"
    }
}

/// Errors that occur during Z-Machine virtual machine execution.
///
/// `RuntimeError` represents various runtime failures that can happen while
/// executing Z-Machine bytecode, including memory access violations, stack
/// operations, and corrupted story files.
public struct RuntimeError: ZILError {
    /// The source location where this error occurred
    public let location: SourceLocation

    /// The specific error code and associated data
    let code: ErrorCode

    /// Specific error codes for runtime errors
    enum ErrorCode: Sendable, Equatable {
        /// An attempt to access invalid memory location
        case invalidMemoryAccess(Int)

        /// Stack underflow occurred (pop from empty stack)
        case stackUnderflow

        /// Stack overflow occurred (too many items pushed)
        case stackOverflow

        /// Division by zero was attempted
        case divisionByZero

        /// An attempt to access an invalid object
        case invalidObjectAccess(Int)

        /// An attempt to access an invalid object property
        case invalidPropertyAccess(objectId: Int, property: Int)

        /// The story file is corrupted or invalid
        case corruptedStoryFile(String)

        /// An unsupported operation was requested
        case unsupportedOperation(String)
    }

    private init(_ code: ErrorCode, location: SourceLocation) {
        self.code = code
        self.location = location
    }

    // MARK: - Static Factory Methods

    /// Creates an invalid memory access error.
    public static func invalidMemoryAccess(_ address: Int, location: SourceLocation) -> RuntimeError {
        return RuntimeError(.invalidMemoryAccess(address), location: location)
    }

    /// Creates a stack underflow error.
    public static func stackUnderflow(location: SourceLocation) -> RuntimeError {
        return RuntimeError(.stackUnderflow, location: location)
    }

    /// Creates a stack overflow error.
    public static func stackOverflow(location: SourceLocation) -> RuntimeError {
        return RuntimeError(.stackOverflow, location: location)
    }

    /// Creates a division by zero error.
    public static func divisionByZero(location: SourceLocation) -> RuntimeError {
        return RuntimeError(.divisionByZero, location: location)
    }

    /// Creates an invalid object access error.
    public static func invalidObjectAccess(_ objectId: Int, location: SourceLocation) -> RuntimeError {
        return RuntimeError(.invalidObjectAccess(objectId), location: location)
    }

    /// Creates an invalid property access error.
    public static func invalidPropertyAccess(objectId: Int, property: Int, location: SourceLocation) -> RuntimeError {
        return RuntimeError(.invalidPropertyAccess(objectId: objectId, property: property), location: location)
    }

    /// Creates a corrupted story file error.
    public static func corruptedStoryFile(_ message: String, location: SourceLocation) -> RuntimeError {
        return RuntimeError(.corruptedStoryFile(message), location: location)
    }

    /// Creates an unsupported operation error.
    public static func unsupportedOperation(_ operation: String, location: SourceLocation) -> RuntimeError {
        return RuntimeError(.unsupportedOperation(operation), location: location)
    }

    public var message: String {
        switch code {
        case .invalidMemoryAccess(let address):
            return "invalid memory access at address \(address)"
        case .stackUnderflow:
            return "stack underflow"
        case .stackOverflow:
            return "stack overflow"
        case .divisionByZero:
            return "division by zero"
        case .invalidObjectAccess(let objectId):
            return "invalid object access: object \(objectId)"
        case .invalidPropertyAccess(let objectId, let property):
            return "invalid property access: object \(objectId), property \(property)"
        case .corruptedStoryFile(let msg):
            return "corrupted story file: \(msg)"
        case .unsupportedOperation(let operation):
            return "unsupported operation: \(operation)"
        }
    }

    public var severity: ErrorSeverity {
        switch code {
        case .invalidMemoryAccess, .stackUnderflow, .stackOverflow, .divisionByZero, .invalidObjectAccess, .invalidPropertyAccess:
            return .error
        case .corruptedStoryFile:
            return .fatal
        case .unsupportedOperation:
            return .warning
        }
    }

    public var description: String {
        return "\(location): \(severity): \(message)"
    }
}

/// Errors related to file I/O and file system operations.
///
/// `FileError` represents various file system related issues that can occur
/// during ZIL compilation, including missing files, permission problems,
/// and read/write failures.
public struct FileError: ZILError {
    /// The source location where this error occurred
    public let location: SourceLocation

    /// The specific error code and associated data
    let code: ErrorCode

    /// Specific error codes for file errors
    enum ErrorCode: Sendable, Equatable {
        /// A required file could not be found
        case fileNotFound(String)

        /// Access to a file was denied due to permissions
        case permissionDenied(String)

        /// An invalid file path was provided
        case invalidPath(String)

        /// An error occurred while reading a file
        case readError(path: String, underlying: String)

        /// An error occurred while writing a file
        case writeError(path: String, underlying: String)
    }

    private init(_ code: ErrorCode, location: SourceLocation) {
        self.code = code
        self.location = location
    }

    // MARK: - Static Factory Methods

    /// Creates a file not found error.
    public static func fileNotFound(_ path: String, location: SourceLocation) -> FileError {
        return FileError(.fileNotFound(path), location: location)
    }

    /// Creates a permission denied error.
    public static func permissionDenied(_ path: String, location: SourceLocation) -> FileError {
        return FileError(.permissionDenied(path), location: location)
    }

    /// Creates an invalid path error.
    public static func invalidPath(_ path: String, location: SourceLocation) -> FileError {
        return FileError(.invalidPath(path), location: location)
    }

    /// Creates a read error.
    public static func readError(path: String, underlying: Error, location: SourceLocation) -> FileError {
        return FileError(.readError(path: path, underlying: underlying.localizedDescription), location: location)
    }

    /// Creates a write error.
    public static func writeError(path: String, underlying: Error, location: SourceLocation) -> FileError {
        return FileError(.writeError(path: path, underlying: underlying.localizedDescription), location: location)
    }

    public var message: String {
        switch code {
        case .fileNotFound(let path):
            return "file not found: '\(path)'"
        case .permissionDenied(let path):
            return "permission denied: '\(path)'"
        case .invalidPath(let path):
            return "invalid path: '\(path)'"
        case .readError(let path, let error):
            return "failed to read '\(path)': \(error)"
        case .writeError(let path, let error):
            return "failed to write '\(path)': \(error)"
        }
    }

    public var severity: ErrorSeverity {
        return .error
    }

    public var description: String {
        return "\(location): \(severity): \(message)"
    }
}