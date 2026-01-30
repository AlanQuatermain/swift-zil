import Foundation
import Synchronization

/// Represents the result of semantic analysis
public enum SemanticResult: Sendable, Equatable {
    case success
    case failure([SemanticDiagnostic])
}

/// Semantic analysis diagnostic messages
public struct SemanticDiagnostic: Sendable, Equatable {
    public enum Code: Sendable, Equatable {
        case undefinedSymbol(name: String, type: String)
        case symbolRedefinition(name: String, originalLocation: SourceLocation)
        case typeMismatch(expected: String, actual: String, context: String)
        case invalidPropertyAccess(property: String, onType: String)
        case invalidFlagOperation(flag: String, context: String)
        case scopeViolation(variable: String, scope: String)
        case parameterCountMismatch(routine: String, expected: Int, actual: Int)
        case circularDependency(symbols: [String])
        case unreachableCode(reason: String)
        case recursiveMacroDefinition(name: String)
    }

    public let code: Code
    public let location: SourceLocation
    public let context: String?

    public init(code: Code, location: SourceLocation, context: String? = nil) {
        self.code = code
        self.location = location
        self.context = context
    }

    public var message: String {
        let baseMessage = switch code {
        case .undefinedSymbol(let name, let type):
            "Undefined \(type) '\(name)'"
        case .symbolRedefinition(let name, let original):
            "Symbol '\(name)' redefined (originally defined at \(original))"
        case .typeMismatch(let expected, let actual, let context):
            "Type mismatch in \(context): expected \(expected), got \(actual)"
        case .invalidPropertyAccess(let property, let type):
            "Invalid property '\(property)' access on \(type)"
        case .invalidFlagOperation(let flag, let context):
            "Invalid flag '\(flag)' operation in \(context)"
        case .scopeViolation(let variable, let scope):
            "Variable '\(variable)' used outside of \(scope) scope"
        case .parameterCountMismatch(let routine, let expected, let actual):
            "Routine '\(routine)' expects \(expected) parameters, got \(actual)"
        case .circularDependency(let symbols):
            "Circular dependency detected: \(symbols.joined(separator: " -> "))"
        case .unreachableCode(let reason):
            "Unreachable code: \(reason)"
        case .recursiveMacroDefinition(let name):
            "Recursive macro definition: macro '\(name)' references itself"
        }

        if let context = context {
            return "\(baseMessage) (in \(context))"
        }
        return baseMessage
    }
}

/// Semantic analyzer for ZIL programs - validates AST against language rules
public final class SemanticAnalyzer: Sendable {

    /// Protected state managed by a single mutex
    private struct State: ~Copyable {
        /// Symbol table for semantic analysis
        var symbolTable: SymbolTableManager

        /// Compilation context for directive processing
        var compilationContext: CompilationContext

        /// Diagnostics collected during analysis
        var diagnostics: [SemanticDiagnostic] = []

        /// Current analysis context stack
        var contextStack: [String] = []

        /// Forward references to resolve
        var forwardReferences: [String: [(location: SourceLocation, context: String)]] = [:]

        /// Dependency graph for circular dependency detection
        var dependencyGraph: [String: Set<String>] = [:]

        /// Currently analyzing symbols (for recursion detection)
        var analyzingSymbols: Set<String> = []

        /// Current local variable context (for macro parameter validation)
        var currentLocalVariables: Set<String> = []
    }

    private let state: Mutex<State>

    public init(symbolTable: SymbolTableManager = SymbolTableManager(), compilationContext: CompilationContext = CompilationContext()) {
        self.state = Mutex(State(symbolTable: symbolTable, compilationContext: compilationContext))

        // Initialize built-in ZIL functions
        state.withLock { state in
            initializeBuiltInFunctions(&state)
        }
    }

    /// Analyze a complete ZIL program
    public func analyzeProgram(_ declarations: [ZILDeclaration]) -> SemanticResult {
        return state.withLock { state in
            // Clear previous analysis state
            state.diagnostics.removeAll()
            state.forwardReferences.removeAll()
            state.dependencyGraph.removeAll()
            state.analyzingSymbols.removeAll()

            // First pass: Collect all symbol definitions
            for declaration in declarations {
                collectSymbolDefinitions(declaration, state: &state)
            }

            // Second pass: Resolve forward references and validate usage
            for declaration in declarations {
                validateDeclaration(declaration, state: &state)
            }

            // Third pass: Detect circular dependencies
            detectCircularDependencies(state: &state)

            // Final validation of symbol table
            state.symbolTable.validate()
            let symbolTableDiagnostics = state.symbolTable.getDiagnostics()

            // Convert symbol table diagnostics to semantic diagnostics
            for symDiag in symbolTableDiagnostics {
                let semanticDiag = convertSymbolTableDiagnostic(symDiag)
                state.diagnostics.append(semanticDiag)
            }

            if state.diagnostics.isEmpty {
                return .success
            } else {
                return .failure(state.diagnostics)
            }
        }
    }

