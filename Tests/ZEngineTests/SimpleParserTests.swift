import Testing
@testable import ZEngine

@Suite("Simple Parser Tests")
struct SimpleParserTests {

    @Test("Basic atom parsing")
    func basicAtomParsing() throws {
        let source = "HELLO"
        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer)

        let expression = try parser.parseExpression()

        if case .atom(let name, _) = expression {
            #expect(name == "HELLO")
        } else {
            #expect(Bool(false), "Expected atom expression")
        }
    }

    @Test("Simple routine parsing")
    func simpleRoutineParsing() throws {
        let source = #"""
        <ROUTINE TEST ()
            <RTRUE>>
        """#

        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer)

        let declarations = try parser.parseProgram()

        #expect(declarations.count == 1)

        if case .routine(let routine) = declarations[0] {
            #expect(routine.name == "TEST")
            #expect(routine.parameters.isEmpty)
            #expect(routine.body.count == 1)
        } else {
            #expect(Bool(false), "Expected routine declaration")
        }
    }

    @Test("Simple object parsing")
    func simpleObjectParsing() throws {
        let source = #"""
        <OBJECT LAMP
            (DESC "a lamp")>
        """#

        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer)

        let declarations = try parser.parseProgram()

        #expect(declarations.count == 1)

        if case .object(let object) = declarations[0] {
            #expect(object.name == "LAMP")
            #expect(object.properties.count == 1)
            #expect(object.properties[0].name == "DESC")
        } else {
            #expect(Bool(false), "Expected object declaration")
        }
    }

    @Test("Version parsing")
    func versionParsing() throws {
        let source = "<VERSION ZIP>"
        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer)

        let declarations = try parser.parseProgram()

        #expect(declarations.count == 1)

        if case .version(let version) = declarations[0] {
            #expect(version.version == "ZIP")
        } else {
            #expect(Bool(false), "Expected version declaration")
        }
    }
}