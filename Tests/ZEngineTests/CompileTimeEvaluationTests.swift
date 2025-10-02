import Testing
@testable import ZEngine

@Suite("Compile-Time Evaluation Tests")
struct CompileTimeEvaluationTests {

    @Test("Basic arithmetic operations")
    func basicArithmeticOperations() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Test addition
        let addExpr = ZILExpression.list([
            .atom("+", location),
            .number(5, location),
            .number(3, location)
        ], location)

        let addResult = processor.evaluateExpression(addExpr)
        guard case .success(let addValue) = addResult else {
            Issue.record("Addition should succeed, but got: \(addResult)")
            return
        }

        guard case .number(let sum, _) = addValue else {
            Issue.record("Addition result should be a number, but got: \(addValue)")
            return
        }
        #expect(sum == 8, "5 + 3 should equal 8")

        // Test subtraction
        let subtractExpr = ZILExpression.list([
            .atom("-", location),
            .number(10, location),
            .number(4, location)
        ], location)

        let subtractResult = processor.evaluateExpression(subtractExpr)
        guard case .success(let subtractValue) = subtractResult else {
            Issue.record("Subtraction should succeed, but got: \(subtractResult)")
            return
        }

        guard case .number(let difference, _) = subtractValue else {
            Issue.record("Subtraction result should be a number, but got: \(subtractValue)")
            return
        }
        #expect(difference == 6, "10 - 4 should equal 6")

        // Test multiplication
        let multiplyExpr = ZILExpression.list([
            .atom("*", location),
            .number(6, location),
            .number(7, location)
        ], location)

        let multiplyResult = processor.evaluateExpression(multiplyExpr)
        guard case .success(let multiplyValue) = multiplyResult else {
            Issue.record("Multiplication should succeed, but got: \(multiplyResult)")
            return
        }

        guard case .number(let product, _) = multiplyValue else {
            Issue.record("Multiplication result should be a number, but got: \(multiplyValue)")
            return
        }
        #expect(product == 42, "6 * 7 should equal 42")

        // Test division
        let divideExpr = ZILExpression.list([
            .atom("/", location),
            .number(20, location),
            .number(4, location)
        ], location)

        let divideResult = processor.evaluateExpression(divideExpr)
        guard case .success(let divideValue) = divideResult else {
            Issue.record("Division should succeed, but got: \(divideResult)")
            return
        }

