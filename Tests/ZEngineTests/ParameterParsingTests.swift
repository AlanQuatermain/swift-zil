import Testing
@testable import ZEngine

@Suite("Parameter Parsing Tests")
struct ParameterParsingTests {

    @Test("Single line parameter list")
    func singleLineParameterList() throws {
        let source = #"<ROUTINE TEST (A B "OPT" C "AUX" D) <RTRUE>>"#

        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer)
        let declarations = try parser.parseProgram()

        #expect(declarations.count == 1)

        guard case .routine(let routine) = declarations[0] else {
            #expect(Bool(false), "Should be a routine")
            return
        }

        #expect(routine.name == "TEST")
        #expect(routine.parameters == ["A", "B"])
        #expect(routine.optionalParameters.map(\.name) == ["C"])
        #expect(routine.auxiliaryVariables.map(\.name) == ["D"])
    }

    @Test("Multi-line parameter list")
    func multiLineParameterList() throws {
        let source = """
        <ROUTINE TEST (A B
                      "OPT" C
                      "AUX" D)
            <RTRUE>>
        """

        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer)
        let declarations = try parser.parseProgram()

        #expect(declarations.count == 1)

        guard case .routine(let routine) = declarations[0] else {
            #expect(Bool(false), "Should be a routine")
            return
        }

        #expect(routine.name == "TEST")
        #expect(routine.parameters == ["A", "B"])
        #expect(routine.optionalParameters.map(\.name) == ["C"])
        #expect(routine.auxiliaryVariables.map(\.name) == ["D"])
    }

    @Test("Optional parameter with default values")
    func optionalParameterWithDefaults() throws {
        let source = #"<ROUTINE TEST ("OPT" (A 10) (B <>)) <RTRUE>>"#

        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer)
        let declarations = try parser.parseProgram()

        #expect(declarations.count == 1)

        guard case .routine(let routine) = declarations[0] else {
            #expect(Bool(false), "Should be a routine")
            return
        }

        #expect(routine.name == "TEST")
        #expect(routine.parameters == [])
        #expect(routine.optionalParameters.count == 2)
        #expect(routine.optionalParameters[0].name == "A")
        #expect(routine.optionalParameters[1].name == "B")

        // Check that default values are captured
        #expect(routine.optionalParameters[0].defaultValue != nil)
        #expect(routine.optionalParameters[1].defaultValue != nil)

        // Check specific default values
        if case .number(let value, _) = routine.optionalParameters[0].defaultValue {
            #expect(value == 10)
        } else {
            #expect(Bool(false), "First optional parameter should have number default value")
        }

        if case .list(let elements, _) = routine.optionalParameters[1].defaultValue {
            #expect(elements.isEmpty, "Second optional parameter should have empty list default value")
        } else {
            #expect(Bool(false), "Second optional parameter should have list default value")
        }
    }
}