    /// Get the symbol table used for analysis
    public func getSymbolTable() -> SymbolTableManager {
        return state.withLock { state in
            state.symbolTable
        }
    }

    /// Get the compilation context used for analysis
    public func getCompilationContext() -> CompilationContext {
        return state.withLock { state in
            state.compilationContext
        }
    }

    /// Get all diagnostics from the last analysis
    public func getDiagnostics() -> [SemanticDiagnostic] {
        return state.withLock { state in
            state.diagnostics
        }
    }

    // MARK: - Private Implementation

    /// First pass: Collect symbol definitions
    private func collectSymbolDefinitions(_ declaration: ZILDeclaration, state: inout State) {
        switch declaration {
        case .routine(let routine):
            let parameterNames = routine.parameters
            let optionalNames = routine.optionalParameters.map { $0.name }
            let auxiliaryNames = routine.auxiliaryVariables.map { $0.name }

            let success = state.symbolTable.defineSymbol(
                name: routine.name,
                type: .routine(
                    parameters: parameterNames,
                    optionalParameters: optionalNames,
                    auxiliaryVariables: auxiliaryNames
                ),
                at: routine.location
            )
            if !success {
                // Symbol redefinition will be handled by symbol table diagnostics
            }

        case .object(let object):
            let propertyNames = object.properties.map { $0.name }

            let success = state.symbolTable.defineSymbol(
                name: object.name,
                type: .object(properties: propertyNames, flags: []), // TODO: Extract flags from properties
                at: object.location
            )
            if !success {
                // Symbol redefinition will be handled by symbol table diagnostics
            }

        case .global(let global):
            let success = state.symbolTable.defineSymbol(
                name: global.name,
                type: .globalVariable,
                at: global.location
            )
            if !success {
                // Symbol redefinition will be handled by symbol table diagnostics
            }

        case .property(let property):
            let success = state.symbolTable.defineSymbol(
                name: property.name,
                type: .property(defaultValue: property.defaultValue),
                at: property.location
            )
            if !success {
                // Symbol redefinition will be handled by symbol table diagnostics
            }

        case .constant(let constant):
            let success = state.symbolTable.defineSymbol(
                name: constant.name,
                type: .constant(value: constant.value),
                at: constant.location
            )
            if !success {
                // Symbol redefinition will be handled by symbol table diagnostics
            }

        case .insertFile(_), .version(_):
            // These don't define symbols, skip
            break

        case .princ(_):
            // PRINC is compile-time only, doesn't define symbols
            break

        case .sname(_):
            // SNAME is compile-time metadata, doesn't define symbols
            break

        case .set(_):
            // SET is compile-time configuration, doesn't define symbols
            break

        case .directions(let directions):
            // DIRECTIONS creates direction constants
            for (index, direction) in directions.directions.enumerated() {
                let constantName = "P?\(direction.uppercased())"
                let success = state.symbolTable.defineSymbol(
                    name: constantName,
                    type: .constant(value: .number(Int16(index + 1), directions.location)),
                    at: directions.location
                )
                if !success {
                    // Symbol redefinition will be handled by symbol table diagnostics
                }
            }

        case .syntax(let syntax):
            // SYNTAX defines parser rules - register the action routine
            let success = state.symbolTable.defineSymbol(
                name: syntax.action,
                type: .routine(parameters: [], optionalParameters: [], auxiliaryVariables: []),
                at: syntax.location
            )
            if !success {
                // Symbol redefinition will be handled by symbol table diagnostics
            }

        case .synonym(_):
            // SYNONYM declarations don't define new symbols, they create word mappings
            break

        case .defmac(let defmac):
            // DEFMAC defines a preprocessor macro
            let success = state.symbolTable.defineSymbol(
                name: defmac.name,
                type: .macro(parameters: defmac.parameters, body: defmac.body),
                at: defmac.location
            )
            if !success {
                // Symbol redefinition will be handled by symbol table diagnostics
            }

        case .buzz(_):
            // BUZZ declarations don't define symbols, they configure the parser
            break

        case .zipOptions(_):
            // ZIP-OPTIONS declarations don't define symbols, they configure story file capabilities
            break

        case .orderObjects(_):
            // ORDER-OBJECTS? declarations don't define symbols, they configure object ordering
            break

        case .orderTree(_):
            // ORDER-TREE? declarations don't define symbols, they configure tree ordering
            break

        case .orderFlags(_):
            // ORDER-FLAGS? declarations don't define symbols, they configure flag ordering
            break

        case .routineFlags(_):
            // ROUTINE-FLAGS declarations don't define symbols, they set flags for next routine
            break

        case .fileFlags(_):
            // FILE-FLAGS declarations don't define symbols, they configure file-level flags
            break
        }
    }

