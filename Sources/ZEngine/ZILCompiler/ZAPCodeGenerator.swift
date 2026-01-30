/// Generates ZAP (Z-Machine Assembly Program) code from ZIL abstract syntax tree
import Foundation

public struct ZAPCodeGenerator {

    // MARK: - Error Handling

    public struct CodeGenerationError: Error {
        public enum Kind: Sendable {
            case unsupportedExpression(String)
            case invalidFunction(String)
            case undefinedSymbol(String)
            case invalidInstruction(String)
            case labelGenerationFailed(String)
            case invalidOperand(String)
            case memoryLayoutError(String)
            case versionIncompatibility(String)
            case invalidControlFlow(String)
            case typeSystemError(String)
            case optimizationError(String)
            case codeGenerationFailed(String)
            case invalidObjectDefinition(String)
            case propertyTableError(String)
            case globalTableError(String)
            case stringTableError(String)
            case branchTargetError(String)
            case stackManagementError(String)
        }

        public let kind: Kind
        public let location: SourceLocation?
        public let context: String?

        public init(_ kind: Kind, at location: SourceLocation? = nil, context: String? = nil) {
            self.kind = kind
            self.location = location
            self.context = context
        }

        public var localizedDescription: String {
            var description = ""

            if let location = location {
                description += "\(location): "
            }

            switch kind {
            case .unsupportedExpression(let expr):
                description += "unsupported expression: \(expr)"
            case .invalidFunction(let name):
                description += "invalid function: \(name)"
            case .undefinedSymbol(let symbol):
                description += "undefined symbol: \(symbol)"
            case .invalidInstruction(let instr):
                description += "invalid instruction: \(instr)"
            case .labelGenerationFailed(let reason):
                description += "label generation failed: \(reason)"
            case .invalidOperand(let operand):
                description += "invalid operand: \(operand)"
            case .memoryLayoutError(let error):
                description += "memory layout error: \(error)"
            case .versionIncompatibility(let issue):
                description += "version incompatibility: \(issue)"
            case .invalidControlFlow(let issue):
                description += "invalid control flow: \(issue)"
            case .typeSystemError(let error):
                description += "type system error: \(error)"
            case .optimizationError(let error):
                description += "optimization error: \(error)"
            case .codeGenerationFailed(let reason):
                description += "code generation failed: \(reason)"
            case .invalidObjectDefinition(let error):
                description += "invalid object definition: \(error)"
            case .propertyTableError(let error):
                description += "property table error: \(error)"
            case .globalTableError(let error):
                description += "global table error: \(error)"
            case .stringTableError(let error):
                description += "string table error: \(error)"
            case .branchTargetError(let error):
                description += "branch target error: \(error)"
            case .stackManagementError(let error):
                description += "stack management error: \(error)"
            }

            if let context = context {
                description += " (context: \(context))"
            }

            return description
        }
    }

    // MARK: - InstructionBuilder

    private class InstructionBuilder {
        private var instructions: [String] = []
        private var tempVarCounter: Int = 0
        private var labelCounter: Int = 0
        private var contextStack: [GenerationContext] = []
        private var stackDepth: Int = 0 // Track current stack depth

        struct GenerationContext {
            let scopeName: String
            let tempVarBase: Int
            let availableTemps: Set<String>
            let stackBase: Int
        }

        func pushContext(_ name: String) {
            contextStack.append(GenerationContext(
                scopeName: name,
                tempVarBase: tempVarCounter,
                availableTemps: [],
                stackBase: stackDepth
            ))
        }

        func popContext() {
            guard let context = contextStack.popLast() else { return }
            // Release temp vars back to pool
            tempVarCounter = context.tempVarBase
            // Reset stack depth to context base
            stackDepth = context.stackBase
        }

        func emit(_ instruction: String) {
            instructions.append(instruction)
        }

        func emitWithResult(_ instruction: String) -> String {
            let temp = generateTempVar()
            instructions.append("\(instruction) >\(temp)")
            return temp
        }

        // New method for direct assignment to variables (Infocom style)
        func emitWithDirectAssignment(_ instruction: String, to variable: String) {
            instructions.append("\(instruction) >\(variable)")
        }

        // New method for stack-based operations (Infocom style)
        func emitToStack(_ instruction: String) -> String {
            instructions.append(instruction)
            stackDepth += 1
            return "STACK"
        }

        // Use value from stack (decrements stack depth)
        func useStackValue() -> String {
            if stackDepth > 0 {
                stackDepth -= 1
            }
            return "STACK"
        }

        // Get current stack depth for debugging
        func getStackDepth() -> Int {
            return stackDepth
        }

        // Check if we should prefer stack operations (Infocom optimization)
        func shouldUseStack() -> Bool {
            return stackDepth < 8 // Conservative stack limit
        }

        func generateTempVar() -> String {
            tempVarCounter += 1
            return "TEMP\(tempVarCounter)"
        }

        func generateLabel(_ prefix: String = "L") -> String {
            labelCounter += 1
            return "?\(prefix)\(labelCounter)"
        }

        func getInstructions() -> [String] {
            return instructions
        }

        func clear() {
            instructions.removeAll()
            tempVarCounter = 0
            labelCounter = 0
            contextStack.removeAll()
            stackDepth = 0
        }
    }

    // MARK: - Label Management

    private struct LabelManager {
        private var counters: [String: Int] = [:]

        mutating func generateLabel(prefix: String) -> String {
            counters[prefix, default: 0] += 1
            return "?\(prefix)\(counters[prefix]!)"
        }

        func formatBranchTrue(_ label: String) -> String {
            return "/\(label)"
        }

        func formatBranchFalse(_ label: String) -> String {
            return "\\\(label)"
        }
    }

    // MARK: - Code Generation Context

    private struct GenerationContext {
        var currentFunction: String?
        var localVariables: Set<String> = []
        var loopStack: [String] = [] // Stack of loop end labels
        var conditionStack: [String] = [] // Stack of condition end labels

        mutating func enterFunction(_ name: String) {
            currentFunction = name
            localVariables.removeAll()
        }

        mutating func exitFunction() {
            currentFunction = nil
            localVariables.removeAll()
        }

        mutating func addLocalVariable(_ name: String) {
            localVariables.insert(name)
        }

        func isLocalVariable(_ name: String) -> Bool {
            return localVariables.contains(name)
        }
    }

    // MARK: - Memory Layout Management

    private struct MemoryLayout {
        var constants: [(String, ZValue)] = []
        var globals: [String] = []
        var properties: [String] = []
        var objects: [String] = []
        var strings: [String] = []
        var functions: [String] = []
        var tables: [(String, ZILTableType, [String])] = [] // (name, type, elements)
        var vocabularyManager: VocabularyManager?
        var syntaxTableBuilder: SyntaxTableBuilder?

        mutating func addConstant(_ name: String, value: ZValue) {
            constants.append((name, value))
        }

        mutating func addGlobal(_ name: String) {
            if !globals.contains(name) {
                globals.append(name)
            }
        }

        mutating func addProperty(_ name: String) {
            if !properties.contains(name) {
                properties.append(name)
            }
        }

        mutating func addObject(_ name: String) {
            if !objects.contains(name) {
                objects.append(name)
            }
        }

        mutating func addString(_ content: String) -> Int {
            if let index = strings.firstIndex(of: content) {
                return index
            } else {
                strings.append(content)
                return strings.count - 1
            }
        }

        mutating func addFunction(_ name: String) {
            if !functions.contains(name) {
                functions.append(name)
            }
        }

        mutating func addTable(_ name: String, type: ZILTableType, elements: [String]) -> String {
            let tableName = "TBL\(tables.count)"
            tables.append((tableName, type, elements))
            return tableName
        }
    }

    // MARK: - Properties

    private let symbolTable: SymbolTableManager
    private let version: ZMachineVersion
    private var labelManager = LabelManager()
    private var context = GenerationContext()
    private var memoryLayout = MemoryLayout()
    private var output: [String] = []
    private var optimizationLevel: Int = 0  // 0 = debug, 1 = O1 (production), 2+ = future
    private var tempVarCounter: Int = 0  // Class-level temp variable counter

    // Object tree building
    private var objectTreeBuilder: ObjectTreeBuilder?
    private var flagManager: FlagManager!
    private var propertyDefManager: PropertyDefManager!
    private var objectIDToNameMap: [Int: String] = [:]

    // MARK: - Initialization

    public init(symbolTable: SymbolTableManager, version: ZMachineVersion = .v5, optimizationLevel: Int = 0) {
        self.symbolTable = symbolTable
        self.version = version
        self.optimizationLevel = optimizationLevel

        // Initialize managers with version
        self.flagManager = FlagManager(zMachineVersion: Int(version.rawValue))
        self.propertyDefManager = PropertyDefManager(zMachineVersion: Int(version.rawValue))

        // Initialize parser table managers
        self.memoryLayout.vocabularyManager = VocabularyManager(version: version)
        self.memoryLayout.syntaxTableBuilder = SyntaxTableBuilder()
    }

    // MARK: - Helper Methods

    /// Generate a unique temporary variable name
    private mutating func generateTempVar() -> String {
        tempVarCounter += 1
        return "TEMP\(tempVarCounter)"
    }

    // MARK: - Optimization Level Helpers

    private var isProductionMode: Bool {
        return optimizationLevel >= 1  // O1 and above use production output
    }

    private var shouldIncludeHeaders: Bool {
        return optimizationLevel == 0  // Only debug mode includes verbose headers
    }

    private var shouldIncludeSections: Bool {
        return optimizationLevel == 0  // Only debug mode includes section dividers
    }

    private var shouldIncludeStatistics: Bool {
        return optimizationLevel == 0  // Only debug mode includes footer statistics
    }

    // MARK: - Public Interface

    public mutating func generateCode(from declarations: [ZILDeclaration]) throws -> String {
        output.removeAll()
        labelManager = LabelManager()
        context = GenerationContext()

        // Initialize memory layout with parser table managers
        memoryLayout = MemoryLayout()
        memoryLayout.vocabularyManager = VocabularyManager(version: version)
        memoryLayout.syntaxTableBuilder = SyntaxTableBuilder()

        // Initialize object tree builder
        objectTreeBuilder = ObjectTreeBuilder(
            zMachineVersion: Int(version.rawValue),
            flagManager: flagManager,
            propertyManager: propertyDefManager
        )
        objectIDToNameMap.removeAll()

        // First pass: collect symbols and build memory layout
        try analyzeDeclarations(declarations)

        // Generate ZAP header
        try generateHeader()

        // Generate constants section
        try generateConstantsSection()

        // Generate parser tables (vocabulary and syntax)
        try generateParserTablesSection()

        // Generate globals section
        try generateGlobalsSection()

        // Generate properties section
        try generatePropertiesSection()

        // Generate objects section
        try generateObjectsSection(declarations)

        // Generate functions section
        try generateFunctionsSection(declarations)

        // Generate strings section
        try generateStringsSection()

        // Generate tables section
        try generateTablesSection()

        // Generate footer
        try generateFooter()

        // Apply optimizations if requested
        if optimizationLevel > 0 {
            try optimizeCode()
        }

        return output.joined(separator: "\n")
    }

    // MARK: - Analysis Phase

    private mutating func analyzeDeclarations(_ declarations: [ZILDeclaration]) throws {
        for declaration in declarations {
            try analyzeDeclaration(declaration)
        }
    }

