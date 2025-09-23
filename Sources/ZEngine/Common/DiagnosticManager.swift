import Foundation

/// Manages collection and reporting of diagnostic messages during compilation.
///
/// `DiagnosticManager` serves as a central repository for all errors, warnings,
/// and other diagnostic messages generated during ZIL compilation, assembly, and
/// execution. It provides methods to add diagnostics, query their status, and
/// format them for display.
///
/// ## Usage Example
/// ```swift
/// let manager = DiagnosticManager()
/// let error = ParseError.undefinedSymbol(name: "MISSING", location: location)
/// manager.add(error)
///
/// if manager.hasErrors {
///     manager.printDiagnostics(colorOutput: true)
/// }
/// ```
///
/// ## Thread Safety
/// This class is not thread-safe. Use appropriate synchronization if accessing
/// from multiple threads.
public class DiagnosticManager {
    /// Internal storage for all collected diagnostics
    private var diagnostics: [any ZILError] = []

    /// Indicates whether any fatal errors have been recorded
    public var hasFatalErrors: Bool {
        return diagnostics.contains { $0.severity == .fatal }
    }

    /// Indicates whether any errors (including fatal) have been recorded
    public var hasErrors: Bool {
        return diagnostics.contains { $0.severity == .error || $0.severity == .fatal }
    }

    /// Indicates whether any warnings have been recorded
    public var hasWarnings: Bool {
        return diagnostics.contains { $0.severity == .warning }
    }

    /// The total number of diagnostics recorded
    public var count: Int {
        return diagnostics.count
    }

    /// The number of errors (including fatal errors)
    public var errorCount: Int {
        return diagnostics.filter { $0.severity == .error || $0.severity == .fatal }.count
    }

    /// The number of warnings
    public var warningCount: Int {
        return diagnostics.filter { $0.severity == .warning }.count
    }

    /// Creates a new empty diagnostic manager
    public init() {}

    /// Adds a single diagnostic to the collection.
    ///
    /// - Parameter error: The diagnostic error to add
    public func add<T: ZILError>(_ error: T) {
        diagnostics.append(error)
    }

    /// Adds multiple diagnostics to the collection.
    ///
    /// - Parameter errors: The array of diagnostic errors to add
    public func add<T: ZILError>(contentsOf errors: [T]) {
        diagnostics.append(contentsOf: errors)
    }

    /// Removes all diagnostics from the collection
    public func clear() {
        diagnostics.removeAll()
    }

    /// Returns all collected diagnostics.
    ///
    /// - Returns: An array containing all diagnostics in the order they were added
    public func allDiagnostics() -> [any ZILError] {
        return diagnostics
    }

    /// Returns diagnostics filtered by severity level.
    ///
    /// - Parameter severity: The severity level to filter by
    /// - Returns: An array of diagnostics matching the specified severity
    public func diagnostics(withSeverity severity: ErrorSeverity) -> [any ZILError] {
        return diagnostics.filter { $0.severity == severity }
    }

    /// Returns diagnostics for a specific source file.
    ///
    /// - Parameter file: The filename to filter by
    /// - Returns: An array of diagnostics from the specified file
    public func diagnostics(forFile file: String) -> [any ZILError] {
        return diagnostics.filter { $0.location?.file == file }
    }

    /// Returns all diagnostics sorted by their source location.
    ///
    /// Diagnostics are sorted first by file name, then by line and column number.
    /// Diagnostics without source locations are placed at the end.
    ///
    /// - Returns: An array of diagnostics sorted by source location
    public func sortedDiagnostics() -> [any ZILError] {
        return diagnostics.sorted { error1, error2 in
            guard let loc1 = error1.location, let loc2 = error2.location else {
                // Errors without location go to the end
                return error1.location != nil && error2.location == nil
            }
            return loc1 < loc2
        }
    }

    /// Formats all diagnostics as a multi-line string for display.
    ///
    /// - Parameter colorOutput: Whether to include ANSI color codes for terminal display
    /// - Returns: A formatted string containing all diagnostics
    public func formatDiagnostics(colorOutput: Bool = false) -> String {
        let sorted = sortedDiagnostics()
        return sorted.map { diagnostic in
            formatDiagnostic(diagnostic, colorOutput: colorOutput)
        }.joined(separator: "\n")
    }

    /// Formats a single diagnostic for display.
    ///
    /// - Parameters:
    ///   - diagnostic: The diagnostic to format
    ///   - colorOutput: Whether to include ANSI color codes for terminal display
    /// - Returns: A formatted string representation of the diagnostic
    public func formatDiagnostic(_ diagnostic: any ZILError, colorOutput: Bool = false) -> String {
        if colorOutput {
            return formatDiagnosticWithColor(diagnostic)
        } else {
            return diagnostic.description
        }
    }

    /// Format diagnostic with ANSI color codes
    private func formatDiagnosticWithColor(_ diagnostic: any ZILError) -> String {
        let colorCode: String
        switch diagnostic.severity {
        case .warning:
            colorCode = "\u{001B}[33m" // Yellow
        case .error:
            colorCode = "\u{001B}[31m" // Red
        case .fatal:
            colorCode = "\u{001B}[91m" // Bright red
        }
        let resetCode = "\u{001B}[0m"

        if let location = diagnostic.location {
            return "\(location): \(colorCode)\(diagnostic.severity)\(resetCode): \(diagnostic.message)"
        } else {
            return "\(colorCode)\(diagnostic.severity)\(resetCode): \(diagnostic.message)"
        }
    }

