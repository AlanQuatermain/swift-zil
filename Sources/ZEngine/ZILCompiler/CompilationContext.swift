import Foundation
import Synchronization

/// Central context managing compilation settings and directives
///
/// This class stores all compilation-time settings such as Z-Machine version,
/// ZIP options, ordering strategies, and file/routine flags. It uses Mutex
/// for thread-safe access and provides a single source of truth for all
/// compilation decisions.
public final class CompilationContext: Sendable {

    /// Protected state managed by a single mutex
    private struct State: ~Copyable {
        /// Target Z-Machine version (3-8)
        var zVersion: Int = 3

        /// Whether to use time-based status line (v3 only)
        var timeStatusLine: Bool = false

        /// ZIP options enabled
        var zipOptions: ZipOptions = []

        /// Object ordering strategy
        var objectOrdering: ObjectOrdering = .defined

        /// Tree ordering strategy
        var treeOrdering: TreeOrdering = .reverseDefined

        /// Flags to order last in the flag table
        var flagsOrderedLast: Set<String> = []

        /// File-level flags for current file context
        var currentFileFlags: FileFlags = []

        /// Routine-level flags for next routine definition
        var nextRoutineFlags: RoutineFlags = []

        /// Stack of file contexts for nested includes
        var fileContextStack: [FileContext] = []
    }

    private let state: Mutex<State>

    public init() {
        self.state = Mutex(State())
    }

    // MARK: - Version Management

    /// Set the target Z-Machine version
    ///
    /// - Parameter version: Version number (3-8)
    /// - Throws: `CompilationError.invalidVersion` if version is out of range
    public func setVersion(_ version: Int) throws {
        guard (3...8).contains(version) else {
            throw CompilationError.invalidVersion(version)
        }
        state.withLock { state in
            state.zVersion = version
        }
    }

    /// Get the current target Z-Machine version
    public func getVersion() -> Int {
        state.withLock { $0.zVersion }
    }

    /// Enable or disable time-based status line (v3 only)
    public func setTimeStatusLine(_ enabled: Bool) {
        state.withLock { $0.timeStatusLine = enabled }
    }

    /// Check if time-based status line is enabled
    public func hasTimeStatusLine() -> Bool {
        state.withLock { $0.timeStatusLine }
    }

    // MARK: - ZIP Options

    /// Add ZIP options to the current set
    public func addZipOptions(_ options: ZipOptions) {
        state.withLock { $0.zipOptions.formUnion(options) }
    }

    /// Check if a specific ZIP option is enabled
    public func hasZipOption(_ option: ZipOptions) -> Bool {
        state.withLock { $0.zipOptions.contains(option) }
    }

    /// Get all enabled ZIP options
    public func getZipOptions() -> ZipOptions {
        state.withLock { $0.zipOptions }
    }

    // MARK: - Object/Tree Ordering

    /// Set the object ordering strategy
    public func setObjectOrdering(_ ordering: ObjectOrdering) {
        state.withLock { $0.objectOrdering = ordering }
    }

    /// Get the current object ordering strategy
    public func getObjectOrdering() -> ObjectOrdering {
        state.withLock { $0.objectOrdering }
    }

    /// Set the tree ordering strategy
    public func setTreeOrdering(_ ordering: TreeOrdering) {
        state.withLock { $0.treeOrdering = ordering }
    }

    /// Get the current tree ordering strategy
    public func getTreeOrdering() -> TreeOrdering {
        state.withLock { $0.treeOrdering }
    }

    // MARK: - Flag Ordering

    /// Add flags that should be ordered last in the flag table
    public func addFlagsOrderedLast(_ flags: [String]) {
        state.withLock { $0.flagsOrderedLast.formUnion(flags) }
    }

    /// Check if a flag should be ordered last
    public func isFlagOrderedLast(_ flag: String) -> Bool {
        state.withLock { $0.flagsOrderedLast.contains(flag) }
    }

    /// Get all flags that should be ordered last
    public func getFlagsOrderedLast() -> Set<String> {
        state.withLock { $0.flagsOrderedLast }
    }

    // MARK: - File Context Management

    /// Push a new file context onto the stack
    ///
    /// This should be called when entering a new file (including via INSERT-FILE)
    public func pushFileContext(_ path: String, flags: FileFlags = []) {
        state.withLock { state in
            let context = FileContext(path: path, flags: flags)
            state.fileContextStack.append(context)
            state.currentFileFlags = flags
        }
    }

    /// Pop the current file context from the stack
    ///
    /// This should be called when leaving a file
    public func popFileContext() {
        state.withLock { state in
            _ = state.fileContextStack.popLast()
            state.currentFileFlags = state.fileContextStack.last?.flags ?? []
        }
    }

    /// Get the current file's flags
    public func getCurrentFileFlags() -> FileFlags {
        state.withLock { $0.currentFileFlags }
    }

    /// Get the current file path
    public func getCurrentFilePath() -> String? {
        state.withLock { $0.fileContextStack.last?.path }
    }

    // MARK: - Routine Flags

    /// Set flags for the next routine definition
    ///
    /// These flags will be consumed by the next routine that's parsed
    public func setNextRoutineFlags(_ flags: RoutineFlags) {
        state.withLock { $0.nextRoutineFlags = flags }
    }

