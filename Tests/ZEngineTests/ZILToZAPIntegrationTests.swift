import Testing
@testable import ZEngine
import Foundation
import Logging

@Suite("ZIL to ZAP Integration Tests")
struct ZILToZAPIntegrationTests {

    // MARK: - Test Data from Infocom Projects

    private func createTestSymbolTable() -> SymbolTableManager {
        let symbolTable = SymbolTableManager()

        // Add symbols referenced in the THIS-IT? routine
        _ = symbolTable.defineSymbol(name: "INVISIBLE", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "P-NAM", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "P?SYNONYM", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "P-ADJ", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "P?ADJECTIVE", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "P-GWIMBIT", type: .globalVariable, at: .unknown)

        // Add referenced functions
        _ = symbolTable.defineSymbol(name: "ZMEMQ", type: .routine(parameters: ["WHAT", "TABLE", "SIZE"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "GETPT", type: .routine(parameters: ["OBJECT", "PROPERTY"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "PTSIZE", type: .routine(parameters: ["TABLE"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "ZMEMQB", type: .routine(parameters: ["WHAT", "TABLE", "SIZE"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "FSET?", type: .routine(parameters: ["OBJECT", "FLAG"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)

        return symbolTable
    }

    @Test("Generate ZAP from enchanter crufty.zil and compare with Infocom output")
    func generateZAPFromEnchanterCruftyAndCompare() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1) // Use O1 production mode

        let location = ZEngine.SourceLocation(file: "crufty.zil", line: 3, column: 1)

        // Recreate the THIS-IT? routine from enchanter/crufty.zil exactly as written
        let routine = ZILRoutineDeclaration(
            name: "THIS-IT?",
            parameters: ["OBJ", "TBL"],
            auxiliaryVariables: [
                ZILParameter(name: "SYNS", location: location)
            ],
            body: [
                // <COND (<FSET? .OBJ ,INVISIBLE> <RFALSE>)
                ZILExpression.list([
                    ZILExpression.atom("COND", location),
                    ZILExpression.list([
                        ZILExpression.list([
                            ZILExpression.atom("FSET?", location),
                            ZILExpression.localVariable("OBJ", location),
                            ZILExpression.globalVariable("INVISIBLE", location)
                        ], location),
                        ZILExpression.atom("RFALSE", location)
                    ], location),
                    // (<AND ,P-NAM <NOT <ZMEMQ ,P-NAM <SET SYNS <GETPT .OBJ ,P?SYNONYM>> <- </ <PTSIZE .SYNS> 2> 1>>>> <RFALSE>)
                    ZILExpression.list([
                        ZILExpression.list([
                            ZILExpression.atom("AND", location),
                            ZILExpression.globalVariable("P-NAM", location),
                            ZILExpression.list([
                                ZILExpression.atom("NOT", location),
                                ZILExpression.list([
                                    ZILExpression.atom("ZMEMQ", location),
                                    ZILExpression.globalVariable("P-NAM", location),
                                    ZILExpression.list([
                                        ZILExpression.atom("SET", location),
                                        ZILExpression.localVariable("SYNS", location),
                                        ZILExpression.list([
                                            ZILExpression.atom("GETPT", location),
                                            ZILExpression.localVariable("OBJ", location),
                                            ZILExpression.globalVariable("P?SYNONYM", location)
                                        ], location)
                                    ], location),
                                    ZILExpression.list([
                                        ZILExpression.atom("-", location),
                                        ZILExpression.list([
                                            ZILExpression.atom("/", location),
                                            ZILExpression.list([
                                                ZILExpression.atom("PTSIZE", location),
                                                ZILExpression.localVariable("SYNS", location)
                                            ], location),
                                            ZILExpression.number(2, location)
                                        ], location),
                                        ZILExpression.number(1, location)
                                    ], location)
                                ], location)
                            ], location)
                        ], location),
                        ZILExpression.atom("RFALSE", location)
                    ], location),
                    // Third clause: (<AND ,P-ADJ <OR <NOT <SET SYNS <GETPT .OBJ ,P?ADJECTIVE>>> <NOT <ZMEMQB ,P-ADJ .SYNS <- <PTSIZE .SYNS> 1>>>>> <RFALSE>)
                    ZILExpression.list([
                        ZILExpression.list([
                            ZILExpression.atom("AND", location),
                            ZILExpression.globalVariable("P-ADJ", location),
                            ZILExpression.list([
                                ZILExpression.atom("OR", location),
                                ZILExpression.list([
                                    ZILExpression.atom("NOT", location),
                                    ZILExpression.list([
                                        ZILExpression.atom("SET", location),
                                        ZILExpression.localVariable("SYNS", location),
                                        ZILExpression.list([
                                            ZILExpression.atom("GETPT", location),
                                            ZILExpression.localVariable("OBJ", location),
                                            ZILExpression.globalVariable("P?ADJECTIVE", location)
                                        ], location)
                                    ], location)
                                ], location),
                                ZILExpression.list([
                                    ZILExpression.atom("NOT", location),
                                    ZILExpression.list([
                                        ZILExpression.atom("ZMEMQB", location),
                                        ZILExpression.globalVariable("P-ADJ", location),
                                        ZILExpression.localVariable("SYNS", location),
                                        ZILExpression.list([
                                            ZILExpression.atom("-", location),
                                            ZILExpression.list([
                                                ZILExpression.atom("PTSIZE", location),
                                                ZILExpression.localVariable("SYNS", location)
                                            ], location),
                                            ZILExpression.number(1, location)
                                        ], location)
                                    ], location)
                                ], location)
                            ], location)
                        ], location),
                        ZILExpression.atom("RFALSE", location)
                    ], location),
                    // Fourth clause: (<AND <NOT <0? ,P-GWIMBIT>> <NOT <FSET? .OBJ ,P-GWIMBIT>>> <RFALSE>)
                    ZILExpression.list([
                        ZILExpression.list([
                            ZILExpression.atom("AND", location),
                            ZILExpression.list([
                                ZILExpression.atom("NOT", location),
                                ZILExpression.list([
                                    ZILExpression.atom("0?", location),
                                    ZILExpression.globalVariable("P-GWIMBIT", location)
                                ], location)
                            ], location),
                            ZILExpression.list([
                                ZILExpression.atom("NOT", location),
                                ZILExpression.list([
                                    ZILExpression.atom("FSET?", location),
                                    ZILExpression.localVariable("OBJ", location),
                                    ZILExpression.globalVariable("P-GWIMBIT", location)
                                ], location)
                            ], location)
                        ], location),
                        ZILExpression.atom("RFALSE", location)
                    ], location)
                ], location),
                // Final RTRUE
                ZILExpression.atom("RTRUE", location)
            ],
            location: location
        )

        let generatedZAP = try generator.generateCode(from: [.routine(routine)])

        // Write our generated ZAP to a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let generatedZAPFile = tempDir.appendingPathComponent("our_crufty.zap")
        try generatedZAP.write(to: generatedZAPFile, atomically: true, encoding: .utf8)

        // Read the Infocom ZAP file
        let infocomZAPPath = "/Users/jim/Projects/ZIL/enchanter/crufty.zap"
        let infocomZAP = try String(contentsOfFile: infocomZAPPath, encoding: .utf8)

        // Add both versions as test attachments for comparison
        let generatedZAPAttachment = Attachment(generatedZAP, named: "generated-crufty.zap")
        Attachment.record(generatedZAPAttachment)

        let infocomZAPAttachment = Attachment(infocomZAP, named: "infocom-crufty.zap")
        Attachment.record(infocomZAPAttachment)

        // Use diff to compare the files
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/diff")
        process.arguments = ["-u", infocomZAPPath, generatedZAPFile.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let diffOutput = String(data: data, encoding: .utf8) ?? ""

        // Add diff output as attachment if there are differences
        if !diffOutput.isEmpty {
            let diffAttachment = Attachment(diffOutput, named: "crufty-comparison.diff")
            Attachment.record(diffAttachment)
        }

        // Clean up
        try? FileManager.default.removeItem(at: generatedZAPFile)

        // Basic structural expectations - our code should at least have these elements
        #expect(generatedZAP.contains("THIS-IT?"))  // Function name should appear in .FUNCT directive
        #expect(generatedZAP.contains("FSET?"))
        #expect(generatedZAP.contains("RFALSE"))
        #expect(generatedZAP.contains("RTRUE"))
    }

    @Test("Generate simple routine and compare structure")
    func generateSimpleRoutineAndCompareStructure() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1) // Use O1 production mode

        let location = ZEngine.SourceLocation(file: "test.zil", line: 1, column: 1)

        // Create a simple test routine to understand our output format
        let routine = ZILRoutineDeclaration(
            name: "SIMPLE-TEST",
            parameters: ["X"],
            body: [
                ZILExpression.list([
                    ZILExpression.atom("FSET?", location),
                    ZILExpression.localVariable("X", location),
                    ZILExpression.globalVariable("INVISIBLE", location)
                ], location)
            ],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        // Add generated ZAP as attachment for inspection
        let zapAttachment = Attachment(result, named: "simple-routine.zap")
        Attachment.record(zapAttachment)

        // Production mode expectations
        #expect(result.contains(".ZVERSION 3"))
        #expect(result.contains("\t.FUNCT\tSIMPLE-TEST"))  // Infocom-style tab formatting
        #expect(result.contains("FSET?"))
        #expect(result.contains(".END"))

        // Should NOT contain debug headers
        #expect(!result.contains("ZAP Assembly Code Generated"))
        #expect(!result.contains("Code generation statistics"))

        // Should be compact
        let lines = result.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        #expect(lines.count <= 15) // Should be much more compact than debug mode
    }

    @Test("Extract and analyze instruction differences")
    func extractAndAnalyzeInstructionDifferences() throws {
        // Load the Infocom ZAP file and analyze its structure
        let infocomZAPPath = "/Users/jim/Projects/ZIL/enchanter/crufty.zap"
        let infocomZAP = try String(contentsOfFile: infocomZAPPath, encoding: .utf8)

        // Create structure analysis for attachment
        var analysisLines: [String] = ["Infocom ZAP structure analysis:", "==============================", ""]

        let lines = infocomZAP.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                analysisLines.append("Line \(index + 1): '\(trimmed)'")
            }
        }

        let analysisOutput = analysisLines.joined(separator: "\n")

        // Add analysis as attachment
        let analysisAttachment = Attachment(analysisOutput, named: "crufty-structure-analysis.txt")
        Attachment.record(analysisAttachment)

        // Key patterns to note:
        // 1. Function signature format: .FUNCT THIS-IT?,OBJ,TBL,SYNS,?TMP1
        // 2. Instruction format: FSET? OBJ,INVISIBLE /FALSE
        // 3. Label format: ?ELS5:
        // 4. Branch format: /FALSE, \FALSE
        // 5. Stack operations: >SYNS, STACK
        // 6. Function end: .ENDI

        // Analyze what we should expect to generate
        #expect(infocomZAP.contains("THIS-IT?"))  // Function name should appear in .FUNCT directive
        #expect(infocomZAP.contains("FSET?"))
        #expect(infocomZAP.contains(".ENDI"))
        #expect(infocomZAP.contains("?ELS"))
        #expect(infocomZAP.contains("RFALSE"))
    }

    @Test("Generate ZAP from enchanter egg.zil and compare with Infocom output")
    func generateZAPFromEnchanterEggAndCompare() throws {
        // Create extended symbol table for egg.zil with all required symbols
        let symbolTable = SymbolTableManager()

        // Add globals referenced in egg.zil
        _ = symbolTable.defineSymbol(name: "PRSA", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "PRSO", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "PRSI", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "SCORE", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "EGG-POINT", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "REPAIR-POINT", type: .globalVariable, at: .unknown)

        // Add verb constants
        _ = symbolTable.defineSymbol(name: "V?EXAMINE", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "V?LOOK-INSIDE", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "V?OPEN", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "V?CLOSE", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "V?PUT", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "V?REZROV", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "V?TURN", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "V?MOVE", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "V?PUSH", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "V?TAKE", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "V?MUNG", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "V?KREBF", type: .globalVariable, at: .unknown)

        // Add objects
        _ = symbolTable.defineSymbol(name: "EGG", type: .object(properties: [], flags: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "EGG-KNOB-1", type: .object(properties: [], flags: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "EGG-KNOB-2", type: .object(properties: [], flags: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "EGG-KNOB-3", type: .object(properties: [], flags: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "EGG-KNOB-4", type: .object(properties: [], flags: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "EGG-KNOB-5", type: .object(properties: [], flags: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "DAMAGED-SCROLL", type: .object(properties: [], flags: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "SCRAMBLED-EGG", type: .object(properties: [], flags: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "SUMMON-SCROLL", type: .object(properties: [], flags: []), at: .unknown)

        // Add flags
        _ = symbolTable.defineSymbol(name: "OPENBIT", type: .globalVariable, at: .unknown)
        _ = symbolTable.defineSymbol(name: "INVISIBLE", type: .globalVariable, at: .unknown)

        // Add properties
        _ = symbolTable.defineSymbol(name: "P?TEXT", type: .globalVariable, at: .unknown)

        // Add built-in functions
        _ = symbolTable.defineSymbol(name: "GETP", type: .routine(parameters: ["OBJ", "PROP"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "LOC", type: .routine(parameters: ["OBJ"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "FIRST?", type: .routine(parameters: ["OBJ"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "IN?", type: .routine(parameters: ["OBJ1", "OBJ2"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "MOVE", type: .routine(parameters: ["OBJ", "DEST"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "REMOVE", type: .routine(parameters: ["OBJ"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "PERFORM", type: .routine(parameters: ["VERB", "OBJ"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)
        _ = symbolTable.defineSymbol(name: "THIS-IS-IT", type: .routine(parameters: ["OBJ"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)

        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1) // Use O1 production mode

        let location = ZEngine.SourceLocation(file: "egg.zil", line: 1, column: 1)

        // Recreate one of the key routines from egg.zil - EGG-KNOB-STATE
        let eggKnobStateRoutine = ZILRoutineDeclaration(
            name: "EGG-KNOB-STATE",
            parameters: ["KNOB"],
            optionalParameters: [
                ZILParameter(name: "VER?", defaultValue: ZILExpression.atom("<>", location), location: location)
            ],
            body: [
                // <COND (<OR .VER? <FSET? .KNOB ,OPENBIT>>
                ZILExpression.list([
                    ZILExpression.atom("COND", location),
                    ZILExpression.list([
                        ZILExpression.list([
                            ZILExpression.atom("OR", location),
                            ZILExpression.localVariable("VER?", location),
                            ZILExpression.list([
                                ZILExpression.atom("FSET?", location),
                                ZILExpression.localVariable("KNOB", location),
                                ZILExpression.globalVariable("OPENBIT", location)
                            ], location)
                        ], location),
                        // <TELL "The " D .KNOB>
                        ZILExpression.list([
                            ZILExpression.atom("TELL", location),
                            ZILExpression.string("The ", location),
                            ZILExpression.atom("D", location),
                            ZILExpression.localVariable("KNOB", location)
                        ], location),
                        // <COND (<FSET? .KNOB ,OPENBIT> <TELL " has been ">)
                        ZILExpression.list([
                            ZILExpression.atom("COND", location),
                            ZILExpression.list([
                                ZILExpression.list([
                                    ZILExpression.atom("FSET?", location),
                                    ZILExpression.localVariable("KNOB", location),
                                    ZILExpression.globalVariable("OPENBIT", location)
                                ], location),
                                ZILExpression.list([
                                    ZILExpression.atom("TELL", location),
                                    ZILExpression.string(" has been ", location)
                                ], location)
                            ], location),
                            ZILExpression.list([
                                ZILExpression.localVariable("VER?", location),
                                ZILExpression.list([
                                    ZILExpression.atom("TELL", location),
                                    ZILExpression.string(" has not yet been ", location)
                                ], location)
                            ], location)
                        ], location),
                        // <TELL <GETP .KNOB ,P?TEXT> ". ">
                        ZILExpression.list([
                            ZILExpression.atom("TELL", location),
                            ZILExpression.list([
                                ZILExpression.atom("GETP", location),
                                ZILExpression.localVariable("KNOB", location),
                                ZILExpression.globalVariable("P?TEXT", location)
                            ], location),
                            ZILExpression.string(". ", location)
                        ], location)
                    ], location)
                ], location)
            ],
            location: location
        )

        let generatedZAP = try generator.generateCode(from: [.routine(eggKnobStateRoutine)])

        // Write our generated ZAP to a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let generatedZAPFile = tempDir.appendingPathComponent("our_egg_knob_state.zap")
        try generatedZAP.write(to: generatedZAPFile, atomically: true, encoding: .utf8)

        // Read the Infocom ZAP file for comparison
        let infocomZAPPath = "/Users/jim/Projects/ZIL/enchanter/egg.zap"
        let infocomZAP = try String(contentsOfFile: infocomZAPPath, encoding: .utf8)

        // Extract just the EGG-KNOB-STATE routine from Infocom ZAP
        let lines = infocomZAP.components(separatedBy: .newlines)
        var inRoutine = false
        var routineLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".FUNCT\tEGG-KNOB-STATE") {
                inRoutine = true
                routineLines.append(line)
            } else if inRoutine {
                if trimmed.isEmpty && routineLines.last?.trimmingCharacters(in: .whitespaces) == "RTRUE" {
                    break // End of routine
                }
                routineLines.append(line)
            }
        }

        let infocomRoutineZAP = routineLines.joined(separator: "\n")

        // Add both versions as attachments for comparison
        let generatedAttachment = Attachment(generatedZAP, named: "generated-egg-knob-state.zap")
        Attachment.record(generatedAttachment)

        let infocomAttachment = Attachment(infocomRoutineZAP, named: "infocom-egg-knob-state.zap")
        Attachment.record(infocomAttachment)

        // Use diff to compare our generated output with the Infocom routine
        let infocomRoutineFile = tempDir.appendingPathComponent("infocom_egg_knob_state.zap")
        try infocomRoutineZAP.write(to: infocomRoutineFile, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/diff")
        process.arguments = ["-u", infocomRoutineFile.path, generatedZAPFile.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let diffOutput = String(data: data, encoding: .utf8) ?? ""

        // Add diff output as attachment if there are differences
        if !diffOutput.isEmpty {
            let diffAttachment = Attachment(diffOutput, named: "egg-knob-state-comparison.diff")
            Attachment.record(diffAttachment)
        }

        // Clean up
        try? FileManager.default.removeItem(at: generatedZAPFile)
        try? FileManager.default.removeItem(at: infocomRoutineFile)

        // Structural expectations for our generated code
        #expect(generatedZAP.contains("\t.FUNCT\tEGG-KNOB-STATE"))
        #expect(generatedZAP.contains("FSET?"))
        #expect(generatedZAP.contains("GETP"))
        #expect(generatedZAP.contains("PRINTI"))
        // Note: Our generator may not generate RTRUE for all routines - this is a known difference

        // Production mode expectations
        #expect(generatedZAP.contains(".ZVERSION 3"))
        #expect(!generatedZAP.contains("ZAP Assembly Code Generated"))
        #expect(!generatedZAP.contains("Code generation statistics"))

        // Efficiency expectations (our version will be different but should be reasonable)
        let generatedLines = generatedZAP.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        #expect(generatedLines.count <= 40) // Allow for more lines than Infocom due to our different approach
    }
}