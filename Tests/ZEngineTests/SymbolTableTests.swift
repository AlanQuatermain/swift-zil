import Testing
@testable import ZEngine

@Suite("Symbol Table Tests")
struct SymbolTableTests {

    @Test("Basic symbol definition and lookup")
    func basicSymbolDefinitionAndLookup() throws {
        let symbolTable = SymbolTableManager()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define a global variable
        let success = symbolTable.defineSymbol(
            name: "SCORE",
            type: .globalVariable,
            at: location
        )
        #expect(success == true, "Should successfully define symbol")

        // Look up the symbol
        let symbol = symbolTable.lookupSymbol(name: "SCORE")
        #expect(symbol != nil, "Should find defined symbol")
        #expect(symbol?.name == "SCORE", "Symbol name should match")
        #expect(symbol?.scopeLevel == 0, "Global symbol should be at scope 0")

        // Try to look up non-existent symbol
        let missing = symbolTable.lookupSymbol(name: "MISSING")
        #expect(missing == nil, "Should not find undefined symbol")
    }

    @Test("Symbol redefinition detection")
    func symbolRedefinitionDetection() throws {
        let symbolTable = SymbolTableManager()
        let location1 = SourceLocation(file: "test.zil", line: 1, column: 1)
        let location2 = SourceLocation(file: "test.zil", line: 5, column: 1)

        // Define symbol first time
        let firstDefine = symbolTable.defineSymbol(
            name: "WINNER",
            type: .globalVariable,
            at: location1
        )
        #expect(firstDefine == true, "First definition should succeed")

        // Try to redefine in same scope
        let secondDefine = symbolTable.defineSymbol(
            name: "WINNER",
            type: .constant(value: .number(42, location2)),
            at: location2
        )
        #expect(secondDefine == false, "Redefinition should fail")

        // Check diagnostics
        let diagnostics = symbolTable.getDiagnostics()
        #expect(diagnostics.count == 1, "Should have one diagnostic")

        if let diagnostic = diagnostics.first {
            #expect(diagnostic.symbolName == "WINNER", "Diagnostic should reference correct symbol")
            if case .symbolRedefinition(let original, let redefinition) = diagnostic.code {
                #expect(original == location1, "Should track original definition location")
                #expect(redefinition == location2, "Should track redefinition location")
            } else {
                #expect(Bool(false), "Should be redefinition diagnostic")
            }
        }
    }

    @Test("Scope management")
    func scopeManagement() throws {
        let symbolTable = SymbolTableManager()
        let globalLoc = SourceLocation(file: "test.zil", line: 1, column: 1)
        let localLoc = SourceLocation(file: "test.zil", line: 5, column: 1)

        // Define global symbol
        symbolTable.defineSymbol(name: "GLOBAL-VAR", type: .globalVariable, at: globalLoc)

        // Push scope (enter routine)
        #expect(symbolTable.getCurrentScope() == 0, "Should start at global scope")
        symbolTable.pushScope()
        #expect(symbolTable.getCurrentScope() == 1, "Should be at scope 1")

        // Define local symbol
        symbolTable.defineSymbol(name: "LOCAL-VAR", type: .localVariable, at: localLoc)

        // Should be able to see both global and local
        let globalSymbol = symbolTable.lookupSymbol(name: "GLOBAL-VAR")
        let localSymbol = symbolTable.lookupSymbol(name: "LOCAL-VAR")
        #expect(globalSymbol != nil, "Should find global symbol from local scope")
        #expect(localSymbol != nil, "Should find local symbol")
        #expect(localSymbol?.scopeLevel == 1, "Local symbol should be at scope 1")

        // Pop scope (exit routine)
        symbolTable.popScope()
        #expect(symbolTable.getCurrentScope() == 0, "Should return to global scope")

        // Should no longer see local symbol
        let globalStill = symbolTable.lookupSymbol(name: "GLOBAL-VAR")
        let localGone = symbolTable.lookupSymbol(name: "LOCAL-VAR")
        #expect(globalStill != nil, "Should still find global symbol")
        #expect(localGone == nil, "Should no longer find local symbol")
    }

    @Test("Symbol shadowing")
    func symbolShadowing() throws {
        let symbolTable = SymbolTableManager()
        let globalLoc = SourceLocation(file: "test.zil", line: 1, column: 1)
        let localLoc = SourceLocation(file: "test.zil", line: 5, column: 1)

        // Define global symbol
        symbolTable.defineSymbol(name: "VAR", type: .globalVariable, at: globalLoc)

        // Push scope
        symbolTable.pushScope()

        // Define local symbol with same name (shadowing)
        let shadowSuccess = symbolTable.defineSymbol(name: "VAR", type: .localVariable, at: localLoc)
        #expect(shadowSuccess == true, "Should allow shadowing in different scope")

        // Lookup should find local version
        let foundSymbol = symbolTable.lookupSymbol(name: "VAR")
        #expect(foundSymbol?.scopeLevel == 1, "Should find local (shadowing) symbol")
        #expect(foundSymbol?.type == .localVariable, "Should be local variable type")

        // Pop scope
        symbolTable.popScope()

        // Now should find global version again
        let globalAgain = symbolTable.lookupSymbol(name: "VAR")
        #expect(globalAgain?.scopeLevel == 0, "Should find global symbol again")
        #expect(globalAgain?.type == .globalVariable, "Should be global variable type")
    }

