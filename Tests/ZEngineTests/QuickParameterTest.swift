import Testing
@testable import ZEngine

@Suite("Quick Parameter Test")
struct QuickParameterTest {

    @Test("Basic parameter with defaults")
    func basicParameterWithDefaults() throws {
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
        #expect(routine.optionalParameters.count == 2)
        #expect(routine.optionalParameters[0].name == "A")

        // Verify default value is captured
        if case .number(let value, _) = routine.optionalParameters[0].defaultValue {
            #expect(value == 10)
            print("✅ Successfully captured default value: \(value)")
        } else {
            print("❌ Default value not captured correctly")
            #expect(Bool(false), "Default value should be captured")
        }
    }
}