    private mutating func analyzeDeclaration(_ declaration: ZILDeclaration) throws {
        switch declaration {
        case .routine(let routine):
            memoryLayout.addFunction(routine.name)

            // Analyze routine body to find referenced symbols
            for expression in routine.body {
                try analyzeExpression(expression)
            }

        case .object(let object):
            memoryLayout.addObject(object.name)

            // Extract parent name from IN property
            let parentName = extractParentName(from: object.properties)

            // Extract flags from FLAGS property
            let flags = extractFlags(from: object.properties)

            // Convert properties to PropertyValue format
            var properties: [String: PropertyValue] = [:]
            for property in object.properties {
                // Skip IN and FLAGS - these are handled separately
                if property.name.uppercased() == "IN" || property.name.uppercased() == "FLAGS" {
                    continue
                }

                memoryLayout.addProperty(property.name)
                try analyzeExpression(property.value)

                // Convert to PropertyValue
                let propertyValue = try convertToPropertyValue(property.value)
                properties[property.name] = propertyValue
            }

            // Add to object tree builder
            try objectTreeBuilder?.addObject(
                name: object.name,
                parentName: parentName,
                flags: flags,
                properties: properties,
                location: object.location
            )

        case .global(let global):
            memoryLayout.addGlobal(global.name)
            try analyzeExpression(global.value)

        case .property(let property):
            memoryLayout.addProperty(property.name)
            try analyzeExpression(property.defaultValue)

        case .constant(let constant):
            let value = try evaluateConstantExpression(constant.value)
            memoryLayout.addConstant(constant.name, value: value)

        case .version(_):
            // Version declarations don't affect memory layout
            break

        case .princ(let princ):
            // PRINC is compile-time only, but analyze text for any embedded strings
            try analyzeExpression(princ.text)

        case .sname(_):
            // SNAME is compile-time metadata only, doesn't affect memory layout
            break

        case .set(_):
            // SET is compile-time configuration only, doesn't affect memory layout
            break

        case .directions(let directions):
            // DIRECTIONS creates runtime constants and data structures
            // Add direction constants to symbol table (P?NORTH, P?EAST, etc.)
            for (index, direction) in directions.directions.enumerated() {
                let constantName = "P?\(direction.uppercased())"
                memoryLayout.addConstant(constantName, value: .number(Int16(index + 1)))
            }

        case .syntax(let syntax):
            // Process SYNTAX declaration for parser table generation
            if var vocabManager = memoryLayout.vocabularyManager,
               var syntaxBuilder = memoryLayout.syntaxTableBuilder {
                try syntaxBuilder.addSyntax(syntax, vocabularyManager: &vocabManager)
                memoryLayout.vocabularyManager = vocabManager
                memoryLayout.syntaxTableBuilder = syntaxBuilder
            }

        case .synonym(let synonym):
            // Process SYNONYM declaration for dictionary with type information
            if var vocabManager = memoryLayout.vocabularyManager {
                let canonicalWord = synonym.canonical

                // Add canonical word with proper type classification
                switch synonym.type {
                case .preposition:
                    vocabManager.addWord(canonicalWord, type: .preposition)
                case .verb:
                    _ = vocabManager.addVerb(canonicalWord)
                case .adjective:
                    vocabManager.addWord(canonicalWord, type: .adjective)
                case .generic:
                    // Generic synonyms don't get special type classification
                    // They'll be typed by their usage in SYNTAX declarations
                    break
                }

                // Add synonym relationships (canonical + all synonyms)
                vocabManager.addSynonym(words: [canonicalWord] + synonym.words)
                memoryLayout.vocabularyManager = vocabManager
            }

        case .buzz(let buzz):
            // Process BUZZ declaration for parser ignore list
            if var vocabManager = memoryLayout.vocabularyManager {
                vocabManager.addBuzzwords(buzz.words)
                memoryLayout.vocabularyManager = vocabManager
            }

        case .defmac(_):
            // DEFMAC declarations are handled during preprocessing
            // They should not appear in the final declaration list for code generation
            break

        case .insertFile(_):
            // INSERT-FILE declarations should have been processed by the parser
            // and should not appear in the final declaration list
            throw CodeGenerationError(.invalidInstruction("INSERT-FILE declaration should not reach code generator"))

        case .zipOptions(_):
            // ZIP-OPTIONS declarations are compile-time configuration
            // They don't affect memory layout; they're used by the assembler
            break

        case .orderObjects(_):
            // ORDER-OBJECTS? declarations are compile-time configuration
            // They don't affect memory layout; they affect object table ordering
            break

        case .orderTree(_):
            // ORDER-TREE? declarations are compile-time configuration
            // They don't affect memory layout; they affect object tree ordering
            break

        case .orderFlags(_):
            // ORDER-FLAGS? declarations are compile-time configuration
            // They don't affect memory layout; they affect flag table ordering
            break

        case .routineFlags(_):
            // ROUTINE-FLAGS declarations are compile-time configuration
            // They don't affect memory layout; they set flags for the next routine
            break

        case .fileFlags(_):
            // FILE-FLAGS declarations are compile-time configuration
            // They don't affect memory layout; they configure file-level compilation flags
            break
        }
    }

    private mutating func analyzeExpression(_ expression: ZILExpression) throws {
        switch expression {
        case .string(let content, _):
            _ = memoryLayout.addString(content)

        case .globalVariable(let name, _):
            memoryLayout.addGlobal(name)

        case .propertyReference(let name, _):
            memoryLayout.addProperty(name)

        case .list(let elements, _):
            for element in elements {
                try analyzeExpression(element)
            }

        default:
            break
        }
    }

    private func evaluateConstantExpression(_ expression: ZILExpression) throws -> ZValue {
        switch expression {
        case .number(let value, _):
            return .number(Int16(value))
        case .string(let content, _):
            return .string(content)
        case .atom(let name, _):
            return .atom(name)
        default:
            throw CodeGenerationError(.typeSystemError("Cannot evaluate constant expression: \(expression)"))
        }
    }

    // MARK: - Object Processing Helpers

    /// Extract parent name from object properties (from IN property)
    private func extractParentName(from properties: [ZILObjectProperty]) -> String? {
        for property in properties {
            if property.name.uppercased() == "IN" {
                // Extract atom name from expression
                if case .atom(let parentName, _) = property.value {
                    return parentName
                }
            }
        }
        return nil
    }

    /// Extract flags from object properties (from FLAGS property)
    private func extractFlags(from properties: [ZILObjectProperty]) -> [String] {
        for property in properties {
            if property.name.uppercased() == "FLAGS" {
                // FLAGS can be a single atom or a list of atoms
                return extractFlagNames(from: property.value)
            }
        }
        return []
    }

    /// Extract flag names from an expression
    private func extractFlagNames(from expression: ZILExpression) -> [String] {
        switch expression {
        case .atom(let name, _):
            return [name]
        case .list(let elements, _):
            var flags: [String] = []
            for element in elements {
                flags.append(contentsOf: extractFlagNames(from: element))
            }
            return flags
        default:
            return []
        }
    }

    /// Convert ZIL expression to PropertyValue
    private func convertToPropertyValue(_ expression: ZILExpression) throws -> PropertyValue {
        switch expression {
        case .number(let value, _):
            return .integer(Int16(value))
        case .string(let content, _):
            return .string(content)
        case .atom(let name, _):
            // Could be object, routine, table, or general atom reference
            // Context determines the type - for now use general atom
            return .atom(name)
        case .list(let elements, _):
            var values: [PropertyValue] = []
            for element in elements {
                values.append(try convertToPropertyValue(element))
            }
            return .list(values)
        case .globalVariable(let name, _):
            return .atom(name)
        default:
            throw CodeGenerationError(.typeSystemError("Cannot convert expression to property value: \(expression)"))
        }
    }

    // MARK: - Header Generation

    private mutating func generateHeader() throws {
        if shouldIncludeHeaders {
            output.append("; ZAP Assembly Code Generated by ZIL Compiler")
            output.append("; Target Z-Machine Version: \(version.rawValue)")
            output.append("; Generated: \(Date())")
            output.append("; Optimization Level: \(optimizationLevel)")
            output.append("")
        }

        // Version directive - always included
        output.append(".ZVERSION \(version.rawValue)")

        if shouldIncludeHeaders {
            output.append("")

            // Memory limits based on version - only in debug mode
            switch version {
            case .v3:
                output.append("; Z-Machine v3: 128KB limit, 255 objects max")
            case .v4:
                output.append("; Z-Machine v4: 128KB limit, 65535 objects max, sound")
            case .v5:
                output.append("; Z-Machine v5: 256KB limit, 65535 objects max, color, mouse")
            case .v6:
                output.append("; Z-Machine v6: 256KB limit, graphics, multiple windows")
            case .v7:
                output.append("; Z-Machine v7: 256KB limit, extended features")
            case .v8:
                output.append("; Z-Machine v8: Unicode support, modern extensions")
            }
            output.append("")
        }
    }

    // MARK: - Constants Section

    private mutating func generateConstantsSection() throws {
        guard !memoryLayout.constants.isEmpty else { return }

        if shouldIncludeSections {
            output.append("; ===== CONSTANTS SECTION =====")
            output.append("")
        }

        for (name, value) in memoryLayout.constants {
            let zapValue = try convertZValueToZAP(value)
            output.append(".CONSTANT \(name) \(zapValue)")
        }

        if shouldIncludeSections {
            output.append("")
        }
    }

    // MARK: - Parser Tables Section

    private mutating func generateParserTablesSection() throws {
        guard let vocabManager = memoryLayout.vocabularyManager,
              let syntaxBuilder = memoryLayout.syntaxTableBuilder else {
            return
        }

        if shouldIncludeSections {
            output.append("; ===== PARSER TABLES SECTION =====")
            output.append("")
        }

        // 1. Generate verb constants
        let verbConstants = vocabManager.getVerbConstants()
        if !verbConstants.isEmpty {
            output.append("; Verb Constants")
            for (verb, number) in verbConstants {
                output.append(".CONSTANT V?\(verb) \(number)")
            }
            output.append("")
        }

        // 2. Generate vocabulary/dictionary table
        let dictionary = vocabManager.generateDictionary()
        if !dictionary.isEmpty {
            output.append("; Vocabulary Table (Dictionary)")
            output.append("VOCAB::")
            output.append("\t.BYTE 0\t; Number of separators")
            output.append("\t.BYTE 9\t; Entry length (9 bytes for v5)")
            output.append("\t.WORD \(dictionary.count)\t; Number of entries")
            output.append("")

            for entry in dictionary {
                output.append("\t; \(entry.word) (\(describeWordType(entry.type)))")

                // Output encoded word (6 bytes for v3, 9 for v5)
                let hexBytes = entry.encoded.map { String(format: "$%02X", $0) }.joined(separator: ",")
                output.append("\t.BYTE \(hexBytes)")

                // Output word type flags
                var flags = entry.type.rawValue
                if let verbNum = entry.verbNumber {
                    // Encode verb number in flags
                    flags |= (verbNum & 0x03) << 6  // Low 2 bits in flags byte
                }
                output.append("\t.BYTE $\(String(format: "%02X", flags))")
                output.append("")
            }
        }

        // 3. Generate syntax tables
        let syntaxLines = syntaxBuilder.generateZAPCode()
        if !syntaxLines.isEmpty {
            output.append("; Syntax Action Tables")
            output.append(contentsOf: syntaxLines)
            output.append("")
        }

        if shouldIncludeSections {
            output.append("")
        }
    }

    /// Describe word type for comments
    private func describeWordType(_ type: WordType) -> String {
        var types: [String] = []
        if type.contains(.direction) { types.append("direction") }
        if type.contains(.verb) { types.append("verb") }
        if type.contains(.preposition) { types.append("prep") }
        if type.contains(.adjective) { types.append("adj") }
        if type.contains(.noun) { types.append("noun") }
        if type.contains(.buzzword) { types.append("buzz") }
        return types.isEmpty ? "unknown" : types.joined(separator: ", ")
    }

    // MARK: - Globals Section

    private mutating func generateGlobalsSection() throws {
        guard !memoryLayout.globals.isEmpty else { return }

        if shouldIncludeSections {
            output.append("; ===== GLOBALS SECTION =====")
            output.append("")
        }

        for global in memoryLayout.globals {
            output.append(".GLOBAL\t\(global)")
        }

        if shouldIncludeSections {
            output.append("")
        }
    }