    @Test("Symbol references and undefined symbols")
    func symbolReferencesAndUndefinedSymbols() throws {
        let symbolTable = SymbolTableManager()
        let defLoc = SourceLocation(file: "test.zil", line: 1, column: 1)
        let refLoc1 = SourceLocation(file: "test.zil", line: 5, column: 10)
        let refLoc2 = SourceLocation(file: "test.zil", line: 8, column: 15)
        let undefLoc = SourceLocation(file: "test.zil", line: 10, column: 5)

        // Define a symbol
        symbolTable.defineSymbol(name: "DEFINED", type: .globalVariable, at: defLoc)

        // Reference the defined symbol
        let ref1 = symbolTable.referenceSymbol(name: "DEFINED", at: refLoc1)
        let ref2 = symbolTable.referenceSymbol(name: "DEFINED", at: refLoc2)
        #expect(ref1 != nil, "Should find defined symbol")
        #expect(ref2 != nil, "Should find defined symbol again")

        // Reference undefined symbol
        let undef = symbolTable.referenceSymbol(name: "UNDEFINED", at: undefLoc)
        #expect(undef == nil, "Should not find undefined symbol")

        // Check that references were recorded
        let definedSymbol = symbolTable.lookupSymbol(name: "DEFINED")
        #expect(definedSymbol?.references.count == 2, "Should have two references")
        #expect(definedSymbol?.references.contains(refLoc1) == true, "Should contain first reference")
        #expect(definedSymbol?.references.contains(refLoc2) == true, "Should contain second reference")

        // Check undefined references
        let undefinedRefs = symbolTable.getUndefinedReferences()
        #expect(undefinedRefs["UNDEFINED"]?.count == 1, "Should have one undefined reference")
        #expect(undefinedRefs["UNDEFINED"]?.first == undefLoc, "Should track undefined reference location")
    }

    @Test("Forward reference resolution")
    func forwardReferenceResolution() throws {
        let symbolTable = SymbolTableManager()
        let refLoc = SourceLocation(file: "test.zil", line: 1, column: 10)
        let defLoc = SourceLocation(file: "test.zil", line: 5, column: 1)

        // Reference symbol before it's defined
        let beforeDef = symbolTable.referenceSymbol(name: "FORWARD", at: refLoc)
        #expect(beforeDef == nil, "Should not find undefined symbol")

        // Check it's recorded as undefined
        let undefinedBefore = symbolTable.getUndefinedReferences()
        #expect(undefinedBefore["FORWARD"]?.count == 1, "Should have undefined reference")

        // Now define the symbol
        let defineSuccess = symbolTable.defineSymbol(name: "FORWARD", type: .routine(
            parameters: [],
            optionalParameters: [],
            auxiliaryVariables: []
        ), at: defLoc)
        #expect(defineSuccess == true, "Should successfully define symbol")

        // Check that forward reference was resolved
        let definedSymbol = symbolTable.lookupSymbol(name: "FORWARD")
        #expect(definedSymbol?.references.count == 1, "Should have the forward reference")
        #expect(definedSymbol?.references.first == refLoc, "Should have correct reference location")

        // Check undefined references list is cleared for this symbol
        let undefinedAfter = symbolTable.getUndefinedReferences()
        #expect(undefinedAfter["FORWARD"] == nil, "Should no longer be undefined")
    }

    @Test("Validation diagnostics")
    func validationDiagnostics() throws {
        let symbolTable = SymbolTableManager()
        let defLoc = SourceLocation(file: "test.zil", line: 1, column: 1)
        let undefLoc = SourceLocation(file: "test.zil", line: 5, column: 10)

        // Create an unused symbol (in local scope), then pop scope
        symbolTable.pushScope()
        _ = symbolTable.defineSymbol(name: "UNUSED", type: .localVariable, at: defLoc)
        symbolTable.popScope()  // This should preserve the unused symbol for validation

        // Create an undefined reference
        _ = symbolTable.referenceSymbol(name: "UNDEFINED", at: undefLoc)

        // Run validation
        symbolTable.validate()

        let diagnostics = symbolTable.getDiagnostics()
        #expect(diagnostics.count == 2, "Should have two diagnostics")

        let unusedDiag = diagnostics.first { diagnostic in
            if case .unusedSymbol = diagnostic.code {
                return diagnostic.symbolName == "UNUSED"
            }
            return false
        }
        #expect(unusedDiag != nil, "Should have unused symbol diagnostic")

        let undefinedDiag = diagnostics.first { diagnostic in
            if case .undefinedSymbol = diagnostic.code {
                return diagnostic.symbolName == "UNDEFINED"
            }
            return false
        }
        #expect(undefinedDiag != nil, "Should have undefined symbol diagnostic")
    }

