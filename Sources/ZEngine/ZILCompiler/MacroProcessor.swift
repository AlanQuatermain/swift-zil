import Foundation
import Synchronization

/// Represents a ZIL macro definition with parameters and body
public struct ZILMacroDefinition: Sendable, Equatable {
    /// The name of the macro
    public let name: String

    /// Parameter names for the macro
    public let parameters: [String]

    /// The body expression of the macro (template to expand)
    public let body: ZILExpression

    /// Source location where the macro was defined
    public let definition: SourceLocation

    /// Whether this is a built-in macro or user-defined
    public let isBuiltIn: Bool

    public init(
        name: String,
        parameters: [String],
        body: ZILExpression,
        definition: SourceLocation,
        isBuiltIn: Bool = false
    ) {
        self.name = name
        self.parameters = parameters
        self.body = body
        self.definition = definition
        self.isBuiltIn = isBuiltIn
    }
}

/// Represents the result of macro expansion
public enum MacroExpansionResult: Sendable, Equatable {
    case success(ZILExpression)
    case error(MacroDiagnostic)
}

/// Macro-related diagnostic messages
public struct MacroDiagnostic: Sendable, Equatable {
    public enum Code: Sendable, Equatable {
        case undefinedMacro(name: String)
        case argumentCountMismatch(expected: Int, got: Int)
        case recursiveExpansion(macroName: String, expansionChain: [String])
        case variableCapture(variable: String, inMacro: String)
        case expansionError(message: String)
    }

    public let code: Code
    public let location: SourceLocation

    public init(code: Code, location: SourceLocation) {
        self.code = code
        self.location = location
    }

    public var message: String {
        switch code {
        case .undefinedMacro(let name):
            return "Undefined macro '\(name)'"
        case .argumentCountMismatch(let expected, let got):
            return "Macro argument count mismatch: expected \(expected), got \(got)"
        case .recursiveExpansion(let macroName, let chain):
            return "Recursive macro expansion detected: \(macroName) -> \(chain.joined(separator: " -> "))"
        case .variableCapture(let variable, let inMacro):
            return "Variable '\(variable)' captured by macro '\(inMacro)' - use hygiene system"
        case .expansionError(let message):
            return "Macro expansion error: \(message)"
        }
    }
}

/// Manages ZIL macro definitions, expansion, and hygiene
public final class MacroProcessor: Sendable {

    /// Protected state managed by a single mutex
    private struct State: ~Copyable {
        /// All defined macros by name
        var macros: [String: ZILMacroDefinition] = [:]

        /// Expansion stack to detect recursion
        var expansionStack: [String] = []

        /// Generated hygiene variable counter
        var hygieneCounter: Int = 0

        /// Diagnostics for macro-related errors
        var diagnostics: [MacroDiagnostic] = []

        /// Debug trace of macro expansions for development
        var expansionTrace: [MacroExpansionTrace] = []

        /// Whether debug tracing is enabled
        var debugTracing: Bool = false
    }

    private let state: Mutex<State>

    public init() {
        self.state = Mutex(State())
        initializeBuiltInMacros()
    }

    /// Define a new macro
    public func defineMacro(
        name: String,
        parameters: [String],
        body: ZILExpression,
        at location: SourceLocation
    ) -> Bool {
        return state.withLock { state in
            // Check for redefinition of built-in macros
            if let existing = state.macros[name], existing.isBuiltIn {
                let diagnostic = MacroDiagnostic(
                    code: .expansionError(message: "Cannot redefine built-in macro '\(name)'"),
                    location: location
                )
                state.diagnostics.append(diagnostic)
                return false
            }

            let macro = ZILMacroDefinition(
                name: name,
                parameters: parameters,
                body: body,
                definition: location
            )

            state.macros[name] = macro
            return true
        }
    }

    /// Look up a macro definition
    public func getMacro(name: String) -> ZILMacroDefinition? {
        return state.withLock { state in
            state.macros[name]
        }
    }