    // MARK: - Properties Section

    private mutating func generatePropertiesSection() throws {
        guard !memoryLayout.properties.isEmpty else { return }

        output.append("; ===== PROPERTIES SECTION =====")
        output.append("")

        for property in memoryLayout.properties {
            output.append(".PROPERTY\t\(property)")
        }
        output.append("")
    }

    // MARK: - Objects Section

    private mutating func generateObjectsSection(_ declarations: [ZILDeclaration]) throws {
        guard var builder = objectTreeBuilder else { return }

        // Build the object tree with resolved relationships
        let compiledObjects = try builder.build()

        // Get updated managers after build (flags and properties have been assigned)
        flagManager = builder.getFlagManager()
        propertyDefManager = builder.getPropertyManager()

        guard !compiledObjects.isEmpty else { return }

        output.append("; ===== OBJECTS SECTION =====")
        output.append("")

        // Build ID to name mapping for relationship references
        for compiledObject in compiledObjects {
            objectIDToNameMap[compiledObject.id] = compiledObject.name
        }

        // Generate single-line .OBJECT directives
        for compiledObject in compiledObjects {
            try generateObjectDirective(compiledObject)
        }

        output.append("")
        output.append("; ===== PROPERTY TABLES =====")
        output.append("")

        // Generate property table blocks
        for compiledObject in compiledObjects {
            try generatePropertyTable(compiledObject)
        }
    }

    // MARK: - Functions Section

    private mutating func generateFunctionsSection(_ declarations: [ZILDeclaration]) throws {
        let routines = declarations.compactMap { declaration -> ZILRoutineDeclaration? in
            if case .routine(let routine) = declaration {
                return routine
            }
            return nil
        }

        guard !routines.isEmpty else { return }

        if shouldIncludeSections {
            output.append("; ===== FUNCTIONS SECTION =====")
            output.append("")
        }

        for routine in routines {
            try generateRoutine(routine)
        }
    }

    // MARK: - Strings Section

    private mutating func generateStringsSection() throws {
        guard !memoryLayout.strings.isEmpty else { return }

        output.append("; ===== STRINGS SECTION =====")
        output.append("")

        for (index, string) in memoryLayout.strings.enumerated() {
            output.append(".STRING STR\(index) \"\(escapeString(string))\"")
        }
        output.append("")
    }

    // MARK: - Tables Section

    private mutating func generateTablesSection() throws {
        guard !memoryLayout.tables.isEmpty else { return }

        output.append("; ===== TABLES SECTION =====")
        output.append("")

        for (tableName, tableType, elements) in memoryLayout.tables {
            let typeDirective: String
            switch tableType {
            case .itable:
                typeDirective = ".ITABLE"
            case .ltable:
                typeDirective = ".LTABLE"
            case .table:
                typeDirective = ".TABLE"
            case .ptable:
                typeDirective = ".PTABLE"
            case .btable:
                typeDirective = ".BTABLE"
            }
            output.append("\(typeDirective) \(tableName) \(elements.joined(separator: " "))")
        }
        output.append("")
    }

    // MARK: - Object Generation

    /// Generate single-line .OBJECT directive in authentic Infocom format
    private mutating func generateObjectDirective(_ object: CompiledObject) throws {
        // Reconstruct flag expressions from attribute bytes
        let flagExpressions = reconstructFlagExpressions(from: object.attributes)

        // Build parameter list
        var params: [String] = [object.name]

        // Add attribute words (v3=2, v4+=3)
        params.append(contentsOf: flagExpressions)

        // Add parent (ID to name lookup or "0")
        params.append(objectIDToName(object.parentID))

        // Add sibling
        params.append(objectIDToName(object.siblingID))

        // Add child
        params.append(objectIDToName(object.childID))

        // Add property table reference
        params.append("T?\(object.name)")

        // Generate single-line directive with tab indentation
        output.append("\t.OBJECT \(params.joined(separator: ","))")
    }

    /// Convert object ID to name (or "0" if no relationship)
    private func objectIDToName(_ id: Int) -> String {
        if id == 0 {
            return "0"
        }
        return objectIDToNameMap[id] ?? "0"
    }

    /// Reconstruct flag expressions from attribute byte array
    private func reconstructFlagExpressions(from attributes: [UInt8]) -> [String] {
        let wordCount = version.rawValue >= 4 ? 3 : 2
        var expressions: [String] = []

        for wordIndex in 0..<wordCount {
            // Extract 16 bits from attribute bytes (MSB first)
            let byteIndex = wordIndex * 2
            guard byteIndex + 1 < attributes.count else {
                expressions.append("0x0000")
                continue
            }

            let highByte = attributes[byteIndex]
            let lowByte = attributes[byteIndex + 1]
            let word = (UInt16(highByte) << 8) | UInt16(lowByte)

            if word == 0 {
                expressions.append("0x0000")
                continue
            }

            // Find all set bits in this word
            var flagNames: [String] = []
            for bitPosition in 0..<16 {
                let attributeNumber = wordIndex * 16 + bitPosition
                if (word & (1 << (15 - bitPosition))) != 0 {
                    // Bit is set - find the flag name
                    if let flagName = flagManager.getFlagName(for: attributeNumber) {
                        flagNames.append("FX?\(flagName)")
                    } else {
                        // Unknown flag - use bit position
                        flagNames.append("FX?ATTR\(attributeNumber)")
                    }
                }
            }

            expressions.append(flagNames.isEmpty ? "0x0000" : flagNames.joined(separator: "+"))
        }

        return expressions
    }

    /// Generate property table block for an object
    private mutating func generatePropertyTable(_ object: CompiledObject) throws {
        // Property table label
        output.append("T?\(object.name)::\t.TABLE\t\t\t; TABLE FOR OBJECT \(object.name)")

        // Generate short name using .STRL directive
        let shortNameStr = extractShortName(from: object.shortName)
        output.append("\t.STRL \"\(escapeString(shortNameStr))\"")

        // Generate properties (already in descending order from ObjectTreeBuilder)
        for property in object.properties {
            try generatePropertyEntry(property, object: object)
        }

        // Terminator
        output.append("\t.BYTE\t0")
        output.append("\t.ENDT")
        output.append("")
    }

    /// Extract short name string from encoded bytes
    private func extractShortName(from encoded: [UInt8]) -> String {
        // First byte is length in words, followed by Z-encoded text
        // For now, return placeholder - proper Z-decoding would be needed
        // This is acceptable as the bytes are already properly encoded
        return "obj"  // Placeholder - assembler will use the encoded bytes
    }

    /// Generate a property entry in the property table
    private mutating func generatePropertyEntry(_ property: CompiledProperty, object: CompiledObject) throws {
        // Get property data size
        let size: Int
        switch property.encoding {
        case .bytes(let data):
            size = data.count
        case .routineReference, .stringReference, .tableReference:
            size = 2  // Packed addresses are 2 bytes
        }

        // Generate property header
        let propName = "P?\(property.name)"
        output.append("\t.PROP \(size),\(propName)")

        // Generate property data
        switch property.encoding {
        case .bytes(let data):
            // Emit raw bytes using .BYTE directive
            if data.isEmpty {
                // No data bytes
            } else if data.count == 1 {
                output.append("\t\t.BYTE\t\(data[0])")
            } else if data.count == 2 {
                // Could be a word
                let word = (UInt16(data[0]) << 8) | UInt16(data[1])
                output.append("\t\t.WORD\t\(word)")
            } else {
                // Multiple bytes - emit as separate .BYTE directives or comma-separated
                let byteList = data.map { String($0) }.joined(separator: ",")
                output.append("\t\t.BYTE\t\(byteList)")
            }

        case .routineReference(let name):
            output.append("\t\t\(name)")

        case .stringReference(let text):
            // Add to string table and reference
            let strIndex = memoryLayout.addString(text)
            output.append("\t\tSTR\(strIndex)")

        case .tableReference(let name):
            output.append("\t\t\(name)")
        }
    }

    // MARK: - Routine Generation

    private mutating func generateRoutine(_ routine: ZILRoutineDeclaration) throws {
        context.enterFunction(routine.name)
        defer { context.exitFunction() }

        // Create InstructionBuilder for this routine
        let builder = InstructionBuilder()
        builder.pushContext(routine.name)
        defer { builder.popContext() }

        output.append("")
        output.append("; Function: \(routine.name)")

        // Generate .FUNCT directive with parameters (use Infocom tab formatting)
        var functLine = "\t.FUNCT\t\(routine.name)"

        // Add required parameters
        if !routine.parameters.isEmpty {
            functLine += "," + routine.parameters.joined(separator: ",")
            for param in routine.parameters {
                context.addLocalVariable(param)
            }
        }

        // Add optional parameters with defaults
        for optional in routine.optionalParameters {
            context.addLocalVariable(optional.name)
            if let defaultValue = optional.defaultValue {
                let defaultExpr = try generateExpression(defaultValue, using: builder)
                functLine += ",\(optional.name)=\(defaultExpr)"
            } else {
                functLine += ",\(optional.name)"
            }
        }

        // Add auxiliary variables
        for aux in routine.auxiliaryVariables {
            context.addLocalVariable(aux.name)
            functLine += ",\(aux.name)"
        }

        output.append(functLine)

        // Generate function body - handle both statements and expressions
        for expression in routine.body {
            // Check if this is a statement (list starting with statement atom) or expression
            if case .list(let elements, let location) = expression,
               !elements.isEmpty,
               case .atom(let op, _) = elements[0] {

                let operands = Array(elements.dropFirst())

                // Handle statements that generate instructions directly
                switch op.uppercased() {
                case "COND":
                    let instructions = try generateCond(operands, at: location)
                    for instruction in instructions {
                        builder.emit(instruction)
                    }
                case "SET", "SETG":
                    let instructions = try generateSet(operands, isGlobal: op.uppercased() == "SETG", at: location)
                    for instruction in instructions {
                        builder.emit(instruction)
                    }
                case "TELL":
                    let instructions = try generateTell(operands, at: location)
                    for instruction in instructions {
                        builder.emit(instruction)
                    }
                case "PRINT":
                    let instructions = try generatePrint(operands, at: location)
                    for instruction in instructions {
                        builder.emit(instruction)
                    }
                case "PRINTR":
                    let instructions = try generatePrintR(operands, at: location)
                    for instruction in instructions {
                        builder.emit(instruction)
                    }
                case "MOVE":
                    let instructions = try generateMove(operands, at: location)
                    for instruction in instructions {
                        builder.emit(instruction)
                    }
                case "FSET":
                    let instructions = try generateFSet(operands, at: location)
                    for instruction in instructions {
                        builder.emit(instruction)
                    }
                case "FCLEAR":
                    let instructions = try generateFClear(operands, at: location)
                    for instruction in instructions {
                        builder.emit(instruction)
                    }
                case "REPEAT":
                    let instructions = try generateRepeat(operands, at: location)
                    for instruction in instructions {
                        builder.emit(instruction)
                    }
                case "WHILE":
                    let instructions = try generateWhile(operands, at: location)
                    for instruction in instructions {
                        builder.emit(instruction)
                    }
                case "RETURN":
                    let instructions = try generateReturn(operands, at: location)
                    for instruction in instructions {
                        builder.emit(instruction)
                    }
                case "AND":
                    let instructions = try generateAnd(operands, at: location)
                    for instruction in instructions {
                        builder.emit(instruction)
                    }
                case "OR":
                    let instructions = try generateOr(operands, at: location)
                    for instruction in instructions {
                        builder.emit(instruction)
                    }
                case "NOT":
                    let instructions = try generateNot(operands, at: location)
                    for instruction in instructions {
                        builder.emit(instruction)
                    }
                case "RTRUE", "RFALSE", "QUIT", "RESTART":
                    builder.emit(op.uppercased())
                default:
                    // For other expressions (like function calls), use expression generator
                    _ = try generateExpression(expression, using: builder)
                }
            } else {
                // Simple expressions (atoms, numbers, variables)
                // Check if it's a simple statement atom
                if case .atom(let atomName, _) = expression {
                    switch atomName.uppercased() {
                    case "RTRUE", "RFALSE", "QUIT", "RESTART":
                        builder.emit(atomName.uppercased())
                    default:
                        // Other simple expressions don't generate instructions when used as statements
                        _ = try generateExpression(expression, using: builder)
                    }
                } else {
                    // Other simple expressions (numbers, variables)
                    _ = try generateExpression(expression, using: builder)
                }
            }
        }

        // Collect all instructions from builder and apply Infocom formatting
        let instructions = builder.getInstructions()
        let preFormattedInstructions = instructions.map(formatInstruction)
        let formattedInstructions = applyInfocomFormatting(preFormattedInstructions)
        for instruction in formattedInstructions {
            output.append(instruction)
        }

        // Ensure routine ends with RTRUE if it doesn't already have an explicit return
        let lastInstruction = instructions.last?.trimmingCharacters(in: .whitespaces) ?? ""
        let hasExplicitReturn = lastInstruction.starts(with: "RTRUE") ||
                               lastInstruction.starts(with: "RFALSE") ||
                               lastInstruction.starts(with: "RETURN") ||
                               lastInstruction.starts(with: "PRINTR")  // PRINTR implies return

        if !hasExplicitReturn {
            output.append(formatInstruction("RTRUE"))
        }

        // End function with .ENDI directive (Infocom style)
        output.append("\t.ENDI")
        output.append("")
    }