    /// Second pass: Validate declarations and resolve references
    private func validateDeclaration(_ declaration: ZILDeclaration, state: inout State) {
        switch declaration {
        case .routine(let routine):
            validateRoutine(routine, state: &state)
        case .object(let object):
            validateObject(object, state: &state)
        case .global(let global):
            validateGlobal(global, state: &state)
        case .property(let property):
            validateProperty(property, state: &state)
        case .constant(let constant):
            validateConstant(constant, state: &state)
        case .insertFile(_), .version(_):
            // These don't need validation, skip
            break

        case .princ(_):
            // PRINC is compile-time only, no validation needed
            break

        case .sname(_):
            // SNAME is compile-time metadata, no validation needed
            break

        case .set(_):
            // SET is compile-time configuration, no validation needed
            break

        case .directions(_):
            // DIRECTIONS validation handled during symbol definition
            break

        case .syntax(let syntax):
            // Validate SYNTAX patterns and action routine
            validateSyntax(syntax, state: &state)

        case .synonym(_):
            // SYNONYM declarations don't need complex validation
            break

        case .defmac(let defmac):
            // Validate macro body expression with parameter context
            validateMacroBody(defmac, state: &state)

        case .buzz(_):
            // BUZZ declarations don't need validation
            break

        case .zipOptions(let zipOptions):
            // Process ZIP-OPTIONS directive
            validateAndApplyZipOptions(zipOptions, state: &state)

        case .orderObjects(let orderObjects):
            // Process ORDER-OBJECTS? directive
            validateAndApplyOrderObjects(orderObjects, state: &state)

        case .orderTree(let orderTree):
            // Process ORDER-TREE? directive
            validateAndApplyOrderTree(orderTree, state: &state)

        case .orderFlags(let orderFlags):
            // Process ORDER-FLAGS? directive
            validateAndApplyOrderFlags(orderFlags, state: &state)

        case .routineFlags(let routineFlags):
            // Process ROUTINE-FLAGS directive
            validateAndApplyRoutineFlags(routineFlags, state: &state)

        case .fileFlags(let fileFlags):
            // Process FILE-FLAGS directive
            validateAndApplyFileFlags(fileFlags, state: &state)
        }
    }

    /// Validate routine declaration
    private func validateRoutine(_ routine: ZILRoutineDeclaration, state: inout State) {
        state.contextStack.append("routine \(routine.name)")
        defer { state.contextStack.removeLast() }

        // Enter routine scope
        state.symbolTable.pushScope()
        defer { state.symbolTable.popScope() }

        // Define parameters and auxiliary variables in local scope
        for param in routine.parameters {
            _ = state.symbolTable.defineSymbol(
                name: param,
                type: .localVariable,
                at: routine.location
            )
        }

        for opt in routine.optionalParameters {
            _ = state.symbolTable.defineSymbol(
                name: opt.name,
                type: .localVariable,
                at: routine.location
            )
        }

        for aux in routine.auxiliaryVariables {
            _ = state.symbolTable.defineSymbol(
                name: aux.name,
                type: .localVariable,
                at: routine.location
            )
        }

        // Validate routine body
        for expression in routine.body {
            validateExpression(expression, state: &state)
        }
    }

    /// Validate object declaration
    private func validateObject(_ object: ZILObjectDeclaration, state: inout State) {
        state.contextStack.append("object \(object.name)")
        defer { state.contextStack.removeLast() }

        // Validate object properties
        for property in object.properties {
            // Check if property is defined and record reference
            if state.symbolTable.referenceSymbol(name: property.name, at: property.location) == nil {
                recordForwardReference(property.name, location: property.location, context: currentContext(state), state: &state)
            }

            // Validate property value
            validateExpression(property.value, state: &state)
        }
    }

