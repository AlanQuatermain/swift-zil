import Testing
@testable import ZEngine

@Suite("Comprehensive Parser Tests - Primitives Only")
struct ComprehensiveParserTests {

    @Suite("Complete ZIL Program with Primitives")
    struct CompleteZILProgramWithPrimitives {

        @Test("Full game module with primitive instructions only")
        func fullGameModuleWithPrimitives() throws {
            let source = #"""
            ; Adventure Game Module - Primitives Only
            <VERSION ZIP>

            "Global variables for the game state"
            <SETG SCORE 0>
            <SETG MOVES 0>
            <SETG LAMP-ON <>>

            <CONSTANT MAX-SCORE 350>
            <CONSTANT INVENTORY-LIMIT 10>
            <CONSTANT M-LOOK 1>
            <CONSTANT M-ENTER 2>

            ; Property definitions
            <PROPDEF STRENGTH 10>
            <PROPDEF CAPACITY 5>

            <OBJECT LIVING-ROOM
                (DESC "You are in a living room.")
                (NORTH TO KITCHEN)
                (EAST TO GARDEN)
                (WEST TO HALLWAY)
                (FLAGS LIGHTBIT ROOMBIT)>

            <OBJECT BRASS-LANTERN
                (IN LIVING-ROOM)
                (SYNONYM LAMP LANTERN LIGHT)
                (ADJECTIVE BRASS)
                (DESC "a brass lantern")
                (FLAGS TAKEBIT LIGHTBIT)
                (STRENGTH 15)
                (ACTION LANTERN-ACTION)>

            <ROUTINE LIVING-ROOM-F (RARG)
                <COND (<EQUAL? .RARG ,M-LOOK>
                       <PRINTI "You are in a cozy living room.">
                       <CRLF>)
                      (<EQUAL? .RARG ,M-ENTER>
                       <MOVE ,PLAYER ,LIVING-ROOM>
                       <RTRUE>)
                      (T
                       <RFALSE>)>>

            <ROUTINE LANTERN-ACTION (OBJ "AUX" RESULT)
                <COND (<EQUAL? ,PRSA ,V?TAKE>
                       <COND (<FSET? .OBJ ,TAKEBIT>
                              <MOVE .OBJ ,PLAYER>
                              <PRINTI "Taken.">
                              <CRLF>
                              <RTRUE>)
                             (T
                              <PRINTI "You can't take that!">
                              <CRLF>
                              <RFALSE>)>)
                      (<OR <EQUAL? ,PRSA ,V?LIGHT>
                           <EQUAL? ,PRSA ,V?ON>>
                       <FSET .OBJ ,ONBIT>
                       <SETG LAMP-ON T>
                       <PRINTI "The lantern glows brightly.">
                       <CRLF>
                       <RTRUE>)
                      (<OR <EQUAL? ,PRSA ,V?EXTINGUISH>
                           <EQUAL? ,PRSA ,V?OFF>>
                       <FCLEAR .OBJ ,ONBIT>
                       <SETG LAMP-ON <>>
                       <PRINTI "The lantern goes dark.">
                       <CRLF>
                       <RTRUE>)
                      (T
                       <PRINTI "You can't do that.">
                       <CRLF>
                       <RFALSE>)>>
            """#

            let lexer = ZILLexer(source: source, filename: "adventure.zil")
            let parser = try ZILParser(lexer: lexer)
            let declarations = try parser.parseProgram()

            // Verify we have all expected declarations
            #expect(declarations.count == 14)

            // 1. VERSION declaration
            guard case .version(let version) = declarations[0] else {
                #expect(Bool(false), "First declaration should be VERSION")
                return
            }
            #expect(version.version == "ZIP")

            // 2-4. Global variable declarations
            let globals = declarations[1...3].compactMap { decl -> ZILGlobalDeclaration? in
                guard case .global(let global) = decl else { return nil }
                return global
            }
            #expect(globals.count == 3)
            #expect(globals[0].name == "SCORE")
            #expect(globals[1].name == "MOVES")
            #expect(globals[2].name == "LAMP-ON")

            // Verify SCORE has number value 0
            if case .number(let score, _) = globals[0].value {
                #expect(score == 0)
            } else {
                #expect(Bool(false), "SCORE should have number value")
            }

            // Verify LAMP-ON has empty list value
            if case .list(let elements, _) = globals[2].value {
                #expect(elements.isEmpty)
            } else {
                #expect(Bool(false), "LAMP-ON should have empty list value")
            }

            // 5-8. Constant declarations
            let constants = declarations[4...7].compactMap { decl -> ZILConstantDeclaration? in
                guard case .constant(let constant) = decl else { return nil }
                return constant
            }
            #expect(constants.count == 4)
            #expect(constants[0].name == "MAX-SCORE")
            #expect(constants[1].name == "INVENTORY-LIMIT")
            #expect(constants[2].name == "M-LOOK")
            #expect(constants[3].name == "M-ENTER")

            // 9-10. Property definitions
            let properties = declarations[8...9].compactMap { decl -> ZILPropertyDeclaration? in
                guard case .property(let property) = decl else { return nil }
                return property
            }
            #expect(properties.count == 2)
            #expect(properties[0].name == "STRENGTH")
            #expect(properties[1].name == "CAPACITY")

            // 11-12. Object declarations
            let objects = [declarations[10], declarations[11]].compactMap { decl -> ZILObjectDeclaration? in
                guard case .object(let object) = decl else { return nil }
                return object
            }
            #expect(objects.count == 2)
            #expect(objects[0].name == "LIVING-ROOM")
            #expect(objects[1].name == "BRASS-LANTERN")

            // Verify LIVING-ROOM object properties
            let livingRoom = objects[0]
            #expect(livingRoom.properties.count == 5) // DESC, NORTH, EAST, WEST, FLAGS

            let descProp = livingRoom.properties.first { $0.name == "DESC" }
            #expect(descProp != nil)
            if let desc = descProp, case .string(let text, _) = desc.value {
                #expect(text == "You are in a living room.")
            }

            let flagsProp = livingRoom.properties.first { $0.name == "FLAGS" }
            #expect(flagsProp != nil)
            if let flags = flagsProp, case .list(let flagList, _) = flags.value {
                #expect(flagList.count == 2)
            }

            // Verify BRASS-LANTERN object properties
            let lantern = objects[1]
            #expect(lantern.properties.count == 7) // IN, SYNONYM, ADJECTIVE, DESC, FLAGS, STRENGTH, ACTION

            let synonymProp = lantern.properties.first { $0.name == "SYNONYM" }
            #expect(synonymProp != nil)
            if let synonyms = synonymProp, case .list(let synonymList, _) = synonyms.value {
                #expect(synonymList.count == 3) // LAMP LANTERN LIGHT
            }

            // 13-14. Routine declarations
            let routines = [declarations[12], declarations[13]].compactMap { decl -> ZILRoutineDeclaration? in
                guard case .routine(let routine) = decl else { return nil }
                return routine
            }
            #expect(routines.count == 2)
            #expect(routines[0].name == "LIVING-ROOM-F")
            #expect(routines[1].name == "LANTERN-ACTION")

            // Verify LIVING-ROOM-F routine structure
            let livingRoomF = routines[0]
            #expect(livingRoomF.parameters == ["RARG"])
            #expect(livingRoomF.optionalParameters.isEmpty)
            #expect(livingRoomF.auxiliaryVariables.isEmpty)
            #expect(livingRoomF.body.count == 1) // One COND expression

            // Verify the COND structure
            if case .list(let condElements, _) = livingRoomF.body[0] {
                #expect(condElements.count >= 1)
                if case .atom(let condAtom, _) = condElements[0] {
                    #expect(condAtom == "COND")
                }
            }

            // Verify LANTERN-ACTION routine structure
            let lanternAction = routines[1]
            #expect(lanternAction.parameters == ["OBJ"])
            #expect(lanternAction.auxiliaryVariables.map(\.name) == ["RESULT"])
            #expect(lanternAction.body.count == 1) // One COND expression
        }

        @Test("Deeply nested primitive expressions")
        func deeplyNestedPrimitiveExpressions() throws {
            let source = #"""
            <ROUTINE COMPLEX-NESTED ("AUX" TEMP COUNTER RESULT)
                <COND (<AND <EQUAL? ,PLAYER-LOC ,FOREST>
                            <OR <FSET? ,LANTERN ,ONBIT>
                                <EQUAL? ,TIME-OF-DAY 1>
                                <EQUAL? ,TIME-OF-DAY 6>>>
                       <SET TEMP <RANDOM 100>>
                       <COND (<G? .TEMP 50>
                              <PRINTI "You hear rustling in the bushes.">
                              <CRLF>
                              <SET COUNTER <RANDOM 4>>
                              <COND (<EQUAL? .COUNTER 1>
                                     <PRINTI "A small rabbit scurries past.">
                                     <CRLF>
                                     <SETG RABBIT-SEEN T>)
                                    (T
                                     <PRINTI "The sound fades away.">
                                     <CRLF>)>)
                             (T
                              <PRINTI "All is quiet in the forest.">
                              <CRLF>)>)
                      (<EQUAL? ,PLAYER-LOC ,CAVE>
                       <COND (<FSET? ,LANTERN ,ONBIT>
                              <PRINTI "Your light illuminates cave paintings.">
                              <CRLF>
                              <COND (<NOT ,PAINTINGS-SEEN>
                                     <SETG PAINTINGS-SEEN T>
                                     <SETG SCORE <+ ,SCORE 10>>
                                     <PRINTI "You gain 10 points!">
                                     <CRLF>)>)
                             (T
                              <PRINTI "It's too dark to see.">
                              <CRLF>)>)
                      (T
                       <PRINTI "Nothing happens.">
                       <CRLF>)>
                <RTRUE>>
            """#

            let lexer = ZILLexer(source: source, filename: "nested.zil")
            let parser = try ZILParser(lexer: lexer)
            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)

            guard case .routine(let routine) = declarations[0] else {
                #expect(Bool(false), "Should be a routine declaration")
                return
            }

            #expect(routine.name == "COMPLEX-NESTED")
            #expect(routine.parameters.isEmpty)
            #expect(routine.auxiliaryVariables.map(\.name) == ["TEMP", "COUNTER", "RESULT"])
            #expect(routine.body.count == 2) // COND expression + RTRUE

            // Verify the outer COND structure
            guard case .list(let outerCond, _) = routine.body[0],
                  case .atom(let condKeyword, _) = outerCond[0] else {
                #expect(Bool(false), "Body should start with COND")
                return
            }

            #expect(condKeyword == "COND")
            #expect(outerCond.count >= 4) // COND + at least 3 condition clauses

            // Verify first condition has complex AND/OR nesting
            guard case .list(let firstCondition, _) = outerCond[1],
                  firstCondition.count >= 2,
                  case .list(let testExpr, _) = firstCondition[0],
                  case .atom(let andKeyword, _) = testExpr[0] else {
                #expect(Bool(false), "First condition should have AND test")
                return
            }

            #expect(andKeyword == "AND")

            // Verify deeply nested structure exists
            func countNestedLists(_ expr: ZILExpression) -> Int {
                switch expr {
                case .list(let elements, _):
                    return 1 + elements.map(countNestedLists).reduce(0, +)
                default:
                    return 0
                }
            }

            let totalLists = countNestedLists(routine.body[0])
            #expect(totalLists >= 20, "Should have deeply nested structure with many lists")
        }

        @Test("Mixed primitive declarations with comments")
        func mixedPrimitiveDeclarationsWithComments() throws {
            let source = #"""
            ; Main game initialization file
            <VERSION ZIP>

            "Setting up global game state"
            <SETG GAME-STATE 1>     ; 1 = starting

            ; Score tracking
            <SETG SCORE 0>
            <CONSTANT WINNING-SCORE 500>

            "Define object properties"
            <PROPDEF SIZE 0>     ; Size property for containers
            <PROPDEF WEIGHT 1>   ; Weight for carry calculations

            <OBJECT PLAYER
                (DESC "yourself")
                (CAPACITY 100)     ; Can carry up to 100 weight units
                (FLAGS ACTORBIT PLAYERBIT)>

            ; The starting room
            <OBJECT ENTRANCE-HALL
                (DESC "a grand entrance hall")
                (UP TO STAIRWAY)
                (NORTH TO PARLOR)
                (FLAGS ROOMBIT LIGHTBIT)>

            <ROUTINE INIT-GAME ("AUX" TEMP LOC-TEMP)
                ; Initialize the game world using primitives only
                <MOVE ,PLAYER ,ENTRANCE-HALL>
                <SETG SCORE 0>
                <SETG GAME-STATE 2>     ; 2 = playing
                <PRINTI "Welcome to the Adventure!">
                <CRLF>
                <CRLF>

                ; Set up initial object states
                <SET TEMP ,ENTRANCE-HALL>
                <FSET .TEMP ,LIGHTBIT>
                <SET LOC-TEMP <LOC ,PLAYER>>
                <COND (<EQUAL? .LOC-TEMP .TEMP>
                       <PRINTI "You are standing in ">
                       <PRINTD .TEMP>
                       <PRINTI ".">
                       <CRLF>)>
                <RTRUE>>
            """#

            let lexer = ZILLexer(source: source, filename: "init.zil")
            let parser = try ZILParser(lexer: lexer)
            let declarations = try parser.parseProgram()

            // Should successfully parse all declarations despite comments
            #expect(declarations.count == 9)

            let declTypes = declarations.map { decl in
                switch decl {
                case .version: return "VERSION"
                case .global: return "GLOBAL"
                case .constant: return "CONSTANT"
                case .property: return "PROPERTY"
                case .object: return "OBJECT"
                case .routine: return "ROUTINE"
                default: return "OTHER"
                }
            }

            let expectedTypes = ["VERSION", "GLOBAL", "GLOBAL", "CONSTANT", "PROPERTY", "PROPERTY", "OBJECT", "OBJECT", "ROUTINE"]
            #expect(declTypes == expectedTypes)

            // Verify routine has auxiliary variables
            guard case .routine(let initGame) = declarations[8] else {
                #expect(Bool(false), "Last declaration should be routine")
                return
            }

            #expect(initGame.name == "INIT-GAME")
            #expect(initGame.parameters.isEmpty)
            #expect(initGame.auxiliaryVariables.map(\.name) == ["TEMP", "LOC-TEMP"])
            #expect(initGame.body.count >= 8) // Multiple primitive statements in body
        }
    }

    @Suite("Complex Primitive Expression Validation")
    struct ComplexPrimitiveExpressionValidation {

        @Test("Conditional expressions with primitive operators")
        func conditionalExpressionsWithPrimitiveOperators() throws {
            let source = #"""
            <ROUTINE TEST-CONDITIONS (FLAG NUM "AUX" TEMP)
                <COND (<AND <G? .NUM 0>
                            <NOT <ZERO? .FLAG>>>
                       <PRINTI "Positive number and flag is non-zero">
                       <CRLF>)
                      (<OR <EQUAL? .NUM 0>
                           <L? .NUM -10>>
                       <PRINTI "Zero or very negative">
                       <CRLF>)
                      (<ZERO? .FLAG>
                       <PRINTI "Flag is zero">
                       <CRLF>)
                      (T
                       <PRINTI "Default case">
                       <CRLF>)>
                <SET TEMP <+ .NUM .FLAG>>
                <RETURN .TEMP>>
            """#

            let lexer = ZILLexer(source: source, filename: "conditions.zil")
            let parser = try ZILParser(lexer: lexer)
            let declarations = try parser.parseProgram()

            guard case .routine(let routine) = declarations[0] else {
                #expect(Bool(false), "Should be a routine")
                return
            }

            #expect(routine.parameters == ["FLAG", "NUM"])
            #expect(routine.auxiliaryVariables.map(\.name) == ["TEMP"])
            #expect(routine.body.count == 3) // COND + SET + RETURN

            // Validate COND structure
            guard case .list(let condExpr, _) = routine.body[0],
                  case .atom(let condAtom, _) = condExpr[0] else {
                #expect(Bool(false), "Body should start with COND expression")
                return
            }

            #expect(condAtom == "COND")
            #expect(condExpr.count == 5) // COND + 4 clauses

            // Verify each clause has condition and action
            for i in 1...4 {
                guard case .list(let clause, _) = condExpr[i] else {
                    #expect(Bool(false), "Each COND clause should be a list")
                    continue
                }
                #expect(clause.count >= 2, "Each clause should have condition and action")
            }

            // Verify SET and RETURN statements
            guard case .list(let setExpr, _) = routine.body[1],
                  case .atom(let setAtom, _) = setExpr[0] else {
                #expect(Bool(false), "Second statement should be SET")
                return
            }
            #expect(setAtom == "SET")

            guard case .list(let returnExpr, _) = routine.body[2],
                  case .atom(let returnAtom, _) = returnExpr[0] else {
                #expect(Bool(false), "Third statement should be RETURN")
                return
            }
            #expect(returnAtom == "RETURN")
        }

        @Test("Arithmetic expressions with nested primitives")
        func arithmeticExpressionsWithNestedPrimitives() throws {
            let source = #"""
            <ROUTINE COMPLEX-CALC (X Y Z "AUX" TEMP1 TEMP2)
                <SET TEMP1 <+ <* .X .Y>
                             <- .Z </ .X 2>>>>
                <SET TEMP2 <MOD <+ .X .Y .Z> 7>>
                <COND (<G? .TEMP1 .TEMP2>
                       <RETURN .TEMP1>)
                      (<L? .TEMP1 .TEMP2>
                       <RETURN .TEMP2>)
                      (T
                       <RETURN <+ .TEMP1 .TEMP2>>)>>
            """#

            let lexer = ZILLexer(source: source, filename: "calc.zil")
            let parser = try ZILParser(lexer: lexer)
            let declarations = try parser.parseProgram()

            guard case .routine(let routine) = declarations[0] else {
                #expect(Bool(false), "Should be a routine")
                return
            }

            #expect(routine.parameters == ["X", "Y", "Z"])
            #expect(routine.auxiliaryVariables.map(\.name) == ["TEMP1", "TEMP2"])
            #expect(routine.body.count == 3) // Two SETs + one COND

            // Verify first SET has nested arithmetic
            guard case .list(let setExpr1, _) = routine.body[0],
                  case .atom(let setAtom1, _) = setExpr1[0],
                  setAtom1 == "SET",
                  case .list(let addExpr, _) = setExpr1[2],
                  case .atom(let addAtom, _) = addExpr[0] else {
                #expect(Bool(false), "First SET should have nested + expression")
                return
            }

            #expect(addAtom == "+")
            #expect(addExpr.count == 3) // + operator + 2 operands

            // Each operand should be a nested expression
            for i in 1...2 {
                guard case .list(_, _) = addExpr[i] else {
                    #expect(Bool(false), "Operand \(i) should be nested expression")
                    return
                }
            }

            // Verify second SET has MOD expression
            guard case .list(let setExpr2, _) = routine.body[1],
                  case .atom(let setAtom2, _) = setExpr2[0],
                  setAtom2 == "SET",
                  case .list(let modExpr, _) = setExpr2[2],
                  case .atom(let modAtom, _) = modExpr[0] else {
                #expect(Bool(false), "Second SET should have MOD expression")
                return
            }

            #expect(modAtom == "MOD")
        }

        @Test("Object manipulation with primitive operations")
        func objectManipulationWithPrimitiveOperations() throws {
            let source = #"""
            <ROUTINE HANDLE-OBJECT (OBJ "AUX" CONTAINER PROP-VAL OLD-LOC)
                <SET OLD-LOC <LOC .OBJ>>
                <COND (<FSET? .OBJ ,TAKEBIT>
                       <MOVE .OBJ ,PLAYER>
                       <FSET .OBJ ,TOUCHBIT>
                       <FCLEAR .OBJ ,NTOUCHBIT>)>

                <SET CONTAINER <LOC ,PLAYER>>
                <COND (<EQUAL? .CONTAINER ,LIVING-ROOM>
                       <SET PROP-VAL <GETP .OBJ ,P?SIZE>>
                       <PUTP .OBJ ,P?SIZE <+ .PROP-VAL 1>>)>

                <COND (<AND <NOT <EQUAL? .OLD-LOC ,PLAYER>>
                            <EQUAL? <LOC .OBJ> ,PLAYER>>
                       <PRINTI "You now have the ">
                       <PRINTD .OBJ>
                       <PRINTI ".">
                       <CRLF>)>

                <RETURN <LOC .OBJ>>>
            """#

            let lexer = ZILLexer(source: source, filename: "objects.zil")
            let parser = try ZILParser(lexer: lexer)
            let declarations = try parser.parseProgram()

            guard case .routine(let routine) = declarations[0] else {
                #expect(Bool(false), "Should be a routine")
                return
            }

            #expect(routine.parameters == ["OBJ"])
            #expect(routine.auxiliaryVariables.map(\.name) == ["CONTAINER", "PROP-VAL", "OLD-LOC"])
            #expect(routine.body.count >= 5) // Multiple primitive operations

            // Verify we have object manipulation primitives
            let primitiveOperations = routine.body.compactMap { expr -> String? in
                if case .list(let elements, _) = expr,
                   case .atom(let op, _) = elements.first {
                    return op
                }
                return nil
            }

            let expectedPrimitives = ["SET", "COND", "SET", "COND", "COND", "RETURN"]
            #expect(primitiveOperations.count >= expectedPrimitives.count)

            // Verify LOC, MOVE, FSET, GETP, PUTP operations are nested within
            func findNestedOperations(_ expr: ZILExpression) -> [String] {
                switch expr {
                case .list(let elements, _):
                    var ops: [String] = []
                    if case .atom(let op, _) = elements.first {
                        ops.append(op)
                    }
                    for element in elements {
                        ops.append(contentsOf: findNestedOperations(element))
                    }
                    return ops
                default:
                    return []
                }
            }

            let allOperations = routine.body.flatMap(findNestedOperations)
            #expect(allOperations.contains("LOC"))
            #expect(allOperations.contains("MOVE"))
            #expect(allOperations.contains("FSET"))
            #expect(allOperations.contains("GETP"))
            #expect(allOperations.contains("PUTP"))
        }

        @Test("Input/output primitives with proper structure")
        func inputOutputPrimitivesWithProperStructure() throws {
            let source = #"""
            <ROUTINE DISPLAY-STATUS (SCORE MAX-SCORE LOCATION "AUX" TEMP-STR)
                <PRINTI "Score: ">
                <PRINTN .SCORE>
                <PRINTI " out of ">
                <PRINTN .MAX-SCORE>
                <CRLF>

                <PRINTI "Location: ">
                <PRINTD .LOCATION>
                <CRLF>

                <COND (<FSET? .LOCATION ,DARKBIT>
                       <PRINTI "It is dark here.">
                       <CRLF>)
                      (<FSET? .LOCATION ,LIGHTBIT>
                       <PRINTI "The area is well lit.">
                       <CRLF>)>

                <SET TEMP-STR <GETP .LOCATION ,P?LDESC>>
                <COND (.TEMP-STR
                       <PRINT .TEMP-STR>
                       <CRLF>)>

                <RTRUE>>
            """#

            let lexer = ZILLexer(source: source, filename: "io.zil")
            let parser = try ZILParser(lexer: lexer)
            let declarations = try parser.parseProgram()

            guard case .routine(let routine) = declarations[0] else {
                #expect(Bool(false), "Should be a routine")
                return
            }

            #expect(routine.parameters == ["SCORE", "MAX-SCORE", "LOCATION"])
            #expect(routine.auxiliaryVariables.map(\.name) == ["TEMP-STR"])

            // Find all I/O primitive operations
            func findIOOperations(_ expr: ZILExpression) -> [String] {
                switch expr {
                case .list(let elements, _):
                    var ops: [String] = []
                    if case .atom(let op, _) = elements.first {
                        if ["PRINTI", "PRINTN", "PRINTD", "PRINT", "CRLF"].contains(op) {
                            ops.append(op)
                        }
                    }
                    for element in elements {
                        ops.append(contentsOf: findIOOperations(element))
                    }
                    return ops
                default:
                    return []
                }
            }

            let ioOperations = routine.body.flatMap(findIOOperations)
            #expect(ioOperations.contains("PRINTI"))
            #expect(ioOperations.contains("PRINTN"))
            #expect(ioOperations.contains("PRINTD"))
            #expect(ioOperations.contains("PRINT"))
            #expect(ioOperations.contains("CRLF"))

            // Verify proper count of I/O operations (5 PRINTIs, 2 PRINTNs, etc.)
            #expect(ioOperations.filter { $0 == "PRINTI" }.count >= 5)
            #expect(ioOperations.filter { $0 == "PRINTN" }.count >= 2)
            #expect(ioOperations.filter { $0 == "CRLF" }.count >= 5)
        }
    }

    @Suite("Edge Cases with Primitive Instructions")
    struct EdgeCasesWithPrimitiveInstructions {

        @Test("Complex parameter handling with primitives")
        func complexParameterHandlingWithPrimitives() throws {
            let source = #"""
            <ROUTINE PARAM-TEST (REQUIRED1 REQUIRED2 "OPT" (OPTIONAL1 10) (OPTIONAL2 <>)
                                "AUX" AUX1 AUX2 AUX3)
                <SET AUX1 <+ .REQUIRED1 .REQUIRED2>>
                <SET AUX2 <OR .OPTIONAL1 5>>
                <SET AUX3 .OPTIONAL2>

                <COND (<AND .OPTIONAL1 .OPTIONAL2>
                       <PRINTI "Both optionals provided">
                       <CRLF>)
                      (.OPTIONAL1
                       <PRINTI "Only first optional">
                       <CRLF>)
                      (T
                       <PRINTI "Using defaults">
                       <CRLF>)>

                <RETURN <+ .AUX1 .AUX2>>>
            """#

            let lexer = ZILLexer(source: source, filename: "params.zil")
            let parser = try ZILParser(lexer: lexer)
            let declarations = try parser.parseProgram()

            guard case .routine(let routine) = declarations[0] else {
                #expect(Bool(false), "Should be a routine")
                return
            }

            #expect(routine.name == "PARAM-TEST")
            #expect(routine.parameters == ["REQUIRED1", "REQUIRED2"])
            #expect(routine.optionalParameters.map(\.name) == ["OPTIONAL1", "OPTIONAL2"])
            #expect(routine.auxiliaryVariables.map(\.name) == ["AUX1", "AUX2", "AUX3"])
            #expect(routine.body.count >= 4) // Three SETs + COND + RETURN
        }

        @Test("Boundary value testing with primitive arithmetic")
        func boundaryValueTestingWithPrimitiveArithmetic() throws {
            let source = #"""
            <ROUTINE BOUNDARY-ARITHMETIC ("AUX" MAX-VAL MIN-VAL HEX-VAL OCT-VAL BIN-VAL)
                ; Test various numeric boundaries with primitives
                <SET MAX-VAL 32767>
                <SET MIN-VAL -32768>
                <SET HEX-VAL -1>
                <SET OCT-VAL 32767>
                <SET BIN-VAL 255>

                <COND (<EQUAL? .MAX-VAL 32767>
                       <PRINTI "Max value correct">
                       <CRLF>)>

                <COND (<EQUAL? .HEX-VAL -1>
                       <PRINTI "Hex conversion correct">
                       <CRLF>)>

                <SET MAX-VAL <+ .MAX-VAL 1>>  ; Should wrap or error
                <COND (<L? .MAX-VAL 0>
                       <PRINTI "Wrapped to negative">
                       <CRLF>)>

                <RETURN <+ .MAX-VAL .MIN-VAL>>>
            """#

            let lexer = ZILLexer(source: source, filename: "boundary.zil")
            let parser = try ZILParser(lexer: lexer)
            let declarations = try parser.parseProgram()

            guard case .routine(let routine) = declarations[0] else {
                #expect(Bool(false), "Should be a routine")
                return
            }

            #expect(routine.name == "BOUNDARY-ARITHMETIC")
            #expect(routine.auxiliaryVariables.map(\.name) == ["MAX-VAL", "MIN-VAL", "HEX-VAL", "OCT-VAL", "BIN-VAL"])

            // Verify numeric literals were parsed correctly
            let hasNumericLiterals = routine.body.contains { expr in
                if case .list(let elements, _) = expr,
                   elements.count >= 3,
                   case .number(32767, _) = elements[2] {
                    return true
                }
                return false
            }
            #expect(hasNumericLiterals, "Should contain 32767 literal")

            // Verify hex literal ($FFFF = -1 in Int16)
            let hasHexLiteral = routine.body.contains { expr in
                if case .list(let elements, _) = expr,
                   elements.count >= 3,
                   case .number(-1, _) = elements[2] {
                    return true
                }
                return false
            }
            #expect(hasHexLiteral, "Should contain $FFFF as -1 (Int16 overflow)")
        }

        @Test("Variable reference patterns with primitives")
        func variableReferencePatternsWithPrimitives() throws {
            let source = #"""
            <ROUTINE VAR-REF-TEST ("AUX" LOCAL-VAR)
                ; Test all variable reference types
                <SET LOCAL-VAR 42>          ; Initialize with actual value
                <SETG GLOBAL-VAR ,GLOBAL-VAR>       ; Global variable

                ; Property references
                <SET LOCAL-VAR <GETP ,PLAYER ,P?STRENGTH>>
                <PUTP ,PLAYER ,P?STRENGTH <+ <GETP ,PLAYER ,P?STRENGTH> 1>>

                ; Flag references
                <COND (<FSET? ,PLAYER ,TAKEBIT>
                       <FCLEAR ,PLAYER ,TAKEBIT>)
                      (T
                       <FSET ,PLAYER ,TAKEBIT>)>

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

            #expect(routine.auxiliaryVariables.map(\.name) == ["LOCAL-VAR"])

            // Find all variable reference types
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
                case .list(let elements, _):
                    return elements.flatMap(findVariableReferences)
                default:
                    return []
                }
            }

            let allVarRefs = routine.body.flatMap(findVariableReferences)
            #expect(allVarRefs.contains { $0.starts(with: "local:") })
            #expect(allVarRefs.contains { $0.starts(with: "global:") })
            #expect(allVarRefs.contains("global:P?STRENGTH"))  // Property reference as global
            #expect(allVarRefs.contains("global:TAKEBIT"))     // Flag reference as global
        }
    }
}