    /// Consume and return flags for the current routine
    ///
    /// This combines routine-specific flags with inherited file flags,
    /// then clears the routine flags for the next routine
    public func consumeRoutineFlags() -> RoutineFlags {
        state.withLock { state in
            let combined = Self.combineFlags(
                fileFlags: state.currentFileFlags,
                routineFlags: state.nextRoutineFlags
            )
            state.nextRoutineFlags = []
            return combined
        }
    }

    // MARK: - Helper Methods

    /// Combine file-level and routine-level flags
    ///
    /// File flags can contribute to routine flags:
    /// - FileFlags.cleanStack → RoutineFlags.cleanStack
    /// - FileFlags.keepRoutines → RoutineFlags.keep
    /// - FileFlags.suppressUnusedWarnings → RoutineFlags.suppressUnused
    private static func combineFlags(fileFlags: FileFlags, routineFlags: RoutineFlags) -> RoutineFlags {
        var result = routineFlags

        if fileFlags.contains(.cleanStack) {
            result.insert(.cleanStack)
        }
        if fileFlags.contains(.keepRoutines) {
            result.insert(.keep)
        }
        if fileFlags.contains(.suppressUnusedWarnings) {
            result.insert(.suppressUnused)
        }

        return result
    }
}

// MARK: - Supporting Types

/// ZIP options that can be enabled for the story file
public struct ZipOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Color support (versions 5+)
    public static let color = ZipOptions(rawValue: 1 << 0)

    /// Mouse input support (versions 5+)
    public static let mouse = ZipOptions(rawValue: 1 << 1)

    /// Undo support (versions 5+)
    public static let undo = ZipOptions(rawValue: 1 << 2)

    /// Display/graphics support (versions 6+)
    public static let display = ZipOptions(rawValue: 1 << 3)

    /// Sound effects support (versions 4+)
    public static let sound = ZipOptions(rawValue: 1 << 4)

    /// Menu support (versions 6+)
    public static let menu = ZipOptions(rawValue: 1 << 5)

    /// Big game flag (indicates large game size)
    public static let big = ZipOptions(rawValue: 1 << 6)
}

/// Strategies for ordering objects in the object table
public enum ObjectOrdering: Sendable, Equatable {
    /// Order objects as they are defined in source
    case defined

    /// Place rooms first, then objects
    case roomsFirst

    /// Place rooms and local globals first
    case roomsAndLgsFirst

    /// Place objects first, then rooms
    case roomsLast
}

/// Strategies for ordering the object tree
public enum TreeOrdering: Sendable, Equatable {
    /// Reverse the order of definition
    case reverseDefined
}

/// File-level compilation flags
public struct FileFlags: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Clean stack on routine return
    public static let cleanStack = FileFlags(rawValue: 1 << 0)

    /// MDL-ZIL compatibility mode
    public static let mdlZil = FileFlags(rawValue: 1 << 1)

    /// Sentence ending punctuation handling
    public static let sentenceEnds = FileFlags(rawValue: 1 << 2)

    /// Keep all routines (prevent dead code elimination)
    public static let keepRoutines = FileFlags(rawValue: 1 << 3)

    /// Suppress unused routine warnings
    public static let suppressUnusedWarnings = FileFlags(rawValue: 1 << 4)

    /// Output ZAP files to source directory instead of output directory
    public static let zapToSourceDirectory = FileFlags(rawValue: 1 << 5)
}

/// Routine-level compilation flags
public struct RoutineFlags: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Clean stack on return
    public static let cleanStack = RoutineFlags(rawValue: 1 << 0)

    /// Keep routine (prevent dead code elimination)
    public static let keep = RoutineFlags(rawValue: 1 << 1)

    /// Suppress unused warning for this routine
    public static let suppressUnused = RoutineFlags(rawValue: 1 << 2)
}

/// Context information for a source file
public struct FileContext: Sendable, Equatable {
    /// Path to the source file
    public let path: String

    /// Flags active for this file
    public let flags: FileFlags

    public init(path: String, flags: FileFlags) {
        self.path = path
        self.flags = flags
    }
}

/// Errors that can occur during compilation
public enum CompilationError: Error, Equatable {
    /// Invalid Z-Machine version specified
    case invalidVersion(Int)

    /// Version mismatch between components
    case versionMismatch(expected: Int, actual: Int)

    /// Feature requires a higher version than currently targeted
    case unsupportedFeature(String, requiredVersion: Int)

    /// Invalid ZIP option name
    case invalidZipOption(String)

    /// Invalid file flag name
    case invalidFileFlag(String)

    /// Invalid routine flag name
    case invalidRoutineFlag(String)
}

extension CompilationError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidVersion(let version):
            return "Invalid Z-Machine version: \(version). Must be 3-8."
        case .versionMismatch(let expected, let actual):
            return "Version mismatch: expected v\(expected), got v\(actual)"
        case .unsupportedFeature(let feature, let requiredVersion):
            return "Feature '\(feature)' requires Z-Machine v\(requiredVersion) or later"
        case .invalidZipOption(let option):
            return "Invalid ZIP option: '\(option)'"
        case .invalidFileFlag(let flag):
            return "Invalid file flag: '\(flag)'"
        case .invalidRoutineFlag(let flag):
            return "Invalid routine flag: '\(flag)'"
        }
    }
}