    /// Validate global variable declaration
    private func validateGlobal(_ global: ZILGlobalDeclaration, state: inout State) {
        state.contextStack.append("global \(global.name)")
        defer { state.contextStack.removeLast() }

        validateExpression(global.value, state: &state)
    }

    /// Validate property declaration
    private func validateProperty(_ property: ZILPropertyDeclaration, state: inout State) {
        state.contextStack.append("property \(property.name)")
        defer { state.contextStack.removeLast() }

        validateExpression(property.defaultValue, state: &state)
    }

    /// Validate constant declaration
    private func validateConstant(_ constant: ZILConstantDeclaration, state: inout State) {
        state.contextStack.append("constant \(constant.name)")
        defer { state.contextStack.removeLast() }

        validateExpression(constant.value, state: &state)
    }

    /// Validate SYNTAX declaration
    private func validateSyntax(_ syntax: ZILSyntaxDeclaration, state: inout State) {
        state.contextStack.append("SYNTAX \(syntax.verb)")
        defer { state.contextStack.removeLast() }

        // Validate action routine exists or will be defined
        // Action may contain multiple routines (e.g., "V-TAKE PRE-TAKE")
        let actionParts = syntax.action.split(separator: " ").map(String.init)

        for actionName in actionParts {
            validateSymbolReference(
                actionName,
                location: syntax.location,
                type: "routine",
                state: &state
            )
        }

        // Validate pattern elements
        for element in syntax.pattern {
            switch element {
            case .object(_, let constraints):
                // Validate each constraint expression
                for constraint in constraints {
                    validateExpression(constraint, state: &state)
                }

            case .preposition(_):
                // Prepositions don't need validation - they're just literal words
                break

            case .optional(_):
                // Optional elements not currently used in real ZIL, but if they were,
                // we'd validate the wrapped element recursively
                break
            }
        }
    }

    /// Validate an expression
    private func validateExpression(_ expression: ZILExpression, state: inout State) {
        switch expression {
        case .atom(let name, let location):
            validateSymbolReference(name, location: location, type: "routine or constant", state: &state)

        case .globalVariable(let name, let location):
            validateSymbolReference(name, location: location, type: "global variable", state: &state)

        case .localVariable(let name, let location):
            validateSymbolReference(name, location: location, type: "local variable", state: &state)

        case .propertyReference(let name, let location):
            validateSymbolReference(name, location: location, type: "property", state: &state)

        case .flagReference(let name, let location):
            validateSymbolReference(name, location: location, type: "flag", state: &state)

        case .list(let elements, _):
            // Validate list elements
            for element in elements {
                validateExpression(element, state: &state)
            }

            // Special validation for function calls
            if let first = elements.first {
                validateFunctionCall(first, arguments: Array(elements.dropFirst()), state: &state)
            }

        case .number(_, _), .string(_, _):
            // Literals are always valid
            break

        case .table(_, let elements, _):
            // Validate table elements
            for element in elements {
                validateExpression(element, state: &state)
            }

        case .indirection(let targetExpression, _):
            // Validate the target expression being dereferenced
            validateExpression(targetExpression, state: &state)
        }
    }

    /// Validate symbol reference
    private func validateSymbolReference(_ name: String, location: SourceLocation, type: String, state: inout State) {
        if state.symbolTable.referenceSymbol(name: name, at: location) != nil {
            // Symbol found, add dependency if in global context
            if state.contextStack.isEmpty {
                recordDependency(from: currentContext(state), to: name, state: &state)
            }
        } else {
            // Symbol not found, record as forward reference
            recordForwardReference(name, location: location, context: currentContext(state), state: &state)
        }
    }

