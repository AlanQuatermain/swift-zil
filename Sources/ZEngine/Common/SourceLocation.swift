import Foundation

/// Represents a location in source code for error reporting and debugging.
///
/// `SourceLocation` provides precise tracking of where errors, warnings, or other
/// diagnostics occur in ZIL source files. It includes file path, line number,
/// column number, and optional byte offset information.
///
/// ## Thread Safety
/// This struct conforms to `Sendable` and is safe to use across concurrent contexts.
///
/// ## Usage Example
/// ```swift
/// let location = SourceLocation(file: "game.zil", line: 42, column: 10)
/// print(location.description) // Prints: "game.zil:42:10"
/// ```
public struct SourceLocation: Sendable {
    /// The file path or name where this location occurs
    public let file: String

    /// The line number (1-based) within the file
    public let line: Int

    /// The column number (1-based) within the line
    public let column: Int

    /// Optional byte offset from the beginning of the file
    public let offset: Int?

    /// Creates a new source location.
    ///
    /// - Parameters:
    ///   - file: The file path or name where the location occurs
    ///   - line: The line number (1-based)
    ///   - column: The column number (1-based)
    ///   - offset: Optional byte offset from the beginning of the file
    public init(file: String, line: Int, column: Int, offset: Int? = nil) {
        self.file = file
        self.line = line
        self.column = column
        self.offset = offset
    }

    /// Creates a source location from a file URL.
    ///
    /// This convenience initializer extracts the last path component from the URL
    /// to use as the file name in the location.
    ///
    /// - Parameters:
    ///   - file: The file URL where the location occurs
    ///   - line: The line number (1-based)
    ///   - column: The column number (1-based)
    ///   - offset: Optional byte offset from the beginning of the file
    public init(file: URL, line: Int, column: Int, offset: Int? = nil) {
        self.init(file: file.lastPathComponent, line: line, column: column, offset: offset)
    }

    /// A placeholder source location for generated code that doesn't correspond to source files
    public static let generated = SourceLocation(file: "<generated>", line: 0, column: 0)

    /// A placeholder source location for unknown or unspecified source positions
    public static let unknown = SourceLocation(file: "<unknown>", line: 0, column: 0)
}

extension SourceLocation: CustomStringConvertible {
    public var description: String {
        return "\(file):\(line):\(column)"
    }
}

extension SourceLocation: Equatable {
    public static func == (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        return lhs.file == rhs.file &&
               lhs.line == rhs.line &&
               lhs.column == rhs.column
    }
}

extension SourceLocation: Comparable {
    public static func < (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        if lhs.file != rhs.file {
            return lhs.file < rhs.file
        }
        if lhs.line != rhs.line {
            return lhs.line < rhs.line
        }
        return lhs.column < rhs.column
    }
}

extension SourceLocation: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(file)
        hasher.combine(line)
        hasher.combine(column)
    }
}