        guard case .number(let quotient, _) = divideValue else {
            Issue.record("Division result should be a number, but got: \(divideValue)")
            return
        }
        #expect(quotient == 5, "20 / 4 should equal 5")
    }

    @Test("Comparison operations")
    func comparisonOperations() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Test equality
        let equalExpr = ZILExpression.list([
            .atom("=", location),
            .number(5, location),
            .number(5, location)
        ], location)

        let equalResult = processor.evaluateExpression(equalExpr)
        guard case .success(let equalValue) = equalResult else {
            Issue.record("Equality should succeed, but got: \(equalResult)")
            return
        }

        guard case .number(let isEqual, _) = equalValue else {
            Issue.record("Equality result should be a number, but got: \(equalValue)")
            return
        }
        #expect(isEqual == 1, "5 = 5 should be true (1)")

        // Test less than
        let lessThanExpr = ZILExpression.list([
            .atom("<", location),
            .number(3, location),
            .number(7, location)
        ], location)

        let lessThanResult = processor.evaluateExpression(lessThanExpr)
        guard case .success(let lessThanValue) = lessThanResult else {
            Issue.record("Less than should succeed, but got: \(lessThanResult)")
            return
        }

        guard case .number(let isLessThan, _) = lessThanValue else {
            Issue.record("Less than result should be a number, but got: \(lessThanValue)")
            return
        }
        #expect(isLessThan == 1, "3 < 7 should be true (1)")

        // Test greater than
        let greaterThanExpr = ZILExpression.list([
            .atom(">", location),
            .number(10, location),
            .number(5, location)
        ], location)

        let greaterThanResult = processor.evaluateExpression(greaterThanExpr)
        guard case .success(let greaterThanValue) = greaterThanResult else {
            Issue.record("Greater than should succeed, but got: \(greaterThanResult)")
            return
        }

        guard case .number(let isGreaterThan, _) = greaterThanValue else {
            Issue.record("Greater than result should be a number, but got: \(greaterThanValue)")
            return
        }
        #expect(isGreaterThan == 1, "10 > 5 should be true (1)")
    }

    @Test("Logical operations")
    func logicalOperations() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Test AND
        let andExpr = ZILExpression.list([
            .atom("AND", location),
            .number(1, location),
            .number(5, location)
        ], location)

        let andResult = processor.evaluateExpression(andExpr)
        guard case .success(let andValue) = andResult else {
            Issue.record("AND should succeed, but got: \(andResult)")
            return
        }

        guard case .number(let andResult_value, _) = andValue else {
            Issue.record("AND result should be a number, but got: \(andValue)")
            return
        }
        #expect(andResult_value == 1, "AND 1 5 should be true (1)")

        // Test OR
        let orExpr = ZILExpression.list([
            .atom("OR", location),
            .number(0, location),
            .number(3, location)
        ], location)

        let orResult = processor.evaluateExpression(orExpr)
        guard case .success(let orValue) = orResult else {
            Issue.record("OR should succeed, but got: \(orResult)")
            return
        }

        guard case .number(let orResult_value, _) = orValue else {
            Issue.record("OR result should be a number, but got: \(orValue)")
            return
        }
        #expect(orResult_value == 1, "OR 0 3 should be true (1)")

        // Test NOT
        let notExpr = ZILExpression.list([
            .atom("NOT", location),
            .number(0, location)
        ], location)

        let notResult = processor.evaluateExpression(notExpr)
        guard case .success(let notValue) = notResult else {
            Issue.record("NOT should succeed, but got: \(notResult)")
            return
        }

        guard case .number(let notResult_value, _) = notValue else {
            Issue.record("NOT result should be a number, but got: \(notValue)")
            return
        }
        #expect(notResult_value == 1, "NOT 0 should be true (1)")
    }

    @Test("Conditional expressions")
    func conditionalExpressions() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Test IF with true condition
        let ifTrueExpr = ZILExpression.list([
            .atom("IF", location),
            .number(1, location),
            .number(42, location),
            .number(99, location)
        ], location)

        let ifTrueResult = processor.evaluateExpression(ifTrueExpr)
        guard case .success(let ifTrueValue) = ifTrueResult else {
            Issue.record("IF true should succeed, but got: \(ifTrueResult)")
            return
        }

        guard case .number(let ifTrueResult_value, _) = ifTrueValue else {
            Issue.record("IF true result should be a number, but got: \(ifTrueValue)")
            return
        }
        #expect(ifTrueResult_value == 42, "IF 1 42 99 should return 42")

        // Test IF with false condition
        let ifFalseExpr = ZILExpression.list([
            .atom("IF", location),
            .number(0, location),
            .number(42, location),
            .number(99, location)
        ], location)

        let ifFalseResult = processor.evaluateExpression(ifFalseExpr)
        guard case .success(let ifFalseValue) = ifFalseResult else {
            Issue.record("IF false should succeed, but got: \(ifFalseResult)")
            return
        }

        guard case .number(let ifFalseResult_value, _) = ifFalseValue else {
            Issue.record("IF false result should be a number, but got: \(ifFalseValue)")
            return
        }
        #expect(ifFalseResult_value == 99, "IF 0 42 99 should return 99")

        // Test COND
        let condExpr = ZILExpression.list([
            .atom("COND", location),
            .number(0, location),  // false condition
            .number(10, location), // result if true
            .number(1, location),  // true condition
            .number(20, location)  // result if true
        ], location)

        let condResult = processor.evaluateExpression(condExpr)
        guard case .success(let condValue) = condResult else {
            Issue.record("COND should succeed, but got: \(condResult)")
            return
        }

        guard case .number(let condResult_value, _) = condValue else {
            Issue.record("COND result should be a number, but got: \(condValue)")
            return
        }
        #expect(condResult_value == 20, "COND should return 20 for first true condition")
    }

    @Test("List operations")
    func listOperations() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Create a test list
        let testList = ZILExpression.list([
            .number(10, location),
            .number(20, location),
            .number(30, location)
        ], location)

        // Test LENGTH
        let lengthExpr = ZILExpression.list([
            .atom("LENGTH", location),
            testList
        ], location)

        let lengthResult = processor.evaluateExpression(lengthExpr)
        guard case .success(let lengthValue) = lengthResult else {
            Issue.record("LENGTH should succeed, but got: \(lengthResult)")
            return
        }

        guard case .number(let length, _) = lengthValue else {
            Issue.record("LENGTH result should be a number, but got: \(lengthValue)")
            return
        }
        #expect(length == 3, "LENGTH of 3-element list should be 3")

        // Test NTH
        let nthExpr = ZILExpression.list([
            .atom("NTH", location),
            .number(2, location),  // ZIL uses 1-based indexing
            testList
        ], location)

        let nthResult = processor.evaluateExpression(nthExpr)
        guard case .success(let nthValue) = nthResult else {
            Issue.record("NTH should succeed, but got: \(nthResult)")
            return
        }

        guard case .number(let nthElement, _) = nthValue else {
            Issue.record("NTH result should be a number, but got: \(nthValue)")
            return
        }
        #expect(nthElement == 20, "NTH 2 of list should return second element (20)")

        // Test REST
        let restExpr = ZILExpression.list([
            .atom("REST", location),
            testList
        ], location)

        let restResult = processor.evaluateExpression(restExpr)
        guard case .success(let restValue) = restResult else {
            Issue.record("REST should succeed, but got: \(restResult)")
            return
        }

        guard case .list(let restElements, _) = restValue else {
            Issue.record("REST result should be a list, but got: \(restValue)")
            return
        }
        #expect(restElements.count == 2, "REST should return list with 2 elements")

        guard case .number(let firstRest, _) = restElements[0] else {
            Issue.record("First REST element should be a number, but got: \(restElements[0])")
            return
        }
        #expect(firstRest == 20, "First element of REST should be 20")
    }

    @Test("Constant lookup")
    func constantLookup() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define some constants
        processor.defineConstant(name: "MAX-HEALTH", value: .number(100, location))
        processor.defineConstant(name: "MIN-DAMAGE", value: .number(5, location))

        // Test constant evaluation
        let constantExpr = ZILExpression.atom("MAX-HEALTH", location)
        let constantResult = processor.evaluateExpression(constantExpr)
        guard case .success(let constantValue) = constantResult else {
            Issue.record("Constant lookup should succeed, but got: \(constantResult)")
            return
        }

        guard case .number(let health, _) = constantValue else {
            Issue.record("Constant result should be a number, but got: \(constantValue)")
            return
        }
        #expect(health == 100, "MAX-HEALTH constant should evaluate to 100")

        // Test arithmetic with constants
        let arithmeticWithConstantsExpr = ZILExpression.list([
            .atom("+", location),
            .atom("MAX-HEALTH", location),
            .atom("MIN-DAMAGE", location)
        ], location)

        let arithmeticResult = processor.evaluateExpression(arithmeticWithConstantsExpr)
        guard case .success(let arithmeticValue) = arithmeticResult else {
            Issue.record("Arithmetic with constants should succeed, but got: \(arithmeticResult)")
            return
        }

        guard case .number(let sum, _) = arithmeticValue else {
            Issue.record("Arithmetic result should be a number, but got: \(arithmeticValue)")
            return
        }
        #expect(sum == 105, "MAX-HEALTH + MIN-DAMAGE should equal 105")
    }

    @Test("EVAL in macro expansion")
    func evalInMacroExpansion() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define constants for use in macro
        processor.defineConstant(name: "BASE-VALUE", value: .number(10, location))

        // Define macro that uses EVAL for compile-time computation
        // COMPUTE(MULTIPLIER) -> <EVAL <* ,BASE-VALUE .MULTIPLIER>>
        let macroBody = ZILExpression.list([
            .atom("EVAL", location),
            .list([
                .atom("*", location),
                .atom("BASE-VALUE", location),  // This is a constant
                .localVariable("MULTIPLIER", location)  // This is the parameter
            ], location)
        ], location)

        _ = processor.defineMacro(
            name: "COMPUTE",
            parameters: [.standard("MULTIPLIER")],
            body: macroBody,
            at: location
        )

        // Expand the macro with a numeric argument
        let result = processor.expandMacro(
            name: "COMPUTE",
            arguments: [.number(7, location)],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("EVAL macro should expand successfully, but got: \(result)")
            return
        }

        // Should evaluate to the computed result: 10 * 7 = 70
        guard case .number(let computedValue, _) = expanded else {
            Issue.record("EVAL macro result should be a number, but got: \(expanded)")
            return
        }
        #expect(computedValue == 70, "COMPUTE 7 should evaluate to 70 at compile time")
    }

    @Test("Complex compile-time computation")
    func complexCompileTimeComputation() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Test nested arithmetic: (5 + 3) * (10 - 2) = 8 * 8 = 64
        let complexExpr = ZILExpression.list([
            .atom("*", location),
            .list([
                .atom("+", location),
                .number(5, location),
                .number(3, location)
            ], location),
            .list([
                .atom("-", location),
                .number(10, location),
                .number(2, location)
            ], location)
        ], location)

        let complexResult = processor.evaluateExpression(complexExpr)
        guard case .success(let complexValue) = complexResult else {
            Issue.record("Complex computation should succeed, but got: \(complexResult)")
            return
        }

        guard case .number(let result, _) = complexValue else {
            Issue.record("Complex computation result should be a number, but got: \(complexValue)")
            return
        }
        #expect(result == 64, "(5 + 3) * (10 - 2) should equal 64")
    }

    @Test("Error handling")
    func errorHandling() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Test division by zero
        let divideByZeroExpr = ZILExpression.list([
            .atom("/", location),
            .number(10, location),
            .number(0, location)
        ], location)

        let divideByZeroResult = processor.evaluateExpression(divideByZeroExpr)
        guard case .error(let errorMessage) = divideByZeroResult else {
            Issue.record("Division by zero should produce error, but got: \(divideByZeroResult)")
            return
        }
        #expect(errorMessage.contains("Division by zero"), "Should report division by zero error")

        // Test wrong argument count
        let wrongArgCountExpr = ZILExpression.list([
            .atom("+", location)  // No arguments
        ], location)

        let wrongArgCountResult = processor.evaluateExpression(wrongArgCountExpr)
        guard case .error(let argErrorMessage) = wrongArgCountResult else {
            Issue.record("Wrong argument count should produce error, but got: \(wrongArgCountResult)")
            return
        }
        #expect(argErrorMessage.contains("at least one argument"), "Should report argument count error")
    }

    @Test("Non-evaluable expressions")
    func nonEvaluableExpressions() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Test unknown function
        let unknownFunctionExpr = ZILExpression.list([
            .atom("UNKNOWN-FUNCTION", location),
            .number(1, location)
        ], location)

        let unknownResult = processor.evaluateExpression(unknownFunctionExpr)
        guard case .notEvaluable = unknownResult else {
            Issue.record("Unknown function should be not evaluable, but got: \(unknownResult)")
            return
        }

        // Test variable reference (not a constant)
        let variableExpr = ZILExpression.atom("UNKNOWN-VARIABLE", location)
        let variableResult = processor.evaluateExpression(variableExpr)
        guard case .notEvaluable = variableResult else {
            Issue.record("Unknown variable should be not evaluable, but got: \(variableResult)")
            return
        }
    }

    @Test("String operations")
    func stringOperations() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Test SUBSTRING
        let substringExpr = ZILExpression.list([
            .atom("SUBSTRING", location),
            .string("Hello World", location),
            .number(7, location),  // Start at character 7 (1-based)
            .number(5, location)   // Length of 5 characters
        ], location)

        let substringResult = processor.evaluateExpression(substringExpr)
        guard case .success(let substringValue) = substringResult else {
            Issue.record("SUBSTRING should succeed, but got: \(substringResult)")
            return
        }

        guard case .string(let substring, _) = substringValue else {
            Issue.record("SUBSTRING result should be a string, but got: \(substringValue)")
            return
        }
        #expect(substring == "World", "SUBSTRING should extract 'World' from 'Hello World'")

        // Test STRING-CONCAT
        let concatExpr = ZILExpression.list([
            .atom("STRING-CONCAT", location),
            .string("Hello", location),
            .string(" ", location),
            .string("ZIL", location),
            .string("!", location)
        ], location)

        let concatResult = processor.evaluateExpression(concatExpr)
        guard case .success(let concatValue) = concatResult else {
            Issue.record("STRING-CONCAT should succeed, but got: \(concatResult)")
            return
        }

        guard case .string(let concatenated, _) = concatValue else {
            Issue.record("STRING-CONCAT result should be a string, but got: \(concatValue)")
            return
        }
        #expect(concatenated == "Hello ZIL!", "STRING-CONCAT should concatenate all strings")

        // Test STRING-LENGTH
        let lengthExpr = ZILExpression.list([
            .atom("STRING-LENGTH", location),
            .string("Testing", location)
        ], location)

        let lengthResult = processor.evaluateExpression(lengthExpr)
        guard case .success(let lengthValue) = lengthResult else {
            Issue.record("STRING-LENGTH should succeed, but got: \(lengthResult)")
            return
        }

        guard case .number(let length, _) = lengthValue else {
            Issue.record("STRING-LENGTH result should be a number, but got: \(lengthValue)")
            return
        }
        #expect(length == 7, "STRING-LENGTH should return 7 for 'Testing'")

        // Test STRING-UPPER
        let upperExpr = ZILExpression.list([
            .atom("STRING-UPPER", location),
            .string("hello world", location)
        ], location)

        let upperResult = processor.evaluateExpression(upperExpr)
        guard case .success(let upperValue) = upperResult else {
            Issue.record("STRING-UPPER should succeed, but got: \(upperResult)")
            return
        }

        guard case .string(let uppercased, _) = upperValue else {
            Issue.record("STRING-UPPER result should be a string, but got: \(upperValue)")
            return
        }
        #expect(uppercased == "HELLO WORLD", "STRING-UPPER should convert to uppercase")

        // Test STRING-LOWER
        let lowerExpr = ZILExpression.list([
            .atom("STRING-LOWER", location),
            .string("HELLO WORLD", location)
        ], location)

        let lowerResult = processor.evaluateExpression(lowerExpr)
        guard case .success(let lowerValue) = lowerResult else {
            Issue.record("STRING-LOWER should succeed, but got: \(lowerResult)")
            return
        }

        guard case .string(let lowercased, _) = lowerValue else {
            Issue.record("STRING-LOWER result should be a string, but got: \(lowerValue)")
            return
        }
        #expect(lowercased == "hello world", "STRING-LOWER should convert to lowercase")

        // Test STRING-INDEX
        let indexExpr = ZILExpression.list([
            .atom("STRING-INDEX", location),
            .string("Hello World", location),
            .string("World", location)
        ], location)

        let indexResult = processor.evaluateExpression(indexExpr)
        guard case .success(let indexValue) = indexResult else {
            Issue.record("STRING-INDEX should succeed, but got: \(indexResult)")
            return
        }

        guard case .number(let index, _) = indexValue else {
            Issue.record("STRING-INDEX result should be a number, but got: \(indexValue)")
            return
        }
        #expect(index == 7, "STRING-INDEX should find 'World' at position 7 (1-based)")

        // Test STRING-INDEX with not found
        let notFoundExpr = ZILExpression.list([
            .atom("STRING-INDEX", location),
            .string("Hello World", location),
            .string("ZIL", location)
        ], location)

        let notFoundResult = processor.evaluateExpression(notFoundExpr)
        guard case .success(let notFoundValue) = notFoundResult else {
            Issue.record("STRING-INDEX not found should succeed, but got: \(notFoundResult)")
            return
        }

        guard case .number(let notFoundIndex, _) = notFoundValue else {
            Issue.record("STRING-INDEX not found result should be a number, but got: \(notFoundValue)")
            return
        }
        #expect(notFoundIndex == 0, "STRING-INDEX should return 0 when substring not found")
    }

    @Test("String operations error handling")
    func stringOperationsErrorHandling() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Test SUBSTRING with wrong argument count
        let wrongArgCountExpr = ZILExpression.list([
            .atom("SUBSTRING", location),
            .string("Hello", location)  // Missing start and length
        ], location)

        let wrongArgResult = processor.evaluateExpression(wrongArgCountExpr)
        guard case .error(let errorMessage) = wrongArgResult else {
            Issue.record("SUBSTRING with wrong args should produce error, but got: \(wrongArgResult)")
            return
        }
        #expect(errorMessage.contains("three arguments"), "Should report argument count error")

        // Test SUBSTRING with non-string first argument
        let wrongTypeExpr = ZILExpression.list([
            .atom("SUBSTRING", location),
            .number(123, location),     // Not a string
            .number(1, location),
            .number(3, location)
        ], location)

        let wrongTypeResult = processor.evaluateExpression(wrongTypeExpr)
        guard case .error(let typeErrorMessage) = wrongTypeResult else {
            Issue.record("SUBSTRING with wrong type should produce error, but got: \(wrongTypeResult)")
            return
        }
        #expect(typeErrorMessage.contains("must be a string"), "Should report type error")

        // Test SUBSTRING with out of bounds
        let outOfBoundsExpr = ZILExpression.list([
            .atom("SUBSTRING", location),
            .string("Hi", location),
            .number(10, location),      // Start beyond string length
            .number(3, location)
        ], location)

        let outOfBoundsResult = processor.evaluateExpression(outOfBoundsExpr)
        guard case .error(let boundsErrorMessage) = outOfBoundsResult else {
            Issue.record("SUBSTRING out of bounds should produce error, but got: \(outOfBoundsResult)")
            return
        }
        #expect(boundsErrorMessage.contains("out of bounds"), "Should report bounds error")

        // Test STRING-CONCAT with empty arguments
        let emptyArgsExpr = ZILExpression.list([
            .atom("STRING-CONCAT", location)  // No arguments
        ], location)

        let emptyArgsResult = processor.evaluateExpression(emptyArgsExpr)
        guard case .error(let emptyErrorMessage) = emptyArgsResult else {
            Issue.record("STRING-CONCAT with no args should produce error, but got: \(emptyArgsResult)")
            return
        }
        #expect(emptyErrorMessage.contains("at least one argument"), "Should report missing arguments error")

        // Test STRING-LENGTH with non-string argument
        let lengthWrongTypeExpr = ZILExpression.list([
            .atom("STRING-LENGTH", location),
            .number(42, location)  // Not a string
        ], location)

        let lengthWrongTypeResult = processor.evaluateExpression(lengthWrongTypeExpr)
        guard case .error(let lengthTypeErrorMessage) = lengthWrongTypeResult else {
            Issue.record("STRING-LENGTH with wrong type should produce error, but got: \(lengthWrongTypeResult)")
            return
        }
        #expect(lengthTypeErrorMessage.contains("must be a string"), "Should report type error for STRING-LENGTH")
    }

    @Test("String operations in macro expansion")
    func stringOperationsInMacroExpansion() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define a macro that uses EVAL with string operations at compile time
        // MAKE-GREETING(NAME) -> <EVAL <STRING-CONCAT "Hello, " .NAME "!">>
        let macroBody = ZILExpression.list([
            .atom("EVAL", location),
            .list([
                .atom("STRING-CONCAT", location),
                .string("Hello, ", location),
                .localVariable("NAME", location),
                .string("!", location)
            ], location)
        ], location)

        _ = processor.defineMacro(
            name: "MAKE-GREETING",
            parameters: [.standard("NAME")],
            body: macroBody,
            at: location
        )

        // Expand the macro with a string argument
        let result = processor.expandMacro(
            name: "MAKE-GREETING",
            arguments: [.string("ZIL", location)],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("String macro should expand successfully, but got: \(result)")
            return
        }

        // Should evaluate to the concatenated string at compile time
        guard case .string(let greeting, _) = expanded else {
            Issue.record("String macro result should be a string, but got: \(expanded)")
            return
        }
        #expect(greeting == "Hello, ZIL!", "MAKE-GREETING should evaluate string concatenation at compile time")

        // Test macro with string operations and uppercase conversion
        // MAKE-LOUD-NAME(NAME) -> <EVAL <STRING-UPPER <STRING-CONCAT .NAME " SAYS HELLO">>>
        let loudMacroBody = ZILExpression.list([
            .atom("EVAL", location),
            .list([
                .atom("STRING-UPPER", location),
                .list([
                    .atom("STRING-CONCAT", location),
                    .localVariable("NAME", location),
                    .string(" SAYS HELLO", location)
                ], location)
            ], location)
        ], location)

        _ = processor.defineMacro(
            name: "MAKE-LOUD-NAME",
            parameters: [.standard("NAME")],
            body: loudMacroBody,
            at: location
        )

        let loudResult = processor.expandMacro(
            name: "MAKE-LOUD-NAME",
            arguments: [.string("bob", location)],
            at: location
        )

        guard case .success(let loudExpanded) = loudResult else {
            Issue.record("Loud name macro should expand successfully, but got: \(loudResult)")
            return
        }

        guard case .string(let loudGreeting, _) = loudExpanded else {
            Issue.record("Loud name macro result should be a string, but got: \(loudExpanded)")
            return
        }
        #expect(loudGreeting == "BOB SAYS HELLO", "MAKE-LOUD-NAME should evaluate nested string operations")

        // Test macro with string length calculation
        // CHECK-NAME-LENGTH(NAME) -> <EVAL <> <STRING-LENGTH .NAME> 5>>
        let lengthCheckBody = ZILExpression.list([
            .atom("EVAL", location),
            .list([
                .atom(">", location),
                .list([
                    .atom("STRING-LENGTH", location),
                    .localVariable("NAME", location)
                ], location),
                .number(5, location)
            ], location)
        ], location)

        _ = processor.defineMacro(
            name: "CHECK-NAME-LENGTH",
            parameters: [.standard("NAME")],
            body: lengthCheckBody,
            at: location
        )

        // Test with short name
        let shortNameResult = processor.expandMacro(
            name: "CHECK-NAME-LENGTH",
            arguments: [.string("Bob", location)],
            at: location
        )

        guard case .success(let shortExpanded) = shortNameResult else {
            Issue.record("Name length check should expand successfully, but got: \(shortNameResult)")
            return
        }

        guard case .number(let shortResult, _) = shortExpanded else {
            Issue.record("Name length check should return a number, but got: \(shortExpanded)")
            return
        }
        #expect(shortResult == 0, "Short name should return false (0)")

        // Test with long name
        let longNameResult = processor.expandMacro(
            name: "CHECK-NAME-LENGTH",
            arguments: [.string("Alexander", location)],
            at: location
        )

        guard case .success(let longExpanded) = longNameResult else {
            Issue.record("Long name check should expand successfully, but got: \(longNameResult)")
            return
        }

        guard case .number(let longResult, _) = longExpanded else {
            Issue.record("Long name check should return a number, but got: \(longExpanded)")
            return
        }
        #expect(longResult == 1, "Long name should return true (1)")
    }
}