    /// Validate function call
    private func validateFunctionCall(_ function: ZILExpression, arguments: [ZILExpression], state: inout State) {
        guard case .atom(let functionName, let location) = function else {
            return // Non-atom function calls are handled elsewhere
        }

        // Look up function symbol
        if let symbol = state.symbolTable.lookupSymbol(name: functionName) {
            if case .routine(let parameters, let optionalParams, _) = symbol.type {
                // Skip parameter count validation for built-in functions (they have flexible arity)
                if symbol.definition == .unknown {
                    // This is a built-in function - skip parameter validation
                    return
                }

                // For user-defined functions, validate parameter count
                let minParams = parameters.count
                let maxParams = parameters.count + optionalParams.count
                let actualParams = arguments.count

                if actualParams < minParams || actualParams > maxParams {
                    let diagnostic = SemanticDiagnostic(
                        code: .parameterCountMismatch(
                            routine: functionName,
                            expected: minParams,
                            actual: actualParams
                        ),
                        location: location,
                        context: currentContext(state)
                    )
                    state.diagnostics.append(diagnostic)
                }
            }
        }
    }

    /// Record forward reference for later resolution
    private func recordForwardReference(_ name: String, location: SourceLocation, context: String, state: inout State) {
        state.forwardReferences[name, default: []].append((location: location, context: context))
    }

    /// Validate a macro body with parameter context
    private func validateMacroBody(_ defmac: ZILDefmacDeclaration, state: inout State) {
        // Create a temporary local variable context for macro parameters
        // This allows .PARAM references to be treated as valid within the macro body
        var localVars: Set<String> = []
        for param in defmac.parameters {
            switch param {
            case .standard(let name), .quoted(let name), .variableArgs(let name), .optional(let name, _):
                localVars.insert(name)
            }
        }

        // Save current local variable context
        let savedLocalVars = state.currentLocalVariables
        state.currentLocalVariables = localVars

        // Validate the macro body expression
        validateMacroBodyExpression(defmac.body, macroName: defmac.name, state: &state)

        // Restore local variable context
        state.currentLocalVariables = savedLocalVars
    }

    /// Validate expressions within a macro body, checking for recursive references
    private func validateMacroBodyExpression(_ expression: ZILExpression, macroName: String, state: inout State) {
        switch expression {
        case .atom(let name, let location):
            // Check if this is a recursive macro call
            if name == macroName {
                let diagnostic = SemanticDiagnostic(
                    code: .recursiveMacroDefinition(name: macroName),
                    location: location,
                    context: "DEFMAC \(macroName)"
                )
                state.diagnostics.append(diagnostic)
            } else {
                // Validate as normal symbol reference
                validateSymbolReference(name, location: location, type: "routine or constant", state: &state)
            }

        case .globalVariable(let name, let location):
            validateSymbolReference(name, location: location, type: "global variable", state: &state)

        case .localVariable(let name, let location):
            // Check if this is a macro parameter reference
            if !state.currentLocalVariables.contains(name) {
                // Not a macro parameter, validate as regular local variable
                validateSymbolReference(name, location: location, type: "local variable or macro parameter", state: &state)
            }
            // If it is a macro parameter, it's valid - no further validation needed

        case .propertyReference(let name, let location):
            validateSymbolReference(name, location: location, type: "property", state: &state)

        case .flagReference(let name, let location):
            validateSymbolReference(name, location: location, type: "flag", state: &state)

        case .list(let elements, _):
            // Check first element for recursive macro call
            if case .atom(let name, let location) = elements.first, name == macroName {
                let diagnostic = SemanticDiagnostic(
                    code: .recursiveMacroDefinition(name: macroName),
                    location: location,
                    context: "DEFMAC \(macroName)"
                )
                state.diagnostics.append(diagnostic)
            }

            // Recursively validate all list elements
            for element in elements {
                validateMacroBodyExpression(element, macroName: macroName, state: &state)
            }

        case .number(_, _), .string(_, _):
            // Literals are always valid
            break

        case .table(_, let elements, _):
            // Validate table elements
            for element in elements {
                validateMacroBodyExpression(element, macroName: macroName, state: &state)
            }

        case .indirection(let targetExpression, _):
            // Validate the target expression
            validateMacroBodyExpression(targetExpression, macroName: macroName, state: &state)
        }
    }

    /// Record dependency between symbols
    private func recordDependency(from: String, to: String, state: inout State) {
        state.dependencyGraph[from, default: []].insert(to)
    }

    /// Get current analysis context
    private func currentContext(_ state: borrowing State) -> String {
        return state.contextStack.last ?? "global"
    }