    /// Expand a macro call with given arguments
    public func expandMacro(
        name: String,
        arguments: [ZILExpression],
        at location: SourceLocation
    ) -> MacroExpansionResult {
        return state.withLock { state in
            // Check for macro definition
            guard let macro = state.macros[name] else {
                let diagnostic = MacroDiagnostic(
                    code: .undefinedMacro(name: name),
                    location: location
                )
                state.diagnostics.append(diagnostic)
                return .error(diagnostic)
            }

            // Check argument count
            guard arguments.count == macro.parameters.count else {
                let diagnostic = MacroDiagnostic(
                    code: .argumentCountMismatch(expected: macro.parameters.count, got: arguments.count),
                    location: location
                )
                state.diagnostics.append(diagnostic)
                return .error(diagnostic)
            }

            // Check for recursive expansion
            if state.expansionStack.contains(name) {
                let diagnostic = MacroDiagnostic(
                    code: .recursiveExpansion(macroName: name, expansionChain: state.expansionStack + [name]),
                    location: location
                )
                state.diagnostics.append(diagnostic)
                return .error(diagnostic)
            }

            // Add to expansion stack
            state.expansionStack.append(name)
            defer {
                state.expansionStack.removeLast()
            }

            // Create parameter substitution map
            var substitutions: [String: ZILExpression] = [:]
            for (parameter, argument) in zip(macro.parameters, arguments) {
                substitutions[parameter] = argument
            }

            // Perform expansion with direct substitution (ZIL style)
            let expandedBody = expandExpressionWithSubstitution(
                macro.body,
                substitutions: substitutions
            )

            // Add to trace if debugging
            if state.debugTracing {
                let trace = MacroExpansionTrace(
                    macroName: name,
                    arguments: arguments,
                    expandedResult: expandedBody,
                    location: location
                )
                state.expansionTrace.append(trace)
            }

            return .success(expandedBody)
        }
    }

    /// Expand a macro call with given arguments (internal, assumes mutex already held)
    private func expandMacroInternal(
        name: String,
        arguments: [ZILExpression],
        at location: SourceLocation,
        state: inout State
    ) -> MacroExpansionResult {
        // Check for macro definition
        guard let macro = state.macros[name] else {
            let diagnostic = MacroDiagnostic(
                code: .undefinedMacro(name: name),
                location: location
            )
            state.diagnostics.append(diagnostic)
            return .error(diagnostic)
        }

        // Check argument count
        guard arguments.count == macro.parameters.count else {
            let diagnostic = MacroDiagnostic(
                code: .argumentCountMismatch(expected: macro.parameters.count, got: arguments.count),
                location: location
            )
            state.diagnostics.append(diagnostic)
            return .error(diagnostic)
        }

        // Check for recursive expansion
        if state.expansionStack.contains(name) {
            let diagnostic = MacroDiagnostic(
                code: .recursiveExpansion(macroName: name, expansionChain: state.expansionStack + [name]),
                location: location
            )
            state.diagnostics.append(diagnostic)
            return .error(diagnostic)
        }

        // Add to expansion stack
        state.expansionStack.append(name)
        defer {
            state.expansionStack.removeLast()
        }

        // Create parameter substitution map
        var substitutions: [String: ZILExpression] = [:]
        for (parameter, argument) in zip(macro.parameters, arguments) {
            substitutions[parameter] = argument
        }

        // Perform expansion with direct substitution (ZIL style)
        let expandedBody = expandExpressionWithSubstitution(
            macro.body,
            substitutions: substitutions
        )

        // Add to trace if debugging
        if state.debugTracing {
            let trace = MacroExpansionTrace(
                macroName: name,
                arguments: arguments,
                expandedResult: expandedBody,
                location: location
            )
            state.expansionTrace.append(trace)
        }

        return .success(expandedBody)
    }

    /// Recursively expand all macros in an expression
    public func expandExpression(_ expr: ZILExpression) -> ZILExpression {
        return state.withLock { state in
            expandExpressionRecursive(expr, state: &state)
        }
    }

    /// Get all diagnostics
    public func getDiagnostics() -> [MacroDiagnostic] {
        return state.withLock { state in
            state.diagnostics
        }
    }

