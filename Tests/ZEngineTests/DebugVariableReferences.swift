import Testing
@testable import ZEngine

@Suite("Debug Variable References")
struct DebugVariableReferences {

    @Test("Debug variable reference recognition")
    func debugVariableReferences() throws {
        let source = #"""
        <ROUTINE VAR-REF-TEST ("AUX" LOCAL-VAR)
            ; Test all variable reference types
            <SET LOCAL-VAR 42>          ; Initialize with actual value
            <SETG GLOBAL-VAR ,GLOBAL-VAR>       ; Global variable

            ; Property references
            <SET LOCAL-VAR <GETP ,PLAYER ,P?STRENGTH>>
            <PUTP ,PLAYER ,P?STRENGTH <+ <GETP ,PLAYER ,P?STRENGTH> 1>>

            ; Flag references
            <COND (<FSET? ,PLAYER ,F?TAKEBIT>
                   <FCLEAR ,PLAYER ,F?TAKEBIT>)
                  (T
                   <FSET ,PLAYER ,F?TAKEBIT>)>

            ; Nested references
            <SET LOCAL-VAR <GETP <LOC ,PLAYER> ,P?LDESC>>

            <RETURN .LOCAL-VAR>>
        """#

        let lexer = ZILLexer(source: source, filename: "varref.zil")
        let parser = try ZILParser(lexer: lexer)
        let declarations = try parser.parseProgram()

        guard case .routine(let routine) = declarations[0] else {
            #expect(Bool(false), "Should be a routine")
            return
        }

        func findVariableReferences(_ expr: ZILExpression) -> [String] {
            switch expr {
            case .localVariable(let name, _):
                return ["local:\(name)"]
            case .globalVariable(let name, _):
                return ["global:\(name)"]
            case .propertyReference(let name, _):
                return ["property:\(name)"]
            case .flagReference(let name, _):
                return ["flag:\(name)"]
            case .atom(let name, _):
                if name.hasPrefix("P?") {
                    return ["atom-property:\(name)"]
                } else if name.hasPrefix("F?") {
                    return ["atom-flag:\(name)"]
                } else {
                    return ["atom:\(name)"]
                }
            case .list(let elements, _):
                return elements.flatMap(findVariableReferences)
            default:
                return []
            }
        }

        let allVarRefs = routine.body.flatMap(findVariableReferences)
        print("All variable references found: \(allVarRefs)")

        let propertyRefs = allVarRefs.filter { $0.contains("property") }
        let flagRefs = allVarRefs.filter { $0.contains("flag") }

        print("Property references: \(propertyRefs)")
        print("Flag references: \(flagRefs)")
    }
}