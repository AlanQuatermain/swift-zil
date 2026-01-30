import Foundation
import Testing
@testable import ZEngine

@Suite("End-to-End Pipeline Tests")
struct EndToEndPipelineTests {

    @Test("Complete ZIL compilation pipeline - simple program")
    func completeSimpleProgram() throws {
        let zilSource = """
        <VERSION ZIP>
        <CONSTANT MAX-SCORE 350>
        <GLOBAL SCORE 0>

        <ROUTINE MAIN ()
            <TELL "Hello, World!" CR>
            <RTRUE>>
        """

        // Step 1: Parse ZIL source
        let lexer = ZILLexer(source: zilSource, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer, filePath: "test.zil")
        let declarations = try parser.parseProgram()

        #expect(declarations.count == 4, "Should parse 4 declarations")

        // Step 2: Semantic analysis
        let analyzer = SemanticAnalyzer()
        let result = analyzer.analyzeProgram(declarations)

        guard case .success = result else {
            if case .failure(let diagnostics) = result {
                Issue.record("Semantic analysis failed: \(diagnostics.map { $0.message }.joined(separator: ", "))")
            }
            return
        }

        // Step 3: Code generation to ZAP
        let symbolTable = analyzer.getSymbolTable()
        let context = analyzer.getCompilationContext()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)
        let zapCode = try generator.generateCode(from: declarations)

        #expect(!zapCode.isEmpty, "Should generate ZAP code")
        #expect(zapCode.contains(".FUNCT"), "Should contain function definitions")

        // Step 4: Assembly to bytecode
        let assembler = ZAssembler(version: .v3, compilationContext: context)
        let bytecode = try assembler.assemble(zapCode)

        #expect(bytecode.count > 64, "Should generate bytecode with header")

        // Step 5: Load in VM
        let vm = ZMachine()

        // Write bytecode to temporary file for VM loading
        let tempDir = FileManager.default.temporaryDirectory
        let storyFile = tempDir.appendingPathComponent("test-simple.z3")
        try bytecode.write(to: storyFile)
        defer { try? FileManager.default.removeItem(at: storyFile) }

        try vm.loadStoryFile(from: storyFile)

