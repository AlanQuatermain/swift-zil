import Foundation
import Synchronization

/// Represents different types of symbols in ZIL programs
public enum SymbolType: Sendable, Equatable {
    /// Routine/function symbol with parameter information
    case routine(parameters: [String], optionalParameters: [String], auxiliaryVariables: [String])

    /// Object symbol with properties and flags
    case object(properties: [String], flags: [String])

    /// Global variable symbol
    case globalVariable

    /// Constant symbol with compile-time value
    case constant(value: ZILExpression)

    /// Local variable symbol (parameters and auxiliary variables)
    case localVariable

    /// Property definition symbol
    case property(defaultValue: ZILExpression?)

    /// Flag definition symbol
    case flag

    /// Macro definition symbol
    case macro(parameters: [ZILMacroParameter], body: ZILExpression)
}

/// Represents a symbol in the ZIL symbol table
public struct Symbol: Sendable, Equatable {
    /// The symbol's name
    public let name: String

    /// The type of symbol and associated metadata
    public let type: SymbolType

    /// The scope level where this symbol was defined (0 = global)
    public let scopeLevel: Int

    /// Source location where the symbol was defined
    public let definition: SourceLocation

    /// All locations where this symbol is referenced
    public var references: [SourceLocation]

    /// Whether this symbol has been defined (vs just referenced)
    public let isDefined: Bool

    public init(
        name: String,
        type: SymbolType,
        scopeLevel: Int,
        definition: SourceLocation,
        isDefined: Bool = true
    ) {
        self.name = name
        self.type = type
        self.scopeLevel = scopeLevel
        self.definition = definition
        self.references = []
        self.isDefined = isDefined
    }

    /// Add a reference to this symbol
    public mutating func addReference(_ location: SourceLocation) {
        references.append(location)
    }
}

/// Symbol-related diagnostic messages
public struct SymbolDiagnostic: Sendable, Equatable {
    public enum Code: Sendable, Equatable {
        case symbolRedefinition(original: SourceLocation, redefinition: SourceLocation)
        case undefinedSymbol(reference: SourceLocation)
        case unusedSymbol(definition: SourceLocation)
        case cannotPopGlobalScope
    }

    public let symbolName: String?
    public let code: Code
    public let location: SourceLocation

    public init(symbolName: String? = nil, code: Code, location: SourceLocation) {
        self.symbolName = symbolName
        self.code = code
        self.location = location
    }

    public var message: String {
        switch code {
        case .symbolRedefinition(let original, let redefinition):
            let name = symbolName ?? "<unknown>"
            return "Symbol '\(name)' redefined at \(redefinition), originally defined at \(original)"
        case .undefinedSymbol(let reference):
            let name = symbolName ?? "<unknown>"
            return "Undefined symbol '\(name)' referenced at \(reference)"
        case .unusedSymbol(let definition):
            let name = symbolName ?? "<unknown>"
            return "Unused symbol '\(name)' defined at \(definition)"
        case .cannotPopGlobalScope:
            return "Cannot pop global scope"
        }
    }
}

/// Manages symbol tables with scope-based resolution for ZIL compilation
public final class SymbolTableManager: Sendable {

    /// Protected state managed by a single mutex
    private struct State: ~Copyable {
        /// Stack of symbol tables representing nested scopes
        var scopes: [[String: Symbol]] = [[:]]  // Start with global scope

        /// Cross-reference table for undefined symbols
        var undefinedReferences: [String: [SourceLocation]] = [:]

        /// Current scope level (0 = global scope)
        var currentScope: Int = 0

        /// Diagnostics for symbol-related errors
        var diagnostics: [SymbolDiagnostic] = []

        /// Unused symbols from popped scopes, preserved for validation
        var unusedSymbolsFromPoppedScopes: [Symbol] = []
    }

    private let state: Mutex<State>

    public init() {
        self.state = Mutex(State())
    }

    /// Enter a new scope (e.g., entering a routine)
    public func pushScope() {
        state.withLock { state in
            state.scopes.append([:])
            state.currentScope += 1
        }
    }

    /// Exit the current scope
    public func popScope() {
        state.withLock { state in
            guard state.currentScope > 0 else {
                let diagnostic = SymbolDiagnostic(
                    code: .cannotPopGlobalScope,
                    location: .unknown
                )
                state.diagnostics.append(diagnostic)
                return
            }

            // Before popping, check for unused symbols in this scope and preserve them for validation
            let poppedScope = state.scopes.removeLast()
            for symbol in poppedScope.values {
                if symbol.references.isEmpty {
                    state.unusedSymbolsFromPoppedScopes.append(symbol)
                }
            }

            state.currentScope -= 1
        }
    }