    /// Detect circular dependencies
    private func detectCircularDependencies(state: inout State) {
        var visited: Set<String> = []
        var recursionStack: Set<String> = []
        var currentPath: [String] = []

        func dfs(_ symbol: String) -> Bool {
            if recursionStack.contains(symbol) {
                // Found cycle
                let cycleStart = currentPath.firstIndex(of: symbol) ?? currentPath.count
                let cycle = Array(currentPath[cycleStart...]) + [symbol]
                let diagnostic = SemanticDiagnostic(
                    code: .circularDependency(symbols: cycle),
                    location: .unknown
                )
                state.diagnostics.append(diagnostic)
                return true
            }

            if visited.contains(symbol) {
                return false
            }

            visited.insert(symbol)
            recursionStack.insert(symbol)
            currentPath.append(symbol)

            if let dependencies = state.dependencyGraph[symbol] {
                for dependency in dependencies {
                    if dfs(dependency) {
                        return true
                    }
                }
            }

            recursionStack.remove(symbol)
            currentPath.removeLast()
            return false
        }

        for symbol in state.dependencyGraph.keys {
            if !visited.contains(symbol) {
                _ = dfs(symbol)
            }
        }
    }

    // MARK: - Directive Validation and Application

    /// Validate and apply ZIP-OPTIONS directive
    private func validateAndApplyZipOptions(_ zipOptions: ZILZipOptionsDeclaration, state: inout State) {
        var options: ZipOptions = []

        for optionName in zipOptions.options {
            switch optionName.uppercased() {
            case "COLOR", "COLOUR":
                options.insert(.color)
            case "MOUSE":
                options.insert(.mouse)
            case "UNDO":
                options.insert(.undo)
            case "DISPLAY":
                options.insert(.display)
            case "SOUND":
                options.insert(.sound)
            case "MENU":
                options.insert(.menu)
            case "BIG":
                options.insert(.big)
            default:
                let diagnostic = SemanticDiagnostic(
                    code: .undefinedSymbol(name: optionName, type: "ZIP option"),
                    location: zipOptions.location,
                    context: "Unknown ZIP option '\(optionName)'"
                )
                state.diagnostics.append(diagnostic)
            }
        }

        state.compilationContext.addZipOptions(options)
    }

    /// Validate and apply ORDER-OBJECTS? directive
    private func validateAndApplyOrderObjects(_ orderObjects: ZILOrderObjectsDeclaration, state: inout State) {
        let ordering: ObjectOrdering

        switch orderObjects.ordering.uppercased() {
        case "DEFINED":
            ordering = .defined
        case "ROOMS-FIRST":
            ordering = .roomsFirst
        case "ROOMS-AND-LGS-FIRST":
            ordering = .roomsAndLgsFirst
        case "ROOMS-LAST":
            ordering = .roomsLast
        default:
            let diagnostic = SemanticDiagnostic(
                code: .undefinedSymbol(name: orderObjects.ordering, type: "object ordering strategy"),
                location: orderObjects.location,
                context: "Unknown object ordering '\(orderObjects.ordering)'"
            )
            state.diagnostics.append(diagnostic)
            return
        }

        state.compilationContext.setObjectOrdering(ordering)
    }

    /// Validate and apply ORDER-TREE? directive
    private func validateAndApplyOrderTree(_ orderTree: ZILOrderTreeDeclaration, state: inout State) {
        let ordering: TreeOrdering

        switch orderTree.ordering.uppercased() {
        case "REVERSE-DEFINED":
            ordering = .reverseDefined
        default:
            let diagnostic = SemanticDiagnostic(
                code: .undefinedSymbol(name: orderTree.ordering, type: "tree ordering strategy"),
                location: orderTree.location,
                context: "Unknown tree ordering '\(orderTree.ordering)'"
            )
            state.diagnostics.append(diagnostic)
            return
        }

        state.compilationContext.setTreeOrdering(ordering)
    }

    /// Validate and apply ORDER-FLAGS? directive
    private func validateAndApplyOrderFlags(_ orderFlags: ZILOrderFlagsDeclaration, state: inout State) {
        // Validate order keyword
        guard orderFlags.order.uppercased() == "LAST" else {
            let diagnostic = SemanticDiagnostic(
                code: .undefinedSymbol(name: orderFlags.order, type: "flag ordering keyword"),
                location: orderFlags.location,
                context: "Expected 'LAST' for flag ordering, got '\(orderFlags.order)'"
            )
            state.diagnostics.append(diagnostic)
            return
        }

        state.compilationContext.addFlagsOrderedLast(orderFlags.flags)
    }