    // MARK: - Expression Generation (Legacy - to be removed)

    private mutating func generateExpression(_ expression: ZILExpression) throws -> String {
        // Create a temporary builder for backward compatibility
        let builder = InstructionBuilder()
        let result = try generateExpression(expression, using: builder)

        // Emit any generated instructions to main output
        for instruction in builder.getInstructions() {
            output.append(formatInstruction(instruction))
        }

        return result
    }

    private mutating func generateExpressionAsInstructions(_ expression: ZILExpression) throws -> [String] {
        switch expression {
        case .list(let elements, let location):
            // Handle empty list - common in ZIL for empty variable initialization lists
            if elements.isEmpty {
                return [] // Empty list generates no instructions
            }
            return try generateListAsInstructions(elements, at: location)
        default:
            let expr = try generateExpression(expression)
            return [expr]
        }
    }

    private func generateAtom(_ name: String) throws -> String {
        // Check if it's a built-in ZIL instruction
        if let zapInstruction = mapZILToZAP(name) {
            return zapInstruction
        }

        // Check symbol table for user-defined symbols
        if let symbol = symbolTable.lookupSymbol(name: name) {
            switch symbol.type {
            case .routine:
                return name
            case .object:
                return name
            case .globalVariable:
                return "'\(name)"
            default:
                break
            }
        }

        // Return as-is if it's a known atom
        return name
    }

    // Legacy method - delegates to InstructionBuilder version

    private mutating func generateListAsInstructions(_ elements: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard !elements.isEmpty else {
            // Handle empty list - common in ZIL for empty variable initialization lists
            return [] // Empty list generates no instructions
        }

        guard case .atom(let op, _) = elements[0] else {
            throw CodeGenerationError(.invalidInstruction("list must start with atom"), at: location)
        }

        let operands = Array(elements.dropFirst())

        // Handle special ZIL constructs
        switch op.uppercased() {
        case "COND":
            return try generateCond(operands, at: location)
        case "AND":
            return try generateAnd(operands, at: location)
        case "OR":
            return try generateOr(operands, at: location)
        case "NOT":
            return try generateNot(operands, at: location)
        case "SET", "SETG":
            return try generateSet(operands, isGlobal: op.uppercased() == "SETG", at: location)
        case "TELL":
            return try generateTell(operands, at: location)
        case "PRINT":
            return try generatePrint(operands, at: location)
        case "PRINTR":
            return try generatePrintR(operands, at: location)
        case "PRINTN":
            return try generatePrintN(operands, at: location)
        case "PRINTD":
            return try generatePrintD(operands, at: location)
        case "MOVE":
            return try generateMove(operands, at: location)
        case "REMOVE":
            return try generateRemove(operands, at: location)
        case "FSET":
            return try generateFSet(operands, at: location)
        case "FCLEAR":
            return try generateFClear(operands, at: location)
        case "PUT":
            return try generatePut(operands, at: location)
        case "PUTP":
            return try generatePutP(operands, at: location)
        case "REPEAT":
            return try generateRepeat(operands, at: location)
        case "WHILE":
            return try generateWhile(operands, at: location)
        case "DO":
            return try generateDo(operands, at: location)
        case "MAPF":
            return try generateMapF(operands, at: location)
        case "MAPR":
            return try generateMapR(operands, at: location)
        case "PROG":
            return try generateProg(operands, at: location)
        case "RETURN":
            return try generateReturn(operands, at: location)
        case "RTRUE":
            return ["RTRUE"]
        case "RFALSE":
            return ["RFALSE"]
        case "QUIT":
            return ["QUIT"]
        case "RESTART":
            return ["RESTART"]
        case "SAVE":
            return try generateSave(operands, at: location)
        case "RESTORE":
            return try generateRestore(operands, at: location)
        case "VERIFY":
            return ["VERIFY"]
        case "FSET?":
            return try generateFSetTest(operands, at: location)
        case "IN?":
            return try generateInTest(operands, at: location)
        case "VERB?":
            return try generateVerbTest(operands, at: location)
        default:
            return try generateFunctionCall(op, operands, at: location)
        }
    }

    // MARK: - Expression Generation with InstructionBuilder

    private mutating func generateExpression(_ expression: ZILExpression, using builder: InstructionBuilder) throws -> String {
        switch expression {
        case .atom(let name, _):
            return try generateAtom(name)

        case .number(let value, _):
            return "\(value)"

        case .string(let content, _):
            let index = memoryLayout.addString(content)
            return "STR\(index)"

        case .globalVariable(let name, _):
            return "'\(name)"

        case .localVariable(let name, _):
            if context.isLocalVariable(name) {
                return name
            } else {
                // Might be a global accessed without comma prefix
                return "'\(name)"
            }

        case .propertyReference(let name, _):
            return "P?\(name)"

        case .flagReference(let name, _):
            return "F?\(name)"

        case .list(let elements, let location):
            return try generateListExpressionWithBuilder(elements, at: location, using: builder)

        case .table(let tableType, let elements, let location):
            return try generateTableLiteral(tableType, elements: elements, at: location, using: builder)

        case .indirection(let targetExpression, _):
            // Generate code for indirection - dereference the target at runtime
            let targetCode = try generateExpression(targetExpression, using: builder)
            return "!\(targetCode)"
        }
    }

    private mutating func generateListExpressionWithBuilder(_ elements: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard !elements.isEmpty else {
            throw CodeGenerationError(.invalidInstruction("empty list"), at: location)
        }

        guard case .atom(let op, _) = elements[0] else {
            throw CodeGenerationError(.invalidInstruction("list must start with atom"), at: location)
        }

        let operands = Array(elements.dropFirst())

        switch op.uppercased() {
        // Arithmetic Operations
        case "+", "ADD":
            return try generateArithmeticExpression("ADD", operands, at: location, using: builder)
        case "-", "SUB":
            return try generateArithmeticExpression("SUB", operands, at: location, using: builder)
        case "*", "MUL":
            return try generateArithmeticExpression("MUL", operands, at: location, using: builder)
        case "/", "DIV":
            return try generateArithmeticExpression("DIV", operands, at: location, using: builder)
        case "MOD":
            return try generateArithmeticExpression("MOD", operands, at: location, using: builder)

        // Comparison Operations
        case "EQUAL?", "=?":
            return try generateComparisonExpression("EQUAL?", operands, at: location, using: builder)
        case "GREATER?", ">?":
            return try generateComparisonExpression("GRTR?", operands, at: location, using: builder)
        case "LESS?", "<?":
            return try generateComparisonExpression("LESS?", operands, at: location, using: builder)
        case "ZERO?", "0?":
            return try generateUnaryExpression("ZERO?", operands, at: location, using: builder)

        // Memory and Object Operations (return values directly)
        case "GET":
            return try generateGetExpression(operands, at: location, using: builder)
        case "GETP":
            return try generateGetPExpression(operands, at: location, using: builder)
        case "GETPT":
            return try generateGetPTExpression(operands, at: location, using: builder)
        case "PTSIZE":
            return try generatePTSizeExpression(operands, at: location, using: builder)
        case "LOC":
            return try generateLocExpression(operands, at: location, using: builder)
        case "FIRST?":
            return try generateFirstExpression(operands, at: location, using: builder)
        case "NEXT?":
            return try generateNextExpression(operands, at: location, using: builder)

        // Logical Operations (short-circuit evaluation)
        case "AND":
            return try generateAndExpression(operands, at: location, using: builder)
        case "OR":
            return try generateOrExpression(operands, at: location, using: builder)
        case "NOT":
            return try generateNotExpression(operands, at: location, using: builder)

        // Assignment Operations (these return the assigned value)
        case "SET", "SETG":
            return try generateSetExpression(op, operands, at: location, using: builder)

        // Control Flow (these don't return values - should be handled elsewhere)
        case "COND":
            throw CodeGenerationError(.unsupportedExpression("COND cannot be used as expression value"), at: location)
        case "TELL":
            throw CodeGenerationError(.unsupportedExpression("TELL cannot be used as expression value"), at: location)

        // Function Calls
        default:
            return try generateFunctionCallExpression(op, operands, at: location, using: builder)
        }
    }

    // MARK: - Arithmetic Expression Generation

    private mutating func generateArithmeticExpression(_ operation: String, _ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard !operands.isEmpty else {
            throw CodeGenerationError(.invalidInstruction("\(operation) requires at least 1 operand"), at: location)
        }

        // Generate operands first (left-to-right evaluation)
        let operandResults = try operands.map { try generateExpression($0, using: builder) }

        if operandResults.count == 1 {
            // Unary operation (like negation)
            if operation == "SUB" {
                if builder.shouldUseStack() {
                    return builder.emitToStack("SUB 0,\(operandResults[0])")
                } else {
                    return builder.emitWithResult("SUB 0,\(operandResults[0])")
                }
            } else {
                // For other operations, single operand just returns itself
                return operandResults[0]
            }
        } else if operandResults.count == 2 {
            // Binary operation - use stack operations when appropriate
            if builder.shouldUseStack() {
                return builder.emitToStack("\(operation) \(operandResults[0]),\(operandResults[1])")
            } else {
                return builder.emitWithResult("\(operation) \(operandResults[0]),\(operandResults[1])")
            }
        } else {
            // Multiple operands - chain operations left to right using stack
            var result = operandResults[0]
            for i in 1..<operandResults.count {
                if i == operandResults.count - 1 && builder.shouldUseStack() {
                    // Last operation can go to stack if beneficial
                    result = builder.emitToStack("\(operation) \(result),\(operandResults[i])")
                } else {
                    result = builder.emitWithResult("\(operation) \(result),\(operandResults[i])")
                }
            }
            return result
        }
    }

    // MARK: - Comparison Expression Generation

    private mutating func generateComparisonExpression(_ operation: String, _ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard operands.count == 2 else {
            throw CodeGenerationError(.invalidInstruction("\(operation) requires exactly 2 operands"), at: location)
        }

        let operand1 = try generateExpression(operands[0], using: builder)
        let operand2 = try generateExpression(operands[1], using: builder)

        // Comparison operations in ZAP return true/false, so we need conditional logic
        let trueLabel = builder.generateLabel("TRUE")
        let endLabel = builder.generateLabel("END")
        let resultTemp = builder.generateTempVar()

        builder.emit("\(operation) \(operand1),\(operand2) /\(trueLabel)")
        builder.emit("SET \(resultTemp),<>") // False
        builder.emit("JUMP \(endLabel)")
        builder.emit("\(trueLabel):")
        builder.emit("SET \(resultTemp),T") // True
        builder.emit("\(endLabel):")

        return resultTemp
    }

