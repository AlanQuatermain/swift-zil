//===----------------------------------------------------------------------===//
//
// ZILLogger.swift - Centralized logging configuration for ZIL tools
//
// This source file is part of the swift-zil open source project
//
//===----------------------------------------------------------------------===//

import Logging
import Foundation

/// Centralized logging configuration for ZIL compilation tools
public enum ZILLogger {

    /// Initialize the logging system with stderr output
    /// This should be called once at application startup
    /// - Parameter logLevel: The minimum log level to output (default: .notice)
    public static func bootstrap(logLevel: Logger.Level = .notice) {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = logLevel
            return handler
        }
    }

    /// Configure logging from environment variable ZIL_LOG_LEVEL
    /// Valid values: trace, debug, info, notice, warning, error, critical
    /// Defaults to .notice if not set or invalid
    public static func bootstrapFromEnvironment() {
        let envLogLevel = ProcessInfo.processInfo.environment["ZIL_LOG_LEVEL"]
        let logLevel = parseLogLevel(envLogLevel) ?? .notice
        bootstrap(logLevel: logLevel)
    }

    /// Create a logger for a specific subsystem
    /// - Parameter subsystem: The subsystem name (e.g., "compiler", "assembler", "vm")
    /// - Returns: Configured logger instance
    public static func logger(for subsystem: String) -> Logger {
        Logger(label: "com.zil.\(subsystem)")
    }

    /// Parse log level from string
    private static func parseLogLevel(_ string: String?) -> Logger.Level? {
        guard let string = string?.lowercased() else { return nil }

        switch string {
        case "trace": return .trace
        case "debug": return .debug
        case "info": return .info
        case "notice": return .notice
        case "warning": return .warning
        case "error": return .error
        case "critical": return .critical
        default: return nil
        }
    }
}

// MARK: - Convenience loggers for common subsystems

extension ZILLogger {
    /// Logger for ZIL compiler operations
    public static let compiler = logger(for: "compiler")

    /// Logger for Z-Machine assembler operations
    public static let assembler = logger(for: "assembler")

    /// Logger for Z-Machine VM operations
    public static let vm = logger(for: "vm")

    /// Logger for lexical analysis
    public static let lexer = logger(for: "lexer")

    /// Logger for parsing operations
    public static let parser = logger(for: "parser")

    /// Logger for semantic analysis
    public static let semantic = logger(for: "semantic")

    /// Logger for code generation
    public static let codegen = logger(for: "codegen")
}