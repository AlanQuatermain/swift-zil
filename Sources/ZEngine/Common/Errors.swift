import Foundation

/// Base error type for all ZIL-related errors
public protocol ZILError: Error, CustomStringConvertible {
    /// The source location where this error occurred
    var location: SourceLocation? { get }

    /// A human-readable description of the error
    var message: String { get }

    /// Error severity level
    var severity: ErrorSeverity { get }
}

/// Error severity levels
public enum ErrorSeverity: Sendable {
    case warning
    case error
    case fatal

    public var description: String {
        switch self {
        case .warning: return "warning"
        case .error: return "error"
        case .fatal: return "fatal error"
        }
    }
}

/// Compilation and parsing errors
public enum ParseError: ZILError {
    case unexpectedToken(expected: String, found: String, location: SourceLocation)
    case unexpectedEndOfFile(location: SourceLocation)
    case invalidSyntax(message: String, location: SourceLocation)
    case undefinedSymbol(name: String, location: SourceLocation)
    case duplicateDefinition(name: String, location: SourceLocation, originalLocation: SourceLocation)
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

/// Z-Machine assembly errors
public enum AssemblyError: ZILError {
    case invalidInstruction(name: String, location: SourceLocation)
    case invalidOperand(instruction: String, operand: String, location: SourceLocation)
    case undefinedLabel(name: String, location: SourceLocation)
    case addressOutOfRange(address: Int, location: SourceLocation)
    case memoryLayoutError(message: String, location: SourceLocation)
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

/// Z-Machine runtime errors
public enum RuntimeError: ZILError {
    case invalidMemoryAccess(address: Int, location: SourceLocation?)
    case stackUnderflow(location: SourceLocation?)
    case stackOverflow(location: SourceLocation?)
    case divisionByZero(location: SourceLocation?)
    case invalidObjectAccess(objectId: Int, location: SourceLocation?)
    case invalidPropertyAccess(objectId: Int, property: Int, location: SourceLocation?)
    case corruptedStoryFile(message: String, location: SourceLocation?)
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

/// File I/O and system errors
public enum FileError: ZILError {
    case fileNotFound(path: String, location: SourceLocation?)
    case permissionDenied(path: String, location: SourceLocation?)
    case invalidPath(path: String, location: SourceLocation?)
    case readError(path: String, underlying: Error, location: SourceLocation?)
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