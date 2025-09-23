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
    /// The source location where this error occurred, if available
    var location: SourceLocation? { get }

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
public enum ParseError: ZILError {
    /// An unexpected token was encountered during parsing
    case unexpectedToken(expected: String, found: String, location: SourceLocation)

    /// The source file ended unexpectedly
    case unexpectedEndOfFile(location: SourceLocation)

    /// Invalid ZIL syntax was encountered
    case invalidSyntax(message: String, location: SourceLocation)

    /// Reference to an undefined symbol
    case undefinedSymbol(name: String, location: SourceLocation)

    /// A symbol was defined more than once
    case duplicateDefinition(name: String, location: SourceLocation, originalLocation: SourceLocation)

    /// A type-related error occurred
    case typeError(message: String, location: SourceLocation)

    public var location: SourceLocation? {
        switch self {
        case .unexpectedToken(_, _, let loc),
             .unexpectedEndOfFile(let loc),
             .invalidSyntax(_, let loc),
             .undefinedSymbol(_, let loc),
             .duplicateDefinition(_, let loc, _),
             .typeError(_, let loc):
            return loc
        }
    }

    public var message: String {
        switch self {
        case .unexpectedToken(let expected, let found, _):
            return "expected '\(expected)', found '\(found)'"
        case .unexpectedEndOfFile:
            return "unexpected end of file"
        case .invalidSyntax(let msg, _):
            return "invalid syntax: \(msg)"
        case .undefinedSymbol(let name, _):
            return "undefined symbol '\(name)'"
        case .duplicateDefinition(let name, _, let original):
            return "duplicate definition of '\(name)' (original at \(original))"
        case .typeError(let msg, _):
            return "type error: \(msg)"
        }
    }

    public var severity: ErrorSeverity {
        switch self {
        case .unexpectedToken, .unexpectedEndOfFile, .invalidSyntax, .undefinedSymbol, .duplicateDefinition, .typeError:
            return .error
        }
    }

    public var description: String {
        if let loc = location {
            return "\(loc): \(severity): \(message)"
        } else {
            return "\(severity): \(message)"
        }
    }
}

/// Errors that occur during Z-Machine assembly and bytecode generation.
///
/// `AssemblyError` represents issues encountered while converting ZAP assembly
/// language into Z-Machine bytecode, including invalid instructions, operands,
/// and version compatibility problems.
public enum AssemblyError: ZILError {
    /// An invalid or unrecognized instruction was encountered
    case invalidInstruction(name: String, location: SourceLocation)

    /// An invalid operand was provided for an instruction
    case invalidOperand(instruction: String, operand: String, location: SourceLocation)

    /// Reference to an undefined label
    case undefinedLabel(name: String, location: SourceLocation)

    /// A memory address is out of the valid range
    case addressOutOfRange(address: Int, location: SourceLocation)

    /// An error occurred in memory layout or organization
    case memoryLayoutError(message: String, location: SourceLocation)

    /// An instruction is not available in the target Z-Machine version
    case versionMismatch(instruction: String, version: Int, location: SourceLocation)

    public var location: SourceLocation? {
        switch self {
        case .invalidInstruction(_, let loc),
             .invalidOperand(_, _, let loc),
             .undefinedLabel(_, let loc),
             .addressOutOfRange(_, let loc),
             .memoryLayoutError(_, let loc),
             .versionMismatch(_, _, let loc):
            return loc
        }
    }

    public var message: String {
        switch self {
        case .invalidInstruction(let name, _):
            return "invalid instruction '\(name)'"
        case .invalidOperand(let instruction, let operand, _):
            return "invalid operand '\(operand)' for instruction '\(instruction)'"
        case .undefinedLabel(let name, _):
            return "undefined label '\(name)'"
        case .addressOutOfRange(let address, _):
            return "address \(address) out of range"
        case .memoryLayoutError(let msg, _):
            return "memory layout error: \(msg)"
        case .versionMismatch(let instruction, let version, _):
            return "instruction '\(instruction)' not available in Z-Machine version \(version)"
        }
    }

    public var severity: ErrorSeverity {
        switch self {
        case .invalidInstruction, .invalidOperand, .undefinedLabel, .addressOutOfRange, .memoryLayoutError, .versionMismatch:
            return .error
        }
    }

    public var description: String {
        if let loc = location {
            return "\(loc): \(severity): \(message)"
        } else {
            return "\(severity): \(message)"
        }
    }
}