    /// Prints all diagnostics to standard error.
    ///
    /// - Parameter colorOutput: Whether to include ANSI color codes for terminal display
    public func printDiagnostics(colorOutput: Bool = false) {
        let output = formatDiagnostics(colorOutput: colorOutput)
        if !output.isEmpty {
            fputs(output + "\n", stderr)
        }
    }

    /// Prints a summary of diagnostic counts to standard error.
    ///
    /// The summary includes the total number of errors and warnings in a format
    /// suitable for command-line tools.
    public func printSummary() {
        let errors = errorCount
        let warnings = warningCount

        var parts: [String] = []
        if errors > 0 {
            parts.append("\(errors) error\(errors == 1 ? "" : "s")")
        }
        if warnings > 0 {
            parts.append("\(warnings) warning\(warnings == 1 ? "" : "s")")
        }

        if !parts.isEmpty {
            let summary = parts.joined(separator: ", ") + " generated"
            fputs(summary + "\n", stderr)
        }
    }
}

/// Utility functions for enhanced error handling and reporting.
///
/// `ErrorUtils` provides static methods for formatting errors with source context,
/// generating fix suggestions, and creating user-friendly error messages.
public enum ErrorUtils {
    /// Creates a user-friendly error message with source code context.
    ///
    /// This method enhances error messages by showing the relevant source code lines
    /// around the error location, with a caret (^) pointing to the exact column.
    ///
    /// - Parameters:
    ///   - error: The error to format
    ///   - sourceText: Optional source code text to provide context
    ///   - contextLines: Number of lines to show before and after the error (default: 2)
    /// - Returns: A formatted error message with optional source context
    public static func formatErrorWithContext(
        _ error: any ZILError,
        sourceText: String? = nil,
        contextLines: Int = 2
    ) -> String {
        var result = error.description

        // Add source context if available
        if let location = error.location,
           let sourceText = sourceText {
            let lines = sourceText.components(separatedBy: .newlines)
            let errorLine = location.line - 1 // Convert to 0-based

            if errorLine >= 0 && errorLine < lines.count {
                result += "\n"

                // Add context lines before the error
                let startLine = max(0, errorLine - contextLines)
                let endLine = min(lines.count - 1, errorLine + contextLines)

                for i in startLine...endLine {
                    let lineNumber = i + 1
                    let lineText = lines[i]
                    let marker = i == errorLine ? ">" : " "
                    result += "\n\(marker) \(String(format: "%3d", lineNumber)) | \(lineText)"

                    // Add caret pointing to the error column
                    if i == errorLine {
                        let spaces = String(repeating: " ", count: location.column - 1 + 7) // Account for line number prefix
                        result += "\n       |\(spaces)^"
                    }
                }
            }
        }

        return result
    }

    /// Generates suggested fixes for common errors.
    ///
    /// This method analyzes the type and content of an error to provide
    /// actionable suggestions for fixing the issue.
    ///
    /// - Parameter error: The error to analyze
    /// - Returns: An array of suggested fix descriptions
    public static func suggestFixes(for error: any ZILError) -> [String] {
        switch error {
        case let parseError as ParseError:
            return suggestFixesForParseError(parseError)
        case let assemblyError as AssemblyError:
            return suggestFixesForAssemblyError(assemblyError)
        case let runtimeError as RuntimeError:
            return suggestFixesForRuntimeError(runtimeError)
        case let fileError as FileError:
            return suggestFixesForFileError(fileError)
        default:
            return []
        }
    }

    private static func suggestFixesForParseError(_ error: ParseError) -> [String] {
        switch error {
        case .unexpectedToken(let expected, let found, _):
            if expected == ">" && found == "EOF" {
                return ["Add missing '>' to close the expression"]
            }
            return ["Replace '\(found)' with '\(expected)'"]
        case .undefinedSymbol(let name, _):
            return ["Define '\(name)' before using it", "Check spelling of '\(name)'"]
        case .duplicateDefinition(let name, _, _):
            return ["Rename one of the '\(name)' definitions", "Remove the duplicate definition"]
        default:
            return []
        }
    }

    private static func suggestFixesForAssemblyError(_ error: AssemblyError) -> [String] {
        switch error {
        case .versionMismatch(let instruction, let version, _):
            return ["Use Z-Machine version 5 or later", "Replace '\(instruction)' with equivalent instruction for version \(version)"]
        case .undefinedLabel(let name, _):
            return ["Define label '\(name)'", "Check spelling of label '\(name)'"]
        default:
            return []
        }
    }

    private static func suggestFixesForRuntimeError(_ error: RuntimeError) -> [String] {
        switch error {
        case .divisionByZero:
            return ["Check divisor before division", "Add error handling for division operations"]
        case .stackOverflow:
            return ["Reduce recursion depth", "Check for infinite recursion"]
        default:
            return []
        }
    }

    private static func suggestFixesForFileError(_ error: FileError) -> [String] {
        switch error {
        case .fileNotFound(let path, _):
            return ["Check that '\(path)' exists", "Verify the file path is correct"]
        case .permissionDenied(let path, _):
            return ["Check file permissions for '\(path)'", "Run with appropriate privileges"]
        default:
            return []
        }
    }
}