    /// Validate and apply ROUTINE-FLAGS directive
    private func validateAndApplyRoutineFlags(_ routineFlags: ZILRoutineFlagsDeclaration, state: inout State) {
        var flags: RoutineFlags = []

        for flagName in routineFlags.flags {
            switch flagName.uppercased() {
            case "CLEAN-STACK?":
                flags.insert(.cleanStack)
            case "KEEP?":
                flags.insert(.keep)
            case "UNUSED?":
                flags.insert(.suppressUnused)
            default:
                let diagnostic = SemanticDiagnostic(
                    code: .undefinedSymbol(name: flagName, type: "routine flag"),
                    location: routineFlags.location,
                    context: "Unknown routine flag '\(flagName)'"
                )
                state.diagnostics.append(diagnostic)
            }
        }

        state.compilationContext.setNextRoutineFlags(flags)
    }

    /// Validate and apply FILE-FLAGS directive
    private func validateAndApplyFileFlags(_ fileFlags: ZILFileFlagsDeclaration, state: inout State) {
        var flags: FileFlags = []

        for flagName in fileFlags.flags {
            switch flagName.uppercased() {
            case "CLEAN-STACK?":
                flags.insert(.cleanStack)
            case "MDL-ZIL?":
                flags.insert(.mdlZil)
            case "SENTENCE-ENDS?":
                flags.insert(.sentenceEnds)
            case "KEEP?":
                flags.insert(.keepRoutines)
            case "UNUSED?":
                flags.insert(.suppressUnusedWarnings)
            case "ZAP-TO-SOURCE-DIRECTORY?":
                flags.insert(.zapToSourceDirectory)
            default:
                let diagnostic = SemanticDiagnostic(
                    code: .undefinedSymbol(name: flagName, type: "file flag"),
                    location: fileFlags.location,
                    context: "Unknown file flag '\(flagName)'"
                )
                state.diagnostics.append(diagnostic)
            }
        }

        // Update file context with new flags
        // Note: In a real implementation, we'd need to track file paths
        // For now, we just update the current file flags directly
        if let currentPath = state.compilationContext.getCurrentFilePath() {
            state.compilationContext.popFileContext()
            state.compilationContext.pushFileContext(currentPath, flags: flags)
        } else {
            // No file context yet, push one with default path
            state.compilationContext.pushFileContext("<unknown>", flags: flags)
        }
    }

    /// Convert symbol table diagnostic to semantic diagnostic
    private func convertSymbolTableDiagnostic(_ symDiag: SymbolDiagnostic) -> SemanticDiagnostic {
        switch symDiag.code {
        case .symbolRedefinition(let original, let redefinition):
            return SemanticDiagnostic(
                code: .symbolRedefinition(
                    name: symDiag.symbolName ?? "<unknown>",
                    originalLocation: original
                ),
                location: redefinition
            )
        case .undefinedSymbol(let reference):
            return SemanticDiagnostic(
                code: .undefinedSymbol(
                    name: symDiag.symbolName ?? "<unknown>",
                    type: "symbol"
                ),
                location: reference
            )
        case .unusedSymbol(let definition):
            // Convert to unreachable code warning
            return SemanticDiagnostic(
                code: .unreachableCode(reason: "unused symbol '\(symDiag.symbolName ?? "<unknown>")'"),
                location: definition
            )
        case .cannotPopGlobalScope:
            return SemanticDiagnostic(
                code: .scopeViolation(variable: "<scope>", scope: "global"),
                location: .unknown
            )
        }
    }