    private mutating func generateUnaryExpression(_ operation: String, _ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard operands.count == 1 else {
            throw CodeGenerationError(.invalidInstruction("\(operation) requires exactly 1 operand"), at: location)
        }

        let operand = try generateExpression(operands[0], using: builder)

        // Unary operations that return true/false
        let trueLabel = builder.generateLabel("TRUE")
        let endLabel = builder.generateLabel("END")
        let resultTemp = builder.generateTempVar()

        builder.emit("\(operation) \(operand) /\(trueLabel)")
        builder.emit("SET \(resultTemp),<>") // False
        builder.emit("JUMP \(endLabel)")
        builder.emit("\(trueLabel):")
        builder.emit("SET \(resultTemp),T") // True
        builder.emit("\(endLabel):")

        return resultTemp
    }

    // MARK: - Assignment Expression Generation

    private mutating func generateSetExpression(_ operation: String, _ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard operands.count == 2 else {
            throw CodeGenerationError(.invalidInstruction("\(operation) requires exactly 2 operands"), at: location)
        }

        let variable = try generateExpression(operands[0], using: builder)
        let value = try generateExpression(operands[1], using: builder)

        // Use direct assignment optimization - SET returns the assigned value
        if operation.uppercased() == "SETG" || variable.hasPrefix("'") {
            // For global assignments, use SET with global prefix (not SETG)
            let globalVar = variable.hasPrefix("'") ? variable : "'\(variable)"
            builder.emit("SET \(globalVar),\(value)")
            return value
        } else {
            // For local assignments, emit SET and return the value directly
            builder.emit("SET \(variable),\(value)")
            return value
        }
    }

    // MARK: - Memory Access Expression Generation

    private mutating func generateGetExpression(_ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard operands.count == 2 else {
            throw CodeGenerationError(.invalidInstruction("GET requires exactly 2 operands"), at: location)
        }

        let table = try generateExpression(operands[0], using: builder)
        let index = try generateExpression(operands[1], using: builder)

        // Use stack for intermediate result if beneficial, otherwise temp variable
        if builder.shouldUseStack() {
            return builder.emitToStack("GET \(table),\(index)")
        } else {
            return builder.emitWithResult("GET \(table),\(index)")
        }
    }

    private mutating func generateGetPExpression(_ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard operands.count == 2 else {
            throw CodeGenerationError(.invalidInstruction("GETP requires exactly 2 operands"), at: location)
        }

        let object = try generateExpression(operands[0], using: builder)
        let property = try generateExpression(operands[1], using: builder)

        // Use stack for intermediate result if beneficial, otherwise temp variable
        if builder.shouldUseStack() {
            return builder.emitToStack("GETP \(object),\(property)")
        } else {
            return builder.emitWithResult("GETP \(object),\(property)")
        }
    }

    private mutating func generateLocExpression(_ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard operands.count == 1 else {
            throw CodeGenerationError(.invalidInstruction("LOC requires exactly 1 operand"), at: location)
        }

        let object = try generateExpression(operands[0], using: builder)
        return builder.emitWithResult("LOC \(object)")
    }

    private mutating func generateFirstExpression(_ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard operands.count == 1 else {
            throw CodeGenerationError(.invalidInstruction("FIRST? requires exactly 1 operand"), at: location)
        }

        let object = try generateExpression(operands[0], using: builder)
        return builder.emitWithResult("FIRST? \(object)")
    }

    private mutating func generateNextExpression(_ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard operands.count == 1 else {
            throw CodeGenerationError(.invalidInstruction("NEXT? requires exactly 1 operand"), at: location)
        }

        let object = try generateExpression(operands[0], using: builder)
        return builder.emitWithResult("NEXT? \(object)")
    }

    private mutating func generateGetPTExpression(_ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard operands.count == 2 else {
            throw CodeGenerationError(.invalidInstruction("GETPT requires exactly 2 operands"), at: location)
        }

        let object = try generateExpression(operands[0], using: builder)
        let property = try generateExpression(operands[1], using: builder)

        // Use stack for intermediate result if beneficial, otherwise temp variable
        if builder.shouldUseStack() {
            return builder.emitToStack("GETPT \(object),\(property)")
        } else {
            return builder.emitWithResult("GETPT \(object),\(property)")
        }
    }

    private mutating func generatePTSizeExpression(_ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard operands.count == 1 else {
            throw CodeGenerationError(.invalidInstruction("PTSIZE requires exactly 1 operand"), at: location)
        }

        let table = try generateExpression(operands[0], using: builder)

        // Use stack for intermediate result if beneficial, otherwise temp variable
        if builder.shouldUseStack() {
            return builder.emitToStack("PTSIZE \(table)")
        } else {
            return builder.emitWithResult("PTSIZE \(table)")
        }
    }

    // MARK: - Logical Expression Generation (Optimized Infocom-Style)

    private mutating func generateAndExpression(_ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard !operands.isEmpty else {
            return "T" // Empty AND is true
        }

        if operands.count == 1 {
            // Single operand AND just returns the operand's truth value
            return try generateExpression(operands[0], using: builder)
        }

        // Infocom-style streamlined AND: each condition branches to FALSE on failure
        // No temp variables or intermediate labels - direct branching
        let falseLabel = builder.generateLabel("FALSE")
        let resultTemp = builder.generateTempVar()

        // Short-circuit evaluation: if any operand is false, branch directly to false result
        for operand in operands {
            try generateDirectConditionTest(operand, branchFalseTarget: falseLabel, using: builder)
        }

        // All operands were true - set result and continue
        builder.emit("SET \(resultTemp),T")
        let skipLabel = builder.generateLabel("SKIP")
        builder.emit("JUMP \(skipLabel)")

        // False case
        builder.emit("\(falseLabel):")
        builder.emit("SET \(resultTemp),<>")

        builder.emit("\(skipLabel):")
        return resultTemp
    }

    private mutating func generateOrExpression(_ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard !operands.isEmpty else {
            return "<>" // Empty OR is false
        }

        if operands.count == 1 {
            // Single operand OR just returns the operand's truth value
            return try generateExpression(operands[0], using: builder)
        }

        // Infocom-style streamlined OR: each condition branches to TRUE on success
        let trueLabel = builder.generateLabel("TRUE")
        let resultTemp = builder.generateTempVar()

        // Short-circuit evaluation: if any operand is true, branch directly to true result
        for operand in operands {
            try generateDirectConditionTest(operand, branchTrueTarget: trueLabel, using: builder)
        }

        // All operands were false - set result and continue
        builder.emit("SET \(resultTemp),<>")
        let skipLabel = builder.generateLabel("SKIP")
        builder.emit("JUMP \(skipLabel)")

        // True case
        builder.emit("\(trueLabel):")
        builder.emit("SET \(resultTemp),T")

        builder.emit("\(skipLabel):")
        return resultTemp
    }

    private mutating func generateNotExpression(_ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        guard operands.count == 1 else {
            throw CodeGenerationError(.invalidInstruction("NOT requires exactly 1 operand"), at: location)
        }

        // Optimized NOT: single condition test with inverted branching
        let trueLabel = builder.generateLabel("TRUE")
        let resultTemp = builder.generateTempVar()

        // NOT: if operand is false (zero), result is true
        try generateDirectConditionTest(operands[0], branchFalseTarget: trueLabel, using: builder)

        // Operand was true, so NOT is false
        builder.emit("SET \(resultTemp),<>")
        let skipLabel = builder.generateLabel("SKIP")
        builder.emit("JUMP \(skipLabel)")

        // Operand was false, so NOT is true
        builder.emit("\(trueLabel):")
        builder.emit("SET \(resultTemp),T")

        builder.emit("\(skipLabel):")
        return resultTemp
    }

    // MARK: - Direct Condition Testing (Infocom-Style Optimization)

    private mutating func generateDirectConditionTest(_ condition: ZILExpression, branchFalseTarget: String? = nil, branchTrueTarget: String? = nil, using builder: InstructionBuilder) throws {
        switch condition {
        case .list(let elements, let location) where !elements.isEmpty:
            guard case .atom(let op, _) = elements[0] else {
                throw CodeGenerationError(.invalidInstruction("condition must start with atom"), at: location)
            }

            let operands = Array(elements.dropFirst())

            switch op.uppercased() {
            case "EQUAL?", "=?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("EQUAL? requires 2 operands"), at: location)
                }
                let arg1 = try generateExpression(operands[0], using: builder)
                let arg2 = try generateExpression(operands[1], using: builder)

                if let falseTarget = branchFalseTarget {
                    builder.emit("EQUAL? \(arg1),\(arg2) /\(falseTarget)")
                } else if let trueTarget = branchTrueTarget {
                    builder.emit("EQUAL? \(arg1),\(arg2) \\\(trueTarget)")
                }

            case "ZERO?", "0?":
                guard operands.count == 1 else {
                    throw CodeGenerationError(.invalidInstruction("ZERO? requires 1 operand"), at: location)
                }
                let arg = try generateExpression(operands[0], using: builder)

                if let falseTarget = branchFalseTarget {
                    builder.emit("ZERO? \(arg) /\(falseTarget)")
                } else if let trueTarget = branchTrueTarget {
                    builder.emit("ZERO? \(arg) \\\(trueTarget)")
                }

            case "FSET?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("FSET? requires 2 operands"), at: location)
                }
                let obj = try generateExpression(operands[0], using: builder)
                let flag = try generateExpression(operands[1], using: builder)

                if let falseTarget = branchFalseTarget {
                    builder.emit("FSET? \(obj),\(flag) /\(falseTarget)")
                } else if let trueTarget = branchTrueTarget {
                    builder.emit("FSET? \(obj),\(flag) \\\(trueTarget)")
                }

            default:
                // Complex expression - evaluate and test result
                let result = try generateExpression(condition, using: builder)

                if let falseTarget = branchFalseTarget {
                    builder.emit("ZERO? \(result) /\(falseTarget)")
                } else if let trueTarget = branchTrueTarget {
                    builder.emit("ZERO? \(result) \\\(trueTarget)")
                }
            }

        default:
            // Simple value test (non-zero is true)
            let value = try generateExpression(condition, using: builder)

