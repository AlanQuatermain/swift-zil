import Foundation

/// Represents a location in source code with file, line, and column information
public struct SourceLocation: Sendable {
    /// The file path or name
    public let file: String
    /// The line number (1-based)
    public let line: Int
    /// The column number (1-based)
    public let column: Int
    /// Optional byte offset from start of file
    public let offset: Int?

    public init(file: String, line: Int, column: Int, offset: Int? = nil) {
        self.file = file
        self.line = line
        self.column = column
        self.offset = offset
    }

    /// Creates a source location from a file URL
    public init(file: URL, line: Int, column: Int, offset: Int? = nil) {
        self.init(file: file.lastPathComponent, line: line, column: column, offset: offset)
    }

    /// A placeholder source location for generated code
    public static let generated = SourceLocation(file: "<generated>", line: 0, column: 0)

    /// A placeholder source location for unknown origins
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