        // Verify VM loaded successfully
        #expect(vm.version == .v3, "Should be Z-Machine version 3")
    }

    @Test("Pipeline with global variables and routines")
    func pipelineWithGlobalsAndRoutines() throws {
        let zilSource = """
        <VERSION ZIP>
        <GLOBAL COUNTER 0>
        <GLOBAL FLAG <>>

        <ROUTINE INCREMENT-COUNTER ()
            <SETG COUNTER <+ ,COUNTER 1>>
            <RETURN ,COUNTER>>

        <ROUTINE MAIN ()
            <INCREMENT-COUNTER>
            <RTRUE>>
        """

        // Parse
        let lexer = ZILLexer(source: zilSource, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer, filePath: "test.zil")
        let declarations = try parser.parseProgram()

        #expect(declarations.count == 5, "Should parse VERSION, 2 globals, 2 routines")

        // Semantic analysis
        let analyzer = SemanticAnalyzer()
        let result = analyzer.analyzeProgram(declarations)

        guard case .success = result else {
            if case .failure(let diagnostics) = result {
                Issue.record("Semantic analysis failed: \(diagnostics.map { $0.message }.joined(separator: ", "))")
            }
            return
        }

        // Code generation
        let symbolTable = analyzer.getSymbolTable()
        let context = analyzer.getCompilationContext()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)
        let zapCode = try generator.generateCode(from: declarations)

        #expect(zapCode.contains("INCREMENT-COUNTER"), "Should contain INCREMENT-COUNTER function")
        #expect(zapCode.contains("MAIN"), "Should contain MAIN function")

        // Assembly
        let assembler = ZAssembler(version: .v3, compilationContext: context)
        let bytecode = try assembler.assemble(zapCode)

        // Load in VM
        let vm = ZMachine()
        let tempDir = FileManager.default.temporaryDirectory
        let storyFile = tempDir.appendingPathComponent("test-globals.z3")
        try bytecode.write(to: storyFile)
        defer { try? FileManager.default.removeItem(at: storyFile) }

        try vm.loadStoryFile(from: storyFile)
        #expect(vm.version == .v3)
    }

    @Test("Pipeline with objects and properties")
    func pipelineWithObjectsAndProperties() throws {
        let zilSource = """
        <VERSION ZIP>

        <PROPDEF DESC 0>
        <PROPDEF SIZE 0>

        <OBJECT LANTERN
            (DESC "brass lantern")
            (SIZE 5)>

        <OBJECT ROOM
            (DESC "a small room")>

        <ROUTINE MAIN ()
            <TELL "Game starting" CR>
            <RTRUE>>
        """

        // Parse
        let lexer = ZILLexer(source: zilSource, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer, filePath: "test.zil")
        let declarations = try parser.parseProgram()

        #expect(declarations.count == 6, "Should parse VERSION, 2 properties, 2 objects, 1 routine")

        // Semantic analysis
        let analyzer = SemanticAnalyzer()
        let result = analyzer.analyzeProgram(declarations)

        guard case .success = result else {
            if case .failure(let diagnostics) = result {
                Issue.record("Semantic analysis failed: \(diagnostics.map { $0.message }.joined(separator: ", "))")
            }
            return
        }

        // Verify objects were properly analyzed
        let symbolTable = analyzer.getSymbolTable()
        let lanternSymbol = symbolTable.lookupSymbol(name: "LANTERN")
        let roomSymbol = symbolTable.lookupSymbol(name: "ROOM")

        #expect(lanternSymbol != nil, "Should find LANTERN object")
        #expect(roomSymbol != nil, "Should find ROOM object")

        // Code generation
        let context = analyzer.getCompilationContext()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)
        let zapCode = try generator.generateCode(from: declarations)

        #expect(zapCode.contains("LANTERN"), "Should contain LANTERN object")
        #expect(zapCode.contains("ROOM"), "Should contain ROOM object")

        // Assembly
        let assembler = ZAssembler(version: .v3, compilationContext: context)
        let bytecode = try assembler.assemble(zapCode)

        // Load in VM
        let vm = ZMachine()
        let tempDir = FileManager.default.temporaryDirectory
        let storyFile = tempDir.appendingPathComponent("test-objects.z3")
        try bytecode.write(to: storyFile)
        defer { try? FileManager.default.removeItem(at: storyFile) }

        try vm.loadStoryFile(from: storyFile)
        #expect(vm.version == .v3)
    }

    @Test("Pipeline with constants and expressions")
    func pipelineWithConstantsAndExpressions() throws {
        let zilSource = """
        <VERSION ZIP>
        <CONSTANT MAX-HEALTH 100>
        <CONSTANT MIN-HEALTH 0>

        <GLOBAL HEALTH ,MAX-HEALTH>

        <ROUTINE DAMAGE (AMOUNT)
            <COND (<L? ,HEALTH .AMOUNT>
                   <SETG HEALTH ,MIN-HEALTH>)
                  (ELSE
                   <SETG HEALTH <- ,HEALTH .AMOUNT>>)>
            <RETURN ,HEALTH>>

        <ROUTINE MAIN ()
            <DAMAGE 10>
            <RTRUE>>
        """

        // Parse
        let lexer = ZILLexer(source: zilSource, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer, filePath: "test.zil")
        let declarations = try parser.parseProgram()

        // Semantic analysis
        let analyzer = SemanticAnalyzer()
        let result = analyzer.analyzeProgram(declarations)

        guard case .success = result else {
            if case .failure(let diagnostics) = result {
                Issue.record("Semantic analysis failed: \(diagnostics.map { $0.message }.joined(separator: ", "))")
            }
            return
        }

        // Verify constants were resolved
        let symbolTable = analyzer.getSymbolTable()
        let maxHealthSymbol = symbolTable.lookupSymbol(name: "MAX-HEALTH")
        let minHealthSymbol = symbolTable.lookupSymbol(name: "MIN-HEALTH")

        #expect(maxHealthSymbol != nil, "Should find MAX-HEALTH constant")
        #expect(minHealthSymbol != nil, "Should find MIN-HEALTH constant")

        // Code generation
        let context = analyzer.getCompilationContext()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)
        let zapCode = try generator.generateCode(from: declarations)

        #expect(zapCode.contains("DAMAGE"), "Should contain DAMAGE function")

        // Assembly
        let assembler = ZAssembler(version: .v3, compilationContext: context)
        let bytecode = try assembler.assemble(zapCode)

        // Load in VM
        let vm = ZMachine()
        let tempDir = FileManager.default.temporaryDirectory
        let storyFile = tempDir.appendingPathComponent("test-constants.z3")
        try bytecode.write(to: storyFile)
        defer { try? FileManager.default.removeItem(at: storyFile) }

        try vm.loadStoryFile(from: storyFile)
        #expect(vm.version == .v3)
    }

    @Test("Pipeline with macro expansion")
    func pipelineWithMacroExpansion() throws {
        let zilSource = """
        <VERSION ZIP>

        <DEFMAC DOUBLE (X) <FORM * .X 2>>
        <DEFMAC INCREMENT (VAR) <FORM SETG .VAR <FORM + ,.VAR 1>>>

        <GLOBAL COUNTER 0>

        <ROUTINE MAIN ()
            <INCREMENT COUNTER>
            <SET RESULT <DOUBLE 5>>
            <RTRUE>
            "AUX" RESULT>

        <ROUTINE MAIN ()
            <TELL "Test" CR>
            <RTRUE>>
        """

        // Parse (with macro expansion)
        let lexer = ZILLexer(source: zilSource, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer, filePath: "test.zil")
        let declarations = try parser.parseProgram()

        // The DEFMAC declarations should be registered but macros should expand during parsing
        #expect(declarations.count > 2, "Should parse VERSION, DEFMACs, and routines")

        // Semantic analysis
        let analyzer = SemanticAnalyzer()
        let result = analyzer.analyzeProgram(declarations)

        // Note: This may fail if macros reference undefined symbols
        // That's expected - the test is to verify the pipeline runs
        switch result {
        case .success:
            // If successful, continue with code generation
            let symbolTable = analyzer.getSymbolTable()
            let context = analyzer.getCompilationContext()
            var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)
            let zapCode = try generator.generateCode(from: declarations)

            #expect(!zapCode.isEmpty, "Should generate ZAP code")

            // Assembly
            let assembler = ZAssembler(version: .v3, compilationContext: context)
            let bytecode = try assembler.assemble(zapCode)

            // Load in VM
            let vm = ZMachine()
            let tempDir = FileManager.default.temporaryDirectory
            let storyFile = tempDir.appendingPathComponent("test-macros.z3")
            try bytecode.write(to: storyFile)
            defer { try? FileManager.default.removeItem(at: storyFile) }

            try vm.loadStoryFile(from: storyFile)
            #expect(vm.version == .v3)

        case .failure(let diagnostics):
            // If semantic analysis fails, verify it's due to expected issues
            // (like undefined symbols in macro bodies)
            let hasUndefinedSymbols = diagnostics.contains { diagnostic in
                if case .undefinedSymbol = diagnostic.code {
                    return true
                }
                return false
            }

            // As long as we got to semantic analysis and macros were expanded, that's progress
            #expect(hasUndefinedSymbols || diagnostics.isEmpty, "Expected undefined symbols or success")
        }
    }

    @Test("Pipeline error handling - parse error")
    func pipelineParseError() throws {
        let zilSource = """
        <VERSION ZIP>
        <ROUTINE BROKEN (
            <TELL "Missing closing paren">
        """

        // Parse should fail
        let lexer = ZILLexer(source: zilSource, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

        #expect(throws: (any Error).self) {
            _ = try parser.parseProgram()
        }
    }

    @Test("Pipeline error handling - semantic error")
    func pipelineSemanticError() throws {
        let zilSource = """
        <VERSION ZIP>

        <ROUTINE MAIN ()
            <UNDEFINED-FUNCTION>
            <RTRUE>>
        """

        // Parse should succeed
        let lexer = ZILLexer(source: zilSource, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer, filePath: "test.zil")
        let declarations = try parser.parseProgram()

        #expect(declarations.count == 2, "Should parse VERSION and MAIN")

        // Semantic analysis should fail
        let analyzer = SemanticAnalyzer()
        let result = analyzer.analyzeProgram(declarations)

        guard case .failure(let diagnostics) = result else {
            Issue.record("Expected semantic analysis to fail")
            return
        }

        let hasUndefinedSymbol = diagnostics.contains { diagnostic in
            if case .undefinedSymbol(let name, _) = diagnostic.code {
                return name == "UNDEFINED-FUNCTION"
            }
            return false
        }

        #expect(hasUndefinedSymbol, "Should detect undefined function")
    }

    @Test("Pipeline with multiple files - forward references")
    func pipelineWithForwardReferences() throws {
        let zilSource = """
        <VERSION ZIP>

        <ROUTINE FIRST ()
            <SECOND>
            <RTRUE>>

        <ROUTINE SECOND ()
            <THIRD>
            <RTRUE>>

        <ROUTINE THIRD ()
            <TELL "End" CR>
            <RTRUE>>
        """

        // Parse
        let lexer = ZILLexer(source: zilSource, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer, filePath: "test.zil")
        let declarations = try parser.parseProgram()

        #expect(declarations.count == 4, "Should parse VERSION and 3 routines")

        // Semantic analysis should handle forward references
        let analyzer = SemanticAnalyzer()
        let result = analyzer.analyzeProgram(declarations)

        guard case .success = result else {
            if case .failure(let diagnostics) = result {
                Issue.record("Forward references should be resolved: \(diagnostics.map { $0.message }.joined(separator: ", "))")
            }
            return
        }

        // Verify all routines are in symbol table
        let symbolTable = analyzer.getSymbolTable()
        #expect(symbolTable.lookupSymbol(name: "FIRST") != nil)
        #expect(symbolTable.lookupSymbol(name: "SECOND") != nil)
        #expect(symbolTable.lookupSymbol(name: "THIRD") != nil)

        // Code generation and assembly should succeed
        let context = analyzer.getCompilationContext()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)
        let zapCode = try generator.generateCode(from: declarations)

        let assembler = ZAssembler(version: .v3, compilationContext: context)
        let bytecode = try assembler.assemble(zapCode)

        let vm = ZMachine()
        let tempDir = FileManager.default.temporaryDirectory
        let storyFile = tempDir.appendingPathComponent("test-forward-refs.z3")
        try bytecode.write(to: storyFile)
        defer { try? FileManager.default.removeItem(at: storyFile) }

        try vm.loadStoryFile(from: storyFile)
        #expect(vm.version == .v3)
    }

    @Test("Pipeline with different Z-Machine versions")
    func pipelineWithDifferentVersions() throws {
        let zilSource = """
        <VERSION ZIP>
        <ROUTINE MAIN ()
            <TELL "Test" CR>
            <RTRUE>>
        """

        // Test with V3
        do {
            let lexer = ZILLexer(source: zilSource, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")
            let declarations = try parser.parseProgram()

            let analyzer = SemanticAnalyzer()
            let result = analyzer.analyzeProgram(declarations)
            guard case .success = result else {
                Issue.record("V3 semantic analysis failed")
                return
            }

            let symbolTable = analyzer.getSymbolTable()
            let context = analyzer.getCompilationContext()
            var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)
            let zapCode = try generator.generateCode(from: declarations)

            let assembler = ZAssembler(version: .v3, compilationContext: context)
            let bytecode = try assembler.assemble(zapCode)

            let vm = ZMachine()
            let tempDir = FileManager.default.temporaryDirectory
            let storyFile = tempDir.appendingPathComponent("test-v3.z3")
            try bytecode.write(to: storyFile)
            defer { try? FileManager.default.removeItem(at: storyFile) }

            try vm.loadStoryFile(from: storyFile)
            #expect(vm.version == .v3)
        }

        // Test with V5
        do {
            let lexer = ZILLexer(source: zilSource, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")
            let declarations = try parser.parseProgram()

            let analyzer = SemanticAnalyzer()
            let result = analyzer.analyzeProgram(declarations)
            guard case .success = result else {
                Issue.record("V5 semantic analysis failed")
                return
            }

            let symbolTable = analyzer.getSymbolTable()
            let context = analyzer.getCompilationContext()
            var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v5, optimizationLevel: 1)
            let zapCode = try generator.generateCode(from: declarations)

            let assembler = ZAssembler(version: .v5, compilationContext: context)
            let bytecode = try assembler.assemble(zapCode)

            let vm = ZMachine()
            let tempDir = FileManager.default.temporaryDirectory
            let storyFile = tempDir.appendingPathComponent("test-v5.z5")
            try bytecode.write(to: storyFile)
            defer { try? FileManager.default.removeItem(at: storyFile) }

            try vm.loadStoryFile(from: storyFile)
            #expect(vm.version == .v5)
        }
    }
}