    @Test("Complex routine symbol")
    func complexRoutineSymbol() throws {
        let symbolTable = SymbolTableManager()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define complex routine with parameters
        let success = symbolTable.defineSymbol(
            name: "COMPLEX-ROUTINE",
            type: .routine(
                parameters: ["ARG1", "ARG2"],
                optionalParameters: ["OPT1", "OPT2"],
                auxiliaryVariables: ["AUX1", "AUX2", "AUX3"]
            ),
            at: location
        )
        #expect(success == true, "Should define complex routine")

        let symbol = symbolTable.lookupSymbol(name: "COMPLEX-ROUTINE")
        #expect(symbol != nil, "Should find routine symbol")

        if let symbol = symbol, case .routine(let params, let opts, let auxs) = symbol.type {
            #expect(params == ["ARG1", "ARG2"], "Should have correct parameters")
            #expect(opts == ["OPT1", "OPT2"], "Should have correct optional parameters")
            #expect(auxs == ["AUX1", "AUX2", "AUX3"], "Should have correct auxiliary variables")
        } else {
            #expect(Bool(false), "Should be routine type with correct structure")
        }
    }

    @Test("Scope isolation")
    func scopeIsolation() throws {
        let symbolTable = SymbolTableManager()

        // Get symbols in global scope initially
        let globalInitial = symbolTable.getSymbolsInScope(0)
        #expect(globalInitial.isEmpty, "Global scope should start empty")

        // Define global symbol
        symbolTable.defineSymbol(name: "GLOBAL", type: .globalVariable, at: .unknown)

        // Push scope and define local
        symbolTable.pushScope()
        symbolTable.defineSymbol(name: "LOCAL", type: .localVariable, at: .unknown)

        // Check scope isolation
        let globalSymbols = symbolTable.getSymbolsInScope(0)
        let localSymbols = symbolTable.getSymbolsInScope(1)

        #expect(globalSymbols.count == 1, "Global scope should have one symbol")
        #expect(globalSymbols.first?.name == "GLOBAL", "Global scope should contain GLOBAL")

        #expect(localSymbols.count == 1, "Local scope should have one symbol")
        #expect(localSymbols.first?.name == "LOCAL", "Local scope should contain LOCAL")

        // All symbols across scopes
        let allSymbols = symbolTable.getAllSymbols()
        #expect(allSymbols.count == 2, "Should have two symbols total")

        symbolTable.popScope()
    }

    @Test("Cannot pop global scope")
    func cannotPopGlobalScope() throws {
        let symbolTable = SymbolTableManager()

        #expect(symbolTable.getCurrentScope() == 0, "Should start at global scope")

        // Try to pop global scope
        symbolTable.popScope()

        #expect(symbolTable.getCurrentScope() == 0, "Should still be at global scope")

        // Should have diagnostic
        let diagnostics = symbolTable.getDiagnostics()
        #expect(diagnostics.count == 1, "Should have one diagnostic")

        if let diagnostic = diagnostics.first {
            if case .cannotPopGlobalScope = diagnostic.code {
                // Expected
            } else {
                #expect(Bool(false), "Should be cannot pop global scope diagnostic")
            }
        }
    }

    @Test("Popped scopes don't affect current lookups")
    func poppedScopesDontAffectCurrentLookups() throws {
        let symbolTable = SymbolTableManager()
        let globalLoc = SourceLocation(file: "test.zil", line: 1, column: 1)
        let localLoc = SourceLocation(file: "test.zil", line: 5, column: 1)

        // Define global X
        _ = symbolTable.defineSymbol(name: "X", type: .globalVariable, at: globalLoc)

        // Push scope, define local X, then pop
        symbolTable.pushScope()
        _ = symbolTable.defineSymbol(name: "X", type: .localVariable, at: localLoc)
        symbolTable.popScope()

        // Lookup should find global X again, not the popped local X
        let foundSymbol = symbolTable.lookupSymbol(name: "X")
        #expect(foundSymbol != nil, "Should find symbol X")
        #expect(foundSymbol?.scopeLevel == 0, "Should find global X (scope 0)")
        #expect(foundSymbol?.type == .globalVariable, "Should be global variable type")

        // getAllSymbols should only contain current scopes, not popped ones
        let allSymbols = symbolTable.getAllSymbols()
        let xSymbols = allSymbols.filter { $0.name == "X" }
        #expect(xSymbols.count == 1, "Should only have one X symbol in current scopes")
        #expect(xSymbols.first?.scopeLevel == 0, "Should be the global X")
    }
}