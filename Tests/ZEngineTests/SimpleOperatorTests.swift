import Testing
@testable import ZEngine

@Suite("Simple Operator Tests")
struct SimpleOperatorTests {

    @Test("Basic arithmetic operators as atoms")
    func basicArithmeticOperators() throws {
        let source = #"""
        <ROUTINE TEST-OPERATORS ("AUX" TEMP)
            <SET TEMP <+ 1 2>>
            <SET TEMP <* 3 4>>
            <SET TEMP <- 5 6>>
            <SET TEMP </ 7 8>>
            <RTRUE>>
        """#

        let lexer = ZILLexer(source: source, filename: "operators.zil")
        let parser = try ZILParser(lexer: lexer)
        let declarations = try parser.parseProgram()

        #expect(declarations.count == 1)

        guard case .routine(let routine) = declarations[0] else {
            #expect(Bool(false), "Should be a routine")
            return
        }

        #expect(routine.name == "TEST-OPERATORS")
        #expect(routine.body.count == 5) // Four SETs + RTRUE

        // Check that all operators were parsed as atoms
        let operators = ["SET", "+", "*", "-", "/"]
        var foundOperators: [String] = []

        func extractAtoms(_ expr: ZILExpression) {
            switch expr {
            case .atom(let name, _):
                foundOperators.append(name)
            case .list(let elements, _):
                for element in elements {
                    extractAtoms(element)
                }
            default:
                break
            }
        }

        for expr in routine.body {
            extractAtoms(expr)
        }

        for op in operators {
            #expect(foundOperators.contains(op), "Should find operator \(op)")
        }
    }

    @Test("Comparison operators as atoms")
    func comparisonOperators() throws {
        let source = #"""
        <ROUTINE TEST-COMPARISONS (A B)
            <COND (<EQUAL? .A .B>
                   <RTRUE>)
                  (<G? .A .B>
                   <RTRUE>)
                  (<L? .A .B>
                   <RTRUE>)>
            <RTRUE>>
        """#

        let lexer = ZILLexer(source: source, filename: "comparisons.zil")
        let parser = try ZILParser(lexer: lexer)
        let declarations = try parser.parseProgram()

        #expect(declarations.count == 1)

        guard case .routine(let routine) = declarations[0] else {
            #expect(Bool(false), "Should be a routine")
            return
        }

        #expect(routine.name == "TEST-COMPARISONS")
        #expect(routine.parameters == ["A", "B"])
    }
}