    /// Clear all diagnostics
    public func clearDiagnostics() {
        state.withLock { state in
            state.diagnostics.removeAll()
        }
    }

    /// Enable or disable debug tracing
    public func setDebugTracing(_ enabled: Bool) {
        state.withLock { state in
            state.debugTracing = enabled
            if !enabled {
                state.expansionTrace.removeAll()
            }
        }
    }

    /// Get expansion trace (for debugging)
    public func getExpansionTrace() -> [MacroExpansionTrace] {
        return state.withLock { state in
            state.expansionTrace
        }
    }

    /// Get all defined macros
    public func getAllMacros() -> [ZILMacroDefinition] {
        return state.withLock { state in
            Array(state.macros.values)
        }
    }

    // MARK: - Private Implementation

    /// Expand expression with parameter substitution (no hygiene - ZIL uses direct substitution)
    private func expandExpressionWithSubstitution(
        _ expr: ZILExpression,
        substitutions: [String: ZILExpression]
    ) -> ZILExpression {
        switch expr {
        case .atom(let name, _):
            // Direct parameter substitution only
            return substitutions[name] ?? expr

        case .localVariable(let name, _):
            // Both local variables and macro parameters (.PARAM) use this case
            return substitutions[name] ?? expr

        case .list(let elements, let location):
            let expandedElements = elements.map { element in
                expandExpressionWithSubstitution(element, substitutions: substitutions)
            }
            return .list(expandedElements, location)

        default:
            // For other expression types, return as-is (no nested substitution needed)
            return expr
        }
    }

    /// Recursively expand macros in expressions
    private func expandExpressionRecursive(_ expr: ZILExpression, state: inout State) -> ZILExpression {
        switch expr {
        case .list(let elements, let location):
            // Check if this is a macro call
            if let firstElement = elements.first,
               case .atom(let name, _) = firstElement,
               state.macros[name] != nil {
                // Check if this macro is already being expanded (recursion detection)
                if state.expansionStack.contains(name) {
                    // Recursive expansion detected - return original expression to break the cycle
                    return expr
                }

                // This is a macro call - expand it manually to maintain stack control
                let arguments = Array(elements.dropFirst())

                // Check for macro definition
                guard let macro = state.macros[name] else {
                    return expr
                }

                // Check argument count
                guard arguments.count == macro.parameters.count else {
                    return expr
                }

                // Add to expansion stack
                state.expansionStack.append(name)
                defer {
                    state.expansionStack.removeLast()
                }

                // Create parameter substitution map
                var substitutions: [String: ZILExpression] = [:]
                for (parameter, argument) in zip(macro.parameters, arguments) {
                    substitutions[parameter] = argument
                }

                // Perform expansion with direct substitution
                let expandedBody = expandExpressionWithSubstitution(
                    macro.body,
                    substitutions: substitutions
                )

                // Recursively expand the result while keeping this macro on the stack
                return expandExpressionRecursive(expandedBody, state: &state)
            } else {
                // Not a macro call, recursively expand elements
                let expandedElements = elements.map { element in
                    expandExpressionRecursive(element, state: &state)
                }
                return .list(expandedElements, location)
            }

        default:
            // Other expression types don't contain macros
            return expr
        }
    }

    /// Initialize built-in ZIL macros (ZIL has no built-in macros by default)
    private func initializeBuiltInMacros() {
        // ZIL does not have built-in macros like IF, WHEN, UNLESS
        // These would be defined by individual games if needed
        // Leave this empty or define game-specific macros elsewhere
    }
}

/// Debug trace of macro expansion for development
public struct MacroExpansionTrace: Sendable, Equatable {
    public let macroName: String
    public let arguments: [ZILExpression]
    public let expandedResult: ZILExpression
    public let location: SourceLocation

    public init(macroName: String, arguments: [ZILExpression], expandedResult: ZILExpression, location: SourceLocation) {
        self.macroName = macroName
        self.arguments = arguments
        self.expandedResult = expandedResult
        self.location = location
    }
}