/// Errors that occur during Z-Machine virtual machine execution.
///
/// `RuntimeError` represents various runtime failures that can happen while
/// executing Z-Machine bytecode, including memory access violations, stack
/// operations, and corrupted story files.
public enum RuntimeError: ZILError {
    /// An attempt to access invalid memory location
    case invalidMemoryAccess(address: Int, location: SourceLocation?)

    /// Stack underflow occurred (pop from empty stack)
    case stackUnderflow(location: SourceLocation?)

    /// Stack overflow occurred (too many items pushed)
    case stackOverflow(location: SourceLocation?)

    /// Division by zero was attempted
    case divisionByZero(location: SourceLocation?)

    /// An attempt to access an invalid object
    case invalidObjectAccess(objectId: Int, location: SourceLocation?)

    /// An attempt to access an invalid object property
    case invalidPropertyAccess(objectId: Int, property: Int, location: SourceLocation?)

    /// The story file is corrupted or invalid
    case corruptedStoryFile(message: String, location: SourceLocation?)

    /// An unsupported operation was requested
    case unsupportedOperation(operation: String, location: SourceLocation?)

    public var location: SourceLocation? {
        switch self {
        case .invalidMemoryAccess(_, let loc),
             .stackUnderflow(let loc),
             .stackOverflow(let loc),
             .divisionByZero(let loc),
             .invalidObjectAccess(_, let loc),
             .invalidPropertyAccess(_, _, let loc),
             .corruptedStoryFile(_, let loc),
             .unsupportedOperation(_, let loc):
            return loc
        }
    }

    public var message: String {
        switch self {
        case .invalidMemoryAccess(let address, _):
            return "invalid memory access at address \(address)"
        case .stackUnderflow:
            return "stack underflow"
        case .stackOverflow:
            return "stack overflow"
        case .divisionByZero:
            return "division by zero"
        case .invalidObjectAccess(let objectId, _):
            return "invalid object access: object \(objectId)"
        case .invalidPropertyAccess(let objectId, let property, _):
            return "invalid property access: object \(objectId), property \(property)"
        case .corruptedStoryFile(let msg, _):
            return "corrupted story file: \(msg)"
        case .unsupportedOperation(let operation, _):
            return "unsupported operation: \(operation)"
        }
    }

    public var severity: ErrorSeverity {
        switch self {
        case .invalidMemoryAccess, .stackUnderflow, .stackOverflow, .divisionByZero, .invalidObjectAccess, .invalidPropertyAccess:
            return .error
        case .corruptedStoryFile:
            return .fatal
        case .unsupportedOperation:
            return .warning
        }
    }

    public var description: String {
        if let loc = location {
            return "\(loc): \(severity): \(message)"
        } else {
            return "\(severity): \(message)"
        }
    }
}

/// Errors related to file I/O and file system operations.
///
/// `FileError` represents various file system related issues that can occur
/// during ZIL compilation, including missing files, permission problems,
/// and read/write failures.
public enum FileError: ZILError {
    /// A required file could not be found
    case fileNotFound(path: String, location: SourceLocation?)

    /// Access to a file was denied due to permissions
    case permissionDenied(path: String, location: SourceLocation?)

    /// An invalid file path was provided
    case invalidPath(path: String, location: SourceLocation?)

    /// An error occurred while reading a file
    case readError(path: String, underlying: Error, location: SourceLocation?)

    /// An error occurred while writing a file
    case writeError(path: String, underlying: Error, location: SourceLocation?)

    public var location: SourceLocation? {
        switch self {
        case .fileNotFound(_, let loc),
             .permissionDenied(_, let loc),
             .invalidPath(_, let loc),
             .readError(_, _, let loc),
             .writeError(_, _, let loc):
            return loc
        }
    }

    public var message: String {
        switch self {
        case .fileNotFound(let path, _):
            return "file not found: '\(path)'"
        case .permissionDenied(let path, _):
            return "permission denied: '\(path)'"
        case .invalidPath(let path, _):
            return "invalid path: '\(path)'"
        case .readError(let path, let error, _):
            return "failed to read '\(path)': \(error.localizedDescription)"
        case .writeError(let path, let error, _):
            return "failed to write '\(path)': \(error.localizedDescription)"
        }
    }

    public var severity: ErrorSeverity {
        switch self {
        case .fileNotFound, .permissionDenied, .invalidPath, .readError, .writeError:
            return .error
        }
    }

    public var description: String {
        if let loc = location {
            return "\(loc): \(severity): \(message)"
        } else {
            return "\(severity): \(message)"
        }
    }
}