    /// Initialize built-in ZIL functions and constants
    private func initializeBuiltInFunctions(_ state: inout State) {
        let unknownLocation = SourceLocation.unknown

        // Built-in Functions (comprehensive list from ZIL expert)
        let builtinFunctions = [
            // Macro and Meta-Programming Functions
            "FORM", "LIST", "SEGMENT",

            // Arithmetic and Math Functions
            "+", "ADD", "-", "SUB", "*", "MUL", "/", "DIV",
            "MOD", "%", "RANDOM", "ABS", "MIN", "MAX", "SQRT",
            "SIN", "COS", "ATAN", "EXP", "LOG",

            // Comparison and Logic Functions
            "EQUAL?", "=", "==?", "LESS?", "<", "GREATER?", ">",
            "ZERO?", "GRTR?", "G?", "L?", "E?", "N?", "G=?", "L=?",
            "AND", "OR", "NOT", "BAND", "BOR", "BCOM", "SHIFT",
            "XOR", "BTST",

            // Control Flow Functions
            "COND", "PROG", "REPEAT", "RETURN", "RTRUE", "RFALSE",
            "AGAIN", "MAPF", "MAPR", "MAPRET", "MAPSTOP", "APPLY", "EVAL",

            // Variable and Memory Functions
            "SET", "SETG", "PUT", "GET", "PUTB", "GETB", "PUTP", "GETP",
            "GETPT", "PTSIZE", "NEXTP", "TABLE", "ITABLE", "LTABLE",
            "BTABLE", "VALUE", "GVAL", "LVAL",

            // Object Manipulation Functions
            "MOVE", "REMOVE", "FIRST?", "NEXT?", "IN?", "LOC",
            "FSET", "FCLEAR", "FSET?", "CHILD?", "PARENT", "SIBLING",
            "HELD?", "CARRIED?", "WORN?", "ACCESSIBLE?", "VISIBLE?", "TOUCHABLE?",

            // I/O and Text Functions
            "TELL", "PRINT", "PRINTI", "PRINTN", "PRINTB", "PRINTT",
            "PRINTC", "PRINTD", "PRINTR", "PRINTA", "CRLF", "CR",
            "BUFFER", "READ", "READ-TABLE", "SREAD", "AREAD",
            "SPLIT", "BUFFER-PRINT", "DIROUT", "DIRIN", "OUTPUT", "USL",
            // Removed "PARSE" as it may be user-defined

            // Parser and Game Functions
            "VERB?", "THIS-IS-IT?", "LEXV", "PARSE-OBJECTS", "ORPHAN?",
            "SYNTAX", "PROPDEF", "DEFMAC", "PERFORM", "DO-WALK", "GOTO",
            "JIGS-UP", "QUEUE", "DEQUEUE", "ENABLE", "DISABLE", "SAVE",
            "RESTORE", "RESTART", "QUIT", "VERIFY", "RANDOM-SEED", "TIME",
            "DISPLAY", "SHOW-PICTURE", "ERASE-PICTURE", "SET-MARGINS",

            // Stack Functions
            "PUSH", "POP", "STACKP", "FSTACK", "RSTACK", "CATCH", "THROW",

            // Type and Predicate Functions
            "TYPE?", "EMPTY?", "LENGTH?", "ASSIGNED?", "GASSIGNED?",
            "BOUND?", "STRUCTURED?", "NUMBER?", "STRING?", "ATOM?",
            "LIST?", "VECTOR?", "TABLE?", "FUNCTION?", "OBJECT?",

            // String and Conversion Functions
            "SPNAME", "STRING", "ZSTRING", "ASCII", "CHARS",
            "UNPARSE", "SPLICE", "CHTYPE", "FIX", "FLOAT", "TRUNC",
            // Removed "PARSE" as it may be user-defined

            // Advanced/System Functions
            "GC", "DEBUG", "ERROR", "SAVE-UNDO", "RESTORE-UNDO",
            "SCRIPT", "UNSCRIPT", "PICINF", "SOUND-EFFECT", "SET-COLOR",
            "SPLIT-SCREEN", "BUFFER-MODE", "PUSH-STACK", "POP-STACK",
            "CATCH-STACK", "THROW-STACK",

            // Compiler/Meta Functions
            "INSERT-FILE", "CONSTANT", "GLOBAL", "INCLUDE", "REPLACE",
            "SYNONYM", "ADJECTIVE", "MSETG", "GUNASSIGN", "COMPILE-TIME",
            "VERSION", "ZORK-NUMBER", "SNAME"
        ]

        // Built-in Constants (not functions) - only core constants that shouldn't be redefined
        let builtinConstants = [
            "T", "FALSE", "<>", "PRSA", "PRSO", "PRSI", "WINNER", "HERE", "ELSE"
            // Removed "PLAYER", "ROOMS", etc. as they may be legitimately defined by users
            // ELSE is equivalent to T in COND clauses (default/fallback clause)
        ]

        // Define built-in functions as routines with variable parameters
        for functionName in builtinFunctions {
            _ = state.symbolTable.defineSymbol(
                name: functionName,
                type: .routine(parameters: [], optionalParameters: [], auxiliaryVariables: []),
                at: unknownLocation
            )
        }

        // Define built-in constants
        for constantName in builtinConstants {
            _ = state.symbolTable.defineSymbol(
                name: constantName,
                type: .constant(value: .atom(constantName, unknownLocation)),
                at: unknownLocation
            )
        }
    }
}