            if let falseTarget = branchFalseTarget {
                builder.emit("ZERO? \(value) /\(falseTarget)")
            } else if let trueTarget = branchTrueTarget {
                builder.emit("ZERO? \(value) \\\(trueTarget)")
            }
        }
    }

    // MARK: - Function Call Expression Generation

    private mutating func generateFunctionCallExpression(_ function: String, _ operands: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        // Generate arguments first (left-to-right evaluation)
        let args = try operands.map { try generateExpression($0, using: builder) }

        // Check if it's a built-in ZIL function that maps to ZAP
        if let zapInstruction = mapZILToZAP(function) {
            if args.isEmpty {
                return builder.emitWithResult(zapInstruction)
            } else {
                return builder.emitWithResult("\(zapInstruction) \(args.joined(separator: ","))")
            }
        }

        // User-defined function call
        if args.isEmpty {
            return builder.emitWithResult("CALL \(function)")
        } else {
            return builder.emitWithResult("CALL \(function),\(args.joined(separator: ","))")
        }
    }

    // MARK: - ZIL Construct Generators

    private mutating func generateCond(_ clauses: [ZILExpression], at location: SourceLocation) throws -> [String] {
        var result: [String] = []

        // Generate compact COND with direct branching like Infocom
        for (index, clause) in clauses.enumerated() {
            guard case .list(let clauseElements, _) = clause else {
                throw CodeGenerationError(.invalidInstruction("COND clause must be list"), at: location)
            }

            guard clauseElements.count >= 2 else {
                throw CodeGenerationError(.invalidInstruction("COND clause must have condition and action"), at: location)
            }

            let condition = clauseElements[0]
            let actions = Array(clauseElements.dropFirst())

            // Generate compact condition test with direct branching
            if index < clauses.count - 1 {
                // Not the last clause - branch to next clause label on false
                let nextLabel = "?ELS\(index + 1)"
                let conditionInstructions = try generateCompactConditionTest(condition, branchFalseTarget: nextLabel, at: location)
                result.append(contentsOf: conditionInstructions)

                // Generate actions for this clause
                for action in actions {
                    let actionInstructions = try generateExpressionAsInstructions(action)
                    result.append(contentsOf: actionInstructions.map { "\($0)" })
                }

                // Add the next clause label
                result.append("\(nextLabel):")
            } else {
                // Last clause - branch away if condition fails (to RTRUE)
                let conditionInstructions = try generateCompactConditionTest(condition, branchFalseTarget: "TRUE", at: location)
                result.append(contentsOf: conditionInstructions)

                // Generate actions for final clause (executed if condition succeeds)
                for action in actions {
                    let actionInstructions = try generateExpressionAsInstructions(action)
                    result.append(contentsOf: actionInstructions.map { "\($0)" })
                }
            }
        }

        return result
    }

    private mutating func generateCompactConditionTest(_ condition: ZILExpression, branchFalseTarget: String, at location: SourceLocation) throws -> [String] {
        switch condition {
        case .list(let elements, _) where !elements.isEmpty:
            guard case .atom(let op, _) = elements[0] else {
                throw CodeGenerationError(.invalidInstruction("condition must start with atom"), at: location)
            }

            let operands = Array(elements.dropFirst())

            switch op.uppercased() {
            case "EQUAL?", "=?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("EQUAL? requires 2 operands"), at: location)
                }
                let arg1 = try generateExpression(operands[0])
                let arg2 = try generateExpression(operands[1])
                return ["EQUAL? \(arg1),\(arg2) /\(branchFalseTarget)"]

            case "GREATER?", ">?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("GREATER? requires 2 operands"), at: location)
                }
                let arg1 = try generateExpression(operands[0])
                let arg2 = try generateExpression(operands[1])
                return ["GRTR? \(arg1),\(arg2) /\(branchFalseTarget)"]

            case "LESS?", "<?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("LESS? requires 2 operands"), at: location)
                }
                let arg1 = try generateExpression(operands[0])
                let arg2 = try generateExpression(operands[1])
                return ["LESS? \(arg1),\(arg2) /\(branchFalseTarget)"]

            case "ZERO?", "0?":
                guard operands.count == 1 else {
                    throw CodeGenerationError(.invalidInstruction("ZERO? requires 1 operand"), at: location)
                }
                let arg = try generateExpression(operands[0])
                return ["ZERO? \(arg) /\(branchFalseTarget)"]

            case "FSET?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("FSET? requires 2 operands"), at: location)
                }
                let obj = try generateExpression(operands[0])
                let flag = try generateExpression(operands[1])
                return ["FSET? \(obj),\(flag) /\(branchFalseTarget)"]

            case "AND":
                // Infocom-style AND in condition: each sub-condition branches to false target on failure
                var result: [String] = []
                for operand in operands {
                    let subConditionInstructions = try generateCompactConditionTest(operand, branchFalseTarget: branchFalseTarget, at: location)
                    result.append(contentsOf: subConditionInstructions)
                }
                return result

            case "OR":
                // Infocom-style OR in condition: create success label, each sub-condition branches to success on true
                // If none succeed, fall through to false target
                // This is more complex - we need a local success target that continues after the OR
                var result: [String] = []
                let successLabel = labelManager.generateLabel(prefix: "OR")

                for operand in operands {
                    // Each operand should branch to success if true (invert the logic)
                    let subConditionInstructions = try generateCompactConditionTestInverted(operand, branchTrueTarget: successLabel, at: location)
                    result.append(contentsOf: subConditionInstructions)
                }

                // If we reach here, all OR conditions failed - branch to false target
                result.append("JUMP \(branchFalseTarget)")
                result.append("\(successLabel):")

                return result

            case "NOT":
                guard operands.count == 1 else {
                    throw CodeGenerationError(.invalidInstruction("NOT requires 1 operand"), at: location)
                }
                // NOT in condition: invert the branch logic - if the inner condition is TRUE, we branch to false target
                return try generateCompactConditionTestInverted(operands[0], branchTrueTarget: branchFalseTarget, at: location)

            default:
                // Generic function call that returns a value to test
                let instructions = try generateExpressionAsInstructions(condition)
                return instructions + ["ZERO? STACK /\(branchFalseTarget)"]
            }

        default:
            // Simple value test (non-zero is true)
            let value = try generateExpression(condition)
            return ["ZERO? \(value) /\(branchFalseTarget)"]
        }
    }

    private mutating func generateCompactConditionTestInverted(_ condition: ZILExpression, branchTrueTarget: String, at location: SourceLocation) throws -> [String] {
        switch condition {
        case .list(let elements, _) where !elements.isEmpty:
            guard case .atom(let op, _) = elements[0] else {
                throw CodeGenerationError(.invalidInstruction("condition must start with atom"), at: location)
            }

            let operands = Array(elements.dropFirst())

            switch op.uppercased() {
            case "EQUAL?", "=?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("EQUAL? requires 2 operands"), at: location)
                }
                let arg1 = try generateExpression(operands[0])
                let arg2 = try generateExpression(operands[1])
                return ["EQUAL? \(arg1),\(arg2) \\\(branchTrueTarget)"]

            case "GREATER?", ">?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("GREATER? requires 2 operands"), at: location)
                }
                let arg1 = try generateExpression(operands[0])
                let arg2 = try generateExpression(operands[1])
                return ["GRTR? \(arg1),\(arg2) \\\(branchTrueTarget)"]

            case "LESS?", "<?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("LESS? requires 2 operands"), at: location)
                }
                let arg1 = try generateExpression(operands[0])
                let arg2 = try generateExpression(operands[1])
                return ["LESS? \(arg1),\(arg2) \\\(branchTrueTarget)"]

            case "ZERO?", "0?":
                guard operands.count == 1 else {
                    throw CodeGenerationError(.invalidInstruction("ZERO? requires 1 operand"), at: location)
                }
                let arg = try generateExpression(operands[0])
                return ["ZERO? \(arg) \\\(branchTrueTarget)"]

            case "FSET?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("FSET? requires 2 operands"), at: location)
                }
                let obj = try generateExpression(operands[0])
                let flag = try generateExpression(operands[1])
                return ["FSET? \(obj),\(flag) \\\(branchTrueTarget)"]

            case "AND":
                // Inverted AND: if any sub-condition is false, we don't branch to true target
                // This is complex - we need to handle it case by case
                var result: [String] = []
                let skipLabel = labelManager.generateLabel(prefix: "SKIP")

                for operand in operands {
                    let subConditionInstructions = try generateCompactConditionTest(operand, branchFalseTarget: skipLabel, at: location)
                    result.append(contentsOf: subConditionInstructions)
                }

                // All conditions passed - branch to true target
                result.append("JUMP \(branchTrueTarget)")
                result.append("\(skipLabel):")

                return result

            case "OR":
                // Inverted OR: each sub-condition branches to true target on success
                var result: [String] = []
                for operand in operands {
                    let subConditionInstructions = try generateCompactConditionTestInverted(operand, branchTrueTarget: branchTrueTarget, at: location)
                    result.append(contentsOf: subConditionInstructions)
                }
                return result

            case "NOT":
                guard operands.count == 1 else {
                    throw CodeGenerationError(.invalidInstruction("NOT requires 1 operand"), at: location)
                }
                // Double negation - back to normal
                return try generateCompactConditionTest(operands[0], branchFalseTarget: branchTrueTarget, at: location)

            default:
                // Generic function call that returns a value to test (inverted)
                let instructions = try generateExpressionAsInstructions(condition)
                return instructions + ["ZERO? STACK \\\(branchTrueTarget)"]
            }

        default:
            // Simple value test (inverted: NOT zero is true for the branch)
            let value = try generateExpression(condition)
            return ["ZERO? \(value) /\(branchTrueTarget)"]
        }
    }

    private mutating func generateConditionTest(_ condition: ZILExpression, at location: SourceLocation) throws -> [String] {
        switch condition {
        case .list(let elements, _) where !elements.isEmpty:
            guard case .atom(let op, _) = elements[0] else {
                throw CodeGenerationError(.invalidInstruction("condition must start with atom"), at: location)
            }

            let operands = Array(elements.dropFirst())

            switch op.uppercased() {
            case "EQUAL?", "=?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("EQUAL? requires 2 operands"), at: location)
                }
                let arg1 = try generateExpression(operands[0])
                let arg2 = try generateExpression(operands[1])
                return ["EQUAL? \(arg1),\(arg2)"]

            case "GREATER?", ">?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("GREATER? requires 2 operands"), at: location)
                }
                let arg1 = try generateExpression(operands[0])
                let arg2 = try generateExpression(operands[1])
                return ["GRTR? \(arg1),\(arg2)"]

            case "LESS?", "<?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("LESS? requires 2 operands"), at: location)
                }
                let arg1 = try generateExpression(operands[0])
                let arg2 = try generateExpression(operands[1])
                return ["LESS? \(arg1),\(arg2)"]

            case "ZERO?":
                guard operands.count == 1 else {
                    throw CodeGenerationError(.invalidInstruction("ZERO? requires 1 operand"), at: location)
                }
                let arg = try generateExpression(operands[0])
                return ["ZERO? \(arg)"]

            case "FSET?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("FSET? requires 2 operands"), at: location)
                }
                let obj = try generateExpression(operands[0])
                let flag = try generateExpression(operands[1])
                return ["FSET? \(obj),\(flag)"]

            case "IN?":
                guard operands.count == 2 else {
                    throw CodeGenerationError(.invalidInstruction("IN? requires 2 operands"), at: location)
                }
                let obj1 = try generateExpression(operands[0])
                let obj2 = try generateExpression(operands[1])
                return ["IN? \(obj1),\(obj2)"]

            case "VERB?":
                let args = try operands.map { try generateExpression($0) }
                return ["VERB? \(args.joined(separator: ","))"]

            case "NOUN?":
                let args = try operands.map { try generateExpression($0) }
                return ["NOUN? \(args.joined(separator: ","))"]

            default:
                // Generic function call that returns a value to test
                let instructions = try generateExpressionAsInstructions(condition)
                return instructions
            }

        default:
            // Simple value test (non-zero is true)
            let value = try generateExpression(condition)
            return ["ZERO? \(value)"] // Will branch if zero (false), continue if non-zero (true)
        }
    }

    private mutating func generateAnd(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        var result: [String] = []
        let falseLabel = labelManager.generateLabel(prefix: "AND")
        let endLabel = labelManager.generateLabel(prefix: "END")

        for operand in operands {
            let conditionInstructions = try generateConditionTest(operand, at: location)
            result.append(contentsOf: conditionInstructions)
            result.append("    " + labelManager.formatBranchFalse(falseLabel))
        }

        // All conditions passed - return true
        result.append("    RTRUE")
        result.append("    JUMP \(endLabel)")

        // Any condition failed - return false
        result.append("\(falseLabel):")
        result.append("    RFALSE")

        result.append("\(endLabel):")
        return result
    }

    private mutating func generateOr(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        var result: [String] = []
        let trueLabel = labelManager.generateLabel(prefix: "OR")
        let endLabel = labelManager.generateLabel(prefix: "END")

        for operand in operands {
            let conditionInstructions = try generateConditionTest(operand, at: location)
            result.append(contentsOf: conditionInstructions)
            result.append("    " + labelManager.formatBranchTrue(trueLabel))
        }

        // All conditions failed - return false
        result.append("    RFALSE")
        result.append("    JUMP \(endLabel)")

        // Any condition passed - return true
        result.append("\(trueLabel):")
        result.append("    RTRUE")

        result.append("\(endLabel):")
        return result
    }

    private mutating func generateNot(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count == 1 else {
            throw CodeGenerationError(.invalidInstruction("NOT requires exactly 1 operand"), at: location)
        }

        var result: [String] = []
        let trueLabel = labelManager.generateLabel(prefix: "NOT")
        let endLabel = labelManager.generateLabel(prefix: "END")

        let conditionInstructions = try generateConditionTest(operands[0], at: location)
        result.append(contentsOf: conditionInstructions)
        result.append("    " + labelManager.formatBranchFalse(trueLabel))

        // Condition was true, so NOT returns false
        result.append("    RFALSE")
        result.append("    JUMP \(endLabel)")

        // Condition was false, so NOT returns true
        result.append("\(trueLabel):")
        result.append("    RTRUE")

        result.append("\(endLabel):")
        return result
    }

    private mutating func generateSet(_ operands: [ZILExpression], isGlobal: Bool, at location: SourceLocation) throws -> [String] {
        guard operands.count == 2 else {
            throw CodeGenerationError(.invalidInstruction("SET requires exactly 2 operands"), at: location)
        }

        let variable = try generateExpression(operands[0])
        let value = try generateExpression(operands[1])

        if isGlobal || variable.hasPrefix("'") {
            // Global variable assignment uses SET with global operand prefix
            // The ' prefix tells the assembler this is a global variable reference
            let globalVar = variable.hasPrefix("'") ? variable : "'\(variable)"
            return ["SET \(globalVar),\(value)"]
        } else {
            return ["SET \(variable),\(value)"]
        }
    }

    private mutating func generateTell(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        var result: [String] = []
        var i = 0

        while i < operands.count {
            let operand = operands[i]

            switch operand {
            case .string(let content, _):
                result.append("PRINTI \"\(escapeString(content))\"")

            case .atom("CR", _):
                result.append("CRLF")

            case .atom("T", _):
                result.append("PRINTI \" \"")

            case .atom("D", _):
                // D should be followed by the object to describe
                // Look ahead to the next operand
                if i + 1 < operands.count {
                    i += 1  // Consume the next operand
                    let nextOperand = operands[i]
                    let objectExpr = try generateExpression(nextOperand)
                    result.append("PRINTD \(objectExpr)")
                } else {
                    // D without object - shouldn't happen but handle gracefully
                    result.append("PRINTD")
                }

            default:
                let expr = try generateExpression(operand)
                // Use PRINT for stack values, PRINTR for others
                if expr == "STACK" {
                    result.append("PRINT \(expr)")
                } else {
                    result.append("PRINTR \(expr)")
                }
            }

            i += 1
        }

        return result
    }

    private mutating func generatePrint(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count == 1 else {
            throw CodeGenerationError(.invalidInstruction("PRINT requires exactly 1 operand"), at: location)
        }

        let expr = try generateExpression(operands[0])
        // Use PRINT for stack values, PRINTR for others
        if expr == "STACK" {
            return ["PRINT \(expr)"]
        } else {
            return ["PRINTR \(expr)"]
        }
    }

    private mutating func generatePrintR(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count == 1 else {
            throw CodeGenerationError(.invalidInstruction("PRINTR requires exactly 1 operand"), at: location)
        }

        let expr = try generateExpression(operands[0])
        return ["PRINTR \(expr)", "RTRUE"]
    }

    private mutating func generatePrintN(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count == 1 else {
            throw CodeGenerationError(.invalidInstruction("PRINTN requires exactly 1 operand"), at: location)
        }

        let expr = try generateExpression(operands[0])
        return ["PRINTN \(expr)"]
    }

    private mutating func generatePrintD(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count == 1 else {
            throw CodeGenerationError(.invalidInstruction("PRINTD requires exactly 1 operand"), at: location)
        }

        let expr = try generateExpression(operands[0])
        return ["PRINTD \(expr)"]
    }

    private mutating func generateMove(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count == 2 else {
            throw CodeGenerationError(.invalidInstruction("MOVE requires exactly 2 operands"), at: location)
        }

        let object = try generateExpression(operands[0])
        let destination = try generateExpression(operands[1])

        return ["MOVE \(object),\(destination)"]
    }

    private mutating func generateRemove(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count == 1 else {
            throw CodeGenerationError(.invalidInstruction("REMOVE requires exactly 1 operand"), at: location)
        }

        let object = try generateExpression(operands[0])
        return ["REMOVE \(object)"]
    }

    private mutating func generateFSet(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count == 2 else {
            throw CodeGenerationError(.invalidInstruction("FSET requires exactly 2 operands"), at: location)
        }

        let object = try generateExpression(operands[0])
        let flag = try generateExpression(operands[1])
        return ["FSET \(object),\(flag)"]
    }

    private mutating func generateFClear(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count == 2 else {
            throw CodeGenerationError(.invalidInstruction("FCLEAR requires exactly 2 operands"), at: location)
        }

        let object = try generateExpression(operands[0])
        let flag = try generateExpression(operands[1])
        return ["FCLEAR \(object),\(flag)"]
    }

    private mutating func generatePut(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count == 3 else {
            throw CodeGenerationError(.invalidInstruction("PUT requires exactly 3 operands"), at: location)
        }

        let table = try generateExpression(operands[0])
        let index = try generateExpression(operands[1])
        let value = try generateExpression(operands[2])
        return ["PUT \(table),\(index),\(value)"]
    }

    private mutating func generatePutP(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count == 3 else {
            throw CodeGenerationError(.invalidInstruction("PUTP requires exactly 3 operands"), at: location)
        }

        let object = try generateExpression(operands[0])
        let property = try generateExpression(operands[1])
        let value = try generateExpression(operands[2])
        return ["PUTP \(object),\(property),\(value)"]
    }

    private mutating func generateRepeat(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        // REPEAT structure: (REPEAT ((variable-initialization-list) action1 action2 ...))
        // For infinite loop: (REPEAT () action1 action2 ...)
        var result: [String] = []
        let loopLabel = labelManager.generateLabel(prefix: "RPT")
        let endLabel = labelManager.generateLabel(prefix: "END")

        context.loopStack.append(endLabel)
        defer { context.loopStack.removeLast() }

        // REPEAT processes all operands as loop body actions
        if operands.isEmpty {
            // No operands at all - this is unusual but handle gracefully
            result.append("\(loopLabel):")
            result.append("    JUMP \(loopLabel)")
            result.append("\(endLabel):")
            return result
        }

        // Process all operands as loop body
        let bodyOperands = operands

        result.append("\(loopLabel):")

        // Generate loop body instructions
        for operand in bodyOperands {
            let instructions = try generateExpressionAsInstructions(operand)
            result.append(contentsOf: instructions.map { "    \($0)" })
        }

        result.append("    JUMP \(loopLabel)")
        result.append("\(endLabel):")

        return result
    }

    private mutating func generateWhile(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count >= 2 else {
            throw CodeGenerationError(.invalidInstruction("WHILE requires condition and body"), at: location)
        }

        var result: [String] = []
        let loopLabel = labelManager.generateLabel(prefix: "WHL")
        let endLabel = labelManager.generateLabel(prefix: "END")

        context.loopStack.append(endLabel)
        defer { context.loopStack.removeLast() }

        let condition = operands[0]
        let body = Array(operands.dropFirst())

        result.append("\(loopLabel):")

        // Test condition
        let conditionInstructions = try generateConditionTest(condition, at: location)
        result.append(contentsOf: conditionInstructions)
        result.append("    " + labelManager.formatBranchFalse(endLabel))

        // Execute body
        for action in body {
            let instructions = try generateExpressionAsInstructions(action)
            result.append(contentsOf: instructions.map { "    \($0)" })
        }

        result.append("    JUMP \(loopLabel)")
        result.append("\(endLabel):")

        return result
    }

    private mutating func generateDo(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        // DO is similar to PROG but creates a new variable scope
        var result: [String] = []

        for operand in operands {
            let instructions = try generateExpressionAsInstructions(operand)
            result.append(contentsOf: instructions)
        }

        return result
    }

    private mutating func generateMapF(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        // MAPF applies a function to each element of a structure
        guard operands.count >= 2 else {
            throw CodeGenerationError(.invalidInstruction("MAPF requires function and structure"), at: location)
        }

        let function = try generateExpression(operands[0])
        let structure = try generateExpression(operands[1])

        return ["MAPF \(function),\(structure)"]
    }

    private mutating func generateMapR(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        // MAPR applies a function to each element and returns results
        guard operands.count >= 2 else {
            throw CodeGenerationError(.invalidInstruction("MAPR requires function and structure"), at: location)
        }

        let function = try generateExpression(operands[0])
        let structure = try generateExpression(operands[1])

        return ["MAPR \(function),\(structure)"]
    }

    private mutating func generateProg(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        // PROG creates a sequential block of statements
        var result: [String] = []

        for operand in operands {
            let instructions = try generateExpressionAsInstructions(operand)
            result.append(contentsOf: instructions)
        }

        return result
    }

    private mutating func generateReturn(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        if operands.isEmpty {
            return ["RTRUE"]
        } else if operands.count == 1 {
            let value = try generateExpression(operands[0])
            return ["RETURN \(value)"]
        } else {
            throw CodeGenerationError(.invalidInstruction("RETURN requires 0 or 1 operand"), at: location)
        }
    }

    private mutating func generateSave(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        if operands.isEmpty {
            return ["save"]
        } else {
            throw CodeGenerationError(.invalidInstruction("SAVE takes no operands"), at: location)
        }
    }

    private mutating func generateRestore(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        if operands.isEmpty {
            return ["restore"]
        } else {
            throw CodeGenerationError(.invalidInstruction("RESTORE takes no operands"), at: location)
        }
    }

    // MARK: - Missing Function Implementations

    private mutating func generateFSetTest(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count == 2 else {
            throw CodeGenerationError(.invalidInstruction("FSET? requires 2 operands"), at: location)
        }

        let object = try generateExpression(operands[0])
        let flag = try generateExpression(operands[1])

        return ["FSET? \(object),\(flag)"]
    }

    private mutating func generateInTest(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count == 2 else {
            throw CodeGenerationError(.invalidInstruction("IN? requires 2 operands"), at: location)
        }

        let object1 = try generateExpression(operands[0])
        let object2 = try generateExpression(operands[1])

        // IN? tests if object1 is contained in object2
        // This is implemented as: LOC object1 -> temp, EQUAL? temp object2
        let tempVar = generateTempVar()
        return [
            "LOC \(object1) >\(tempVar)",
            "EQUAL? \(tempVar),\(object2)"
        ]
    }

    private mutating func generateVerbTest(_ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        guard operands.count == 1 else {
            throw CodeGenerationError(.invalidInstruction("VERB? requires 1 operand"), at: location)
        }

        let verb = try generateExpression(operands[0])

        // VERB? tests if the current parser verb matches the given verb
        // This compares against the PRSA (parser action) global variable
        return ["EQUAL? 'PRSA,\(verb)"]
    }

    private mutating func generateFunctionCall(_ function: String, _ operands: [ZILExpression], at location: SourceLocation) throws -> [String] {
        // Map ZIL function to ZAP instruction
        if let zapInstruction = mapZILToZAP(function) {
            let args = try operands.map { try generateExpression($0) }
            if args.isEmpty {
                return [zapInstruction]
            } else {
                return ["\(zapInstruction) \(args.joined(separator: ","))"]
            }
        }

        // User-defined function call
        let args = try operands.map { try generateExpression($0) }
        if args.isEmpty {
            return ["CALL \(function)"]
        } else {
            return ["CALL \(function),\(args.joined(separator: ","))"]
        }
    }

    // MARK: - Formatting Helpers

    private func formatInstruction(_ instruction: String) -> String {
        let trimmed = instruction.trimmingCharacters(in: .whitespaces)

        // Special handling for standalone labels - don't add tabs
        if trimmed.hasSuffix(":") && !trimmed.contains(" ") {
            return trimmed  // Return label as-is, no leading tab
        }

        // Format regular instruction with Infocom-style tabs: \t<INSTRUCTION>\t<ARGS>
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count >= 2 {
            return "\t\(parts[0])\t\(parts[1])"
        } else {
            return "\t\(trimmed)"
        }
    }

    private func formatLabelWithInstruction(_ label: String, _ instruction: String) -> String {
        // Format label+instruction: <LABEL>:\t<INSTRUCTION>\t<ARGS>
        let parts = instruction.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count >= 2 {
            return "\(label):\t\(parts[0])\t\(parts[1])"
        } else {
            return "\(label):\t\(instruction)"
        }
    }

    private func formatLabel(_ label: String) -> String {
        // Format standalone label: <LABEL>:
        return "\(label):"
    }

    private func applyInfocomFormatting(_ instructions: [String]) -> [String] {
        // Post-process to combine standalone labels with following instructions (Infocom style)
        var result: [String] = []
        var i = 0

        while i < instructions.count {
            let current = instructions[i].trimmingCharacters(in: .whitespaces)

            // Check if current line is a standalone label (ends with :, no tabs)
            if current.hasSuffix(":") && !current.contains("\t") {
                let labelName = current
                // Look for the next non-empty instruction
                var nextInstructionIndex = i + 1
                while nextInstructionIndex < instructions.count &&
                      instructions[nextInstructionIndex].trimmingCharacters(in: .whitespaces).isEmpty {
                    nextInstructionIndex += 1
                }

                if nextInstructionIndex < instructions.count {
                    let nextInstruction = instructions[nextInstructionIndex] // Don't trim! We need to check for leading tab
                    // If next instruction is a regular instruction (starts with tab), combine them
                    if nextInstruction.hasPrefix("\t") {
                        let combinedLine = formatLabelWithInstruction(
                            String(labelName.dropLast()), // Remove the colon
                            String(nextInstruction.dropFirst()) // Remove the leading tab
                        )
                        result.append(combinedLine)
                        i = nextInstructionIndex + 1 // Skip both current and next
                        continue
                    }
                }
            }

            result.append(instructions[i])
            i += 1
        }

        return result
    }

    // MARK: - Utility Functions

    private func escapeString(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    private func convertZValueToZAP(_ value: ZValue) throws -> String {
        switch value {
        case .number(let num):
            return "\(num)"
        case .string(let str):
            return "\"\(escapeString(str))\""
        case .atom(let atom):
            return atom
        case .object(let objId):
            return "OBJ\(objId.id)"
        case .routine(let routineId):
            return "ROUTINE\(routineId.id)"
        case .property(let propId):
            return "P?\(propId.id)"
        case .flag(let flagId):
            return "F?\(flagId.id)"
        case .word(let wordId):
            return "WORD\(wordId.id)"
        case .table(let tableId):
            return "TABLE\(tableId.id)"
        case .direction(let dir):
            return dir.rawValue
        case .null:
            return "0"
        }
    }

    private func mapZILToZAP(_ zilInstruction: String) -> String? {
        // Comprehensive mapping of ZIL instructions to ZAP equivalents
        switch zilInstruction.uppercased() {
        // Comparison operations
        case "EQUAL?", "=?":
            return "EQUAL?"
        case "GREATER?", ">?", "G?", "GRTR?":
            return "GRTR?"
        case "LESS?", "<?", "L?":
            return "LESS?"
        case "ZERO?", "0?":
            return "ZERO?"
        case "1?":
            return "1?"
        case "D=?", "DLESS?":
            return "DLESS?"
        case "IGRTR?":
            return "IGRTR?"
        case "ELESS?":
            return "ELESS?"

        // Object and property operations
        case "VERB?":
            return "VERB?"
        case "NOUN?":
            return "NOUN?"
        case "PROBJ?":
            return "PROBJ?"
        case "FSET?":
            return "FSET?"
        case "FSET":
            return "FSET"
        case "FCLEAR":
            return "FCLEAR"
        case "FIRST?":
            return "FIRST?"
        case "NEXT?":
            return "NEXT?"
        case "IN?":
            return "IN?"
        case "LOC":
            return "LOC"
        case "MOVE":
            return "MOVE"
        case "REMOVE":
            return "REMOVE"
        case "GET":
            return "GET"
        case "PUT":
            return "PUT"
        case "GETP":
            return "GETP"
        case "PUTP":
            return "PUTP"
        case "GETPT":
            return "GETPT"
        case "NEXTP":
            return "NEXTP"
        case "PTSIZE":
            return "PTSIZE"

        // Arithmetic operations
        case "ADD", "+":
            return "ADD"
        case "SUB", "-":
            return "SUB"
        case "MUL", "*":
            return "MUL"
        case "DIV", "/":
            return "DIV"
        case "MOD", "%":
            return "MOD"
        case "BAND":
            return "BAND"
        case "BOR":
            return "BOR"
        case "BXOR":
            return "BXOR"
        case "BNOT":
            return "BNOT"
        case "LSHIFT":
            return "LSHIFT"
        case "RSHIFT":
            return "RSHIFT"

        // I/O operations
        case "PRINTI":
            return "PRINTI"
        case "PRINTR":
            return "PRINTR"
        case "PRINTB":
            return "PRINTB"
        case "PRINTA":
            return "PRINTA"
        case "PRINTD":
            return "PRINTD"
        case "PRINTN":
            return "PRINTN"
        case "CRLF":
            return "CRLF"
        case "READ":
            return "read"
        case "LEX":
            return "lex"

        // Game state operations
        case "SAVE":
            return "save"
        case "RESTORE":
            return "restore"
        case "QUIT":
            return "quit"
        case "RESTART":
            return "restart"
        case "RANDOM":
            return "random"
        case "VERIFY":
            return "verify"

        // Stack operations
        case "PUSH":
            return "push"
        case "POP":
            return "pop"

        // Control flow
        case "JUMP":
            return "JUMP"
        case "CALL":
            return "CALL"
        case "RETURN":
            return "RETURN"
        case "RTRUE":
            return "RTRUE"
        case "RFALSE":
            return "RFALSE"

        // Memory operations
        case "LOADW":
            return "LOADW"
        case "LOADB":
            return "LOADB"
        case "STOREW":
            return "STOREW"
        case "STOREB":
            return "STOREB"

        // Version-specific operations
        case "SOUND":
            return version.rawValue >= 4 ? "sound" : nil
        case "ERASE":
            return version.rawValue >= 4 ? "erase_window" : nil
        case "SPLIT":
            return version.rawValue >= 3 ? "split_window" : nil
        case "SET-CURSOR":
            return version.rawValue >= 4 ? "set_cursor" : nil
        case "GET-CURSOR":
            return version.rawValue >= 4 ? "get_cursor" : nil
        case "SET-COLOUR":
            return version.rawValue >= 5 ? "set_colour" : nil
        case "THROW":
            return version.rawValue >= 5 ? "throw" : nil
        case "CATCH":
            return version.rawValue >= 5 ? "catch" : nil
        case "PIRACY":
            return version.rawValue >= 5 ? "piracy" : nil
        case "MOUSE-WINDOW":
            return version.rawValue >= 5 ? "mouse_window" : nil
        case "PUSH-STACK":
            return version.rawValue >= 6 ? "push_stack" : nil
        case "POP-STACK":
            return version.rawValue >= 6 ? "pop_stack" : nil
        case "DRAW-PICTURE":
            return version.rawValue >= 6 ? "draw_picture" : nil
        case "PICTURE-DATA":
            return version.rawValue >= 6 ? "picture_data" : nil
        case "ERASE-PICTURE":
            return version.rawValue >= 6 ? "erase_picture" : nil
        case "SET-MARGINS":
            return version.rawValue >= 6 ? "set_margins" : nil

        default:
            return nil
        }
    }

    // MARK: - Optimization

    private mutating func optimizeCode() throws {
        // Apply basic optimizations based on optimization level
        switch optimizationLevel {
        case 1:
            try applyBasicOptimizations()
        case 2:
            try applyBasicOptimizations()
            try applyAdvancedOptimizations()
        case 3:
            try applyBasicOptimizations()
            try applyAdvancedOptimizations()
            try applyAggressiveOptimizations()
        default:
            break
        }
    }

    private mutating func applyBasicOptimizations() throws {
        // Remove redundant jumps, combine adjacent operations
        var optimizedOutput: [String] = []
        var i = 0

        while i < output.count {
            let line = output[i].trimmingCharacters(in: .whitespaces)

            // Remove redundant JUMP to next line
            if line.hasPrefix("JUMP") && i + 1 < output.count {
                let nextLine = output[i + 1].trimmingCharacters(in: .whitespaces)
                let jumpTarget = String(line.dropFirst(4).trimmingCharacters(in: .whitespaces))
                if nextLine == "\(jumpTarget):" {
                    i += 1 // Skip the jump
                    continue
                }
            }

            optimizedOutput.append(output[i])
            i += 1
        }

        output = optimizedOutput
    }

    private mutating func applyAdvancedOptimizations() throws {
        // Peephole optimizations, constant folding
        // TODO: Implement advanced optimizations
    }

    private mutating func applyAggressiveOptimizations() throws {
        // Dead code elimination, loop optimizations
        // TODO: Implement aggressive optimizations
    }

    // MARK: - Footer Generation

    private mutating func generateFooter() throws {
        if shouldIncludeStatistics {
            output.append("")
            output.append("; ===== END OF PROGRAM =====")
        }

        output.append(".END")

        if shouldIncludeStatistics {
            output.append("")
            output.append("; Code generation statistics:")
            output.append("; Functions: \(memoryLayout.functions.count)")
            output.append("; Objects: \(memoryLayout.objects.count)")
            output.append("; Globals: \(memoryLayout.globals.count)")
            output.append("; Properties: \(memoryLayout.properties.count)")
            output.append("; Constants: \(memoryLayout.constants.count)")
            output.append("; Strings: \(memoryLayout.strings.count)")
            output.append("; Tables: \(memoryLayout.tables.count)")
            output.append("; Target Version: Z-Machine v\(version.rawValue)")
        }
    }

    // MARK: - Table Literal Generation

    /// Generates proper ZAP code for different ZIL table types
    private mutating func generateTableLiteral(_ tableType: ZILTableType, elements: [ZILExpression], at location: SourceLocation, using builder: InstructionBuilder) throws -> String {
        // Generate element values
        let elementCodes = try elements.map { element in
            try generateExpression(element, using: builder)
        }

        switch tableType {
        case .itable, .ltable, .table:
            // Standard table types - register with memory layout
            return memoryLayout.addTable("", type: tableType, elements: elementCodes)

        case .ptable:
            // PTABLE - Property table (for object properties)
            // Properties are stored as property-id/value pairs
            guard elements.count % 2 == 0 else {
                throw CodeGenerationError(.invalidInstruction("PTABLE requires even number of elements (property-value pairs)"), at: location)
            }
            return memoryLayout.addTable("", type: tableType, elements: elementCodes)

        case .btable:
            // BTABLE - Byte table for character/byte data
            // Each element should be a byte value (0-255)
            for (index, element) in elements.enumerated() {
                if case .number(let value, _) = element {
                    if value < 0 || value > 255 {
                        throw CodeGenerationError(.invalidInstruction("BTABLE element \(index) value \(value) must be 0-255"), at: location)
                    }
                }
            }
            return memoryLayout.addTable("", type: tableType, elements: elementCodes)
        }
    }
}