    /// Define a symbol in the current scope
    @discardableResult
    public func defineSymbol(
        name: String,
        type: SymbolType,
        at location: SourceLocation
    ) -> Bool {
        return state.withLock { state in
            let scopeLevel = state.currentScope

            // Check if symbol already exists in current scope
            if let existingSymbol = state.scopes[scopeLevel][name] {
                let diagnostic = SymbolDiagnostic(
                    symbolName: name,
                    code: .symbolRedefinition(
                        original: existingSymbol.definition,
                        redefinition: location
                    ),
                    location: location
                )
                state.diagnostics.append(diagnostic)
                return false
            }

            // Create new symbol
            var symbol = Symbol(
                name: name,
                type: type,
                scopeLevel: scopeLevel,
                definition: location
            )

            // Add any pending references for this symbol
            if let pendingRefs = state.undefinedReferences.removeValue(forKey: name) {
                for ref in pendingRefs {
                    symbol.addReference(ref)
                }
            }

            // Add to current scope
            state.scopes[scopeLevel][name] = symbol
            return true
        }
    }

    /// Look up a symbol, searching through scope chain
    public func lookupSymbol(name: String) -> Symbol? {
        return state.withLock { state in
            // Search from current scope up to global scope
            for level in (0...state.currentScope).reversed() {
                if let symbol = state.scopes[level][name] {
                    return symbol
                }
            }
            return nil
        }
    }

    /// Record a reference to a symbol (may be undefined)
    public func referenceSymbol(name: String, at location: SourceLocation) -> Symbol? {
        return state.withLock { state in
            // Search for existing symbol
            for level in (0...state.currentScope).reversed() {
                if var symbol = state.scopes[level][name] {
                    // Symbol exists, add reference
                    symbol.addReference(location)
                    state.scopes[level][name] = symbol
                    return symbol
                }
            }

            // Symbol not defined yet, record as undefined reference
            state.undefinedReferences[name, default: []].append(location)
            return nil
        }
    }

    /// Get all symbols in a specific scope
    public func getSymbolsInScope(_ scopeLevel: Int) -> [Symbol] {
        return state.withLock { state in
            guard scopeLevel < state.scopes.count else { return [] }
            return Array(state.scopes[scopeLevel].values)
        }
    }

    /// Get all symbols across all scopes
    public func getAllSymbols() -> [Symbol] {
        return state.withLock { state in
            state.scopes.flatMap { $0.values }
        }
    }

    /// Get all undefined references
    public func getUndefinedReferences() -> [String: [SourceLocation]] {
        return state.withLock { state in
            state.undefinedReferences
        }
    }

    /// Get all diagnostics
    public func getDiagnostics() -> [SymbolDiagnostic] {
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

    /// Get current scope level
    public func getCurrentScope() -> Int {
        return state.withLock { state in
            state.currentScope
        }
    }

    /// Validate all symbols and generate final diagnostics
    ///
    /// PERFORMANCE NOTE: This method holds the mutex for the entire validation process.
    /// All operations inside are O(n) array/dictionary operations on local data structures,
    /// so the critical section should complete quickly. If future enhancements add expensive
    /// operations (I/O, network calls, complex computations), consider extracting data first
    /// and processing outside the mutex lock.
    public func validate() {
        state.withLock { state in
            // Check for undefined symbols
            for (symbolName, references) in state.undefinedReferences {
                for location in references {
                    let diagnostic = SymbolDiagnostic(
                        symbolName: symbolName,
                        code: .undefinedSymbol(reference: location),
                        location: location
                    )
                    state.diagnostics.append(diagnostic)
                }
            }

            // Check for unused symbols (current scopes + previously popped unused symbols)
            let currentSymbols = state.scopes.flatMap { $0.values }
            let allUnusedSymbols = currentSymbols.filter { $0.references.isEmpty && $0.scopeLevel > 0 } +
                                 state.unusedSymbolsFromPoppedScopes

            for symbol in allUnusedSymbols {
                let diagnostic = SymbolDiagnostic(
                    symbolName: symbol.name,
                    code: .unusedSymbol(definition: symbol.definition),
                    location: symbol.definition
                )
                state.diagnostics.append(diagnostic)
            }
        }
    }
}