import Foundation

/// Represents the result of compile-time evaluation
public enum EvaluationResult: Sendable, Equatable {
    case success(ZILExpression)
    case error(String)
    case notEvaluable  // Expression cannot be evaluated at compile time
}

/// Evaluates ZIL expressions at compile time during macro expansion
///
/// This enables macros to perform computations, conditionals, and other operations
/// during the compilation phase, allowing for more powerful macro programming.
public struct CompileTimeEvaluator: Sendable {

    /// Context for compile-time evaluation
    private let constants: [String: ZILExpression]

    public init(constants: [String: ZILExpression] = [:]) {
        self.constants = constants
    }

    /// Evaluate a ZIL expression at compile time
    ///
    /// - Parameter expression: The expression to evaluate
    /// - Returns: EvaluationResult containing the result or error
    public func evaluate(_ expression: ZILExpression) -> EvaluationResult {
        switch expression {
        case .number(_, _), .string(_, _):
            // Literals evaluate to themselves
            return .success(expression)

        case .atom(let name, let location):
            // Look up constants
            if let constantValue = constants[name] {
                return .success(constantValue)
            }
            // Non-constant atoms cannot be evaluated at compile time
            return .notEvaluable

        case .list(let elements, let location):
            guard let firstElement = elements.first else {
                // Empty list is a valid literal
                return .success(expression)
            }

            guard case .atom(let operation, _) = firstElement else {
                // This is a data list (not a function call), so it's a literal value
                return .success(expression)
            }

            let arguments = Array(elements.dropFirst())

            switch operation.uppercased() {
            case "+":
                return evaluateArithmetic(operation: .add, arguments: arguments, at: location)
            case "-":
                return evaluateArithmetic(operation: .subtract, arguments: arguments, at: location)
            case "*":
                return evaluateArithmetic(operation: .multiply, arguments: arguments, at: location)
            case "/":
                return evaluateArithmetic(operation: .divide, arguments: arguments, at: location)
            case "=":
                return evaluateComparison(operation: .equal, arguments: arguments, at: location)
            case "<":
                return evaluateComparison(operation: .lessThan, arguments: arguments, at: location)
            case ">":
                return evaluateComparison(operation: .greaterThan, arguments: arguments, at: location)
            case "<=":
                return evaluateComparison(operation: .lessThanOrEqual, arguments: arguments, at: location)
            case ">=":
                return evaluateComparison(operation: .greaterThanOrEqual, arguments: arguments, at: location)
            case "AND":
                return evaluateLogical(operation: .and, arguments: arguments, at: location)
            case "OR":
                return evaluateLogical(operation: .or, arguments: arguments, at: location)
            case "NOT":
                return evaluateLogical(operation: .not, arguments: arguments, at: location)
            case "COND":
                return evaluateCond(arguments: arguments, at: location)
            case "IF":
                return evaluateIf(arguments: arguments, at: location)
            case "LENGTH":
                return evaluateLength(arguments: arguments, at: location)
            case "NTH":
                return evaluateNth(arguments: arguments, at: location)
            case "REST":
                return evaluateRest(arguments: arguments, at: location)
            case "SUBSTRING":
                return evaluateSubstring(arguments: arguments, at: location)
            case "STRING-CONCAT":
                return evaluateStringConcat(arguments: arguments, at: location)
            case "STRING-LENGTH":
                return evaluateStringLength(arguments: arguments, at: location)
            case "STRING-UPPER":
                return evaluateStringUpper(arguments: arguments, at: location)
            case "STRING-LOWER":
                return evaluateStringLower(arguments: arguments, at: location)
            case "STRING-INDEX":
                return evaluateStringIndex(arguments: arguments, at: location)
            default:
                // Unknown operation cannot be evaluated at compile time
                return .notEvaluable
            }

        default:
            // Other expression types cannot be evaluated at compile time
            return .notEvaluable
        }
    }

    // MARK: - Private Evaluation Methods

    private enum ArithmeticOperation {
        case add, subtract, multiply, divide
    }

    private func evaluateArithmetic(
        operation: ArithmeticOperation,
        arguments: [ZILExpression],
        at location: SourceLocation
    ) -> EvaluationResult {
        guard !arguments.isEmpty else {
            return .error("Arithmetic operation requires at least one argument")
        }

        // Evaluate all arguments to numbers
        var values: [Int16] = []
        for arg in arguments {
            let result = evaluate(arg)
            switch result {
            case .success(let expr):
                guard case .number(let value, _) = expr else {
                    return .error("Arithmetic operation requires numeric arguments")
                }
                values.append(value)
            case .error(let message):
                return .error(message)
            case .notEvaluable:
                return .notEvaluable
            }
        }

        // Perform the operation
        var result = values[0]
        for i in 1..<values.count {
            switch operation {
            case .add:
                result = result &+ values[i]  // Use wrapping arithmetic
            case .subtract:
                result = result &- values[i]
            case .multiply:
                result = result &* values[i]
            case .divide:
                if values[i] == 0 {
                    return .error("Division by zero")
                }
                result = result / values[i]
            }
        }

        return .success(.number(result, location))
    }

    private enum ComparisonOperation {
        case equal, lessThan, greaterThan, lessThanOrEqual, greaterThanOrEqual
    }

    private func evaluateComparison(
        operation: ComparisonOperation,
        arguments: [ZILExpression],
        at location: SourceLocation
    ) -> EvaluationResult {
        guard arguments.count == 2 else {
            return .error("Comparison operation requires exactly two arguments")
        }

        // Evaluate both arguments
        let leftResult = evaluate(arguments[0])
        let rightResult = evaluate(arguments[1])

        switch (leftResult, rightResult) {
        case (.success(let left), .success(let right)):
            // Compare the values
            let comparison = compareExpressions(left, right)
            switch comparison {
            case .equal:
                let result = (operation == .equal || operation == .lessThanOrEqual || operation == .greaterThanOrEqual)
                return .success(.number(result ? 1 : 0, location))
            case .lessThan:
                let result = (operation == .lessThan || operation == .lessThanOrEqual)
                return .success(.number(result ? 1 : 0, location))
            case .greaterThan:
                let result = (operation == .greaterThan || operation == .greaterThanOrEqual)
                return .success(.number(result ? 1 : 0, location))
            case .notComparable:
                return .error("Cannot compare incompatible types")
            }
        case (.error(let message), _), (_, .error(let message)):
            return .error(message)
        default:
            return .notEvaluable
        }
    }

    private enum ComparisonResult {
        case equal, lessThan, greaterThan, notComparable
    }

    private func compareExpressions(_ left: ZILExpression, _ right: ZILExpression) -> ComparisonResult {
        switch (left, right) {
        case (.number(let a, _), .number(let b, _)):
            if a == b { return .equal }
            else if a < b { return .lessThan }
            else { return .greaterThan }
        case (.string(let a, _), .string(let b, _)):
            if a == b { return .equal }
            else if a < b { return .lessThan }
            else { return .greaterThan }
        case (.atom(let a, _), .atom(let b, _)):
            if a == b { return .equal }
            else if a < b { return .lessThan }
            else { return .greaterThan }
        default:
            return .notComparable
        }
    }

    private enum LogicalOperation {
        case and, or, not
    }

    private func evaluateLogical(
        operation: LogicalOperation,
        arguments: [ZILExpression],
        at location: SourceLocation
    ) -> EvaluationResult {
        switch operation {
        case .not:
            guard arguments.count == 1 else {
                return .error("NOT operation requires exactly one argument")
            }
            let result = evaluate(arguments[0])
            switch result {
            case .success(let expr):
                let isTruthy = isExpressionTruthy(expr)
                return .success(.number(isTruthy ? 0 : 1, location))
            case .error(let message):
                return .error(message)
            case .notEvaluable:
                return .notEvaluable
            }

        case .and:
            guard !arguments.isEmpty else {
                return .error("AND operation requires at least one argument")
            }
            // Short-circuit evaluation
            for arg in arguments {
                let result = evaluate(arg)
                switch result {
                case .success(let expr):
                    if !isExpressionTruthy(expr) {
                        return .success(.number(0, location))
                    }
                case .error(let message):
                    return .error(message)
                case .notEvaluable:
                    return .notEvaluable
                }
            }
            return .success(.number(1, location))

        case .or:
            guard !arguments.isEmpty else {
                return .error("OR operation requires at least one argument")
            }
            // Short-circuit evaluation
            for arg in arguments {
                let result = evaluate(arg)
                switch result {
                case .success(let expr):
                    if isExpressionTruthy(expr) {
                        return .success(.number(1, location))
                    }
                case .error(let message):
                    return .error(message)
                case .notEvaluable:
                    return .notEvaluable
                }
            }
            return .success(.number(0, location))
        }
    }

    private func isExpressionTruthy(_ expression: ZILExpression) -> Bool {
        switch expression {
        case .number(let value, _):
            return value != 0
        case .string(let value, _):
            return !value.isEmpty
        case .atom(let value, _):
            return !value.isEmpty && value.uppercased() != "FALSE"
        case .list(let elements, _):
            return !elements.isEmpty
        default:
            return true
        }
    }

    private func evaluateCond(arguments: [ZILExpression], at location: SourceLocation) -> EvaluationResult {
        guard arguments.count % 2 == 0 else {
            return .error("COND requires an even number of arguments (condition-result pairs)")
        }

        for i in stride(from: 0, to: arguments.count, by: 2) {
            let condition = arguments[i]
            let result = arguments[i + 1]

            let conditionResult = evaluate(condition)
            switch conditionResult {
            case .success(let expr):
                if isExpressionTruthy(expr) {
                    return evaluate(result)
                }
            case .error(let message):
                return .error(message)
            case .notEvaluable:
                return .notEvaluable
            }
        }

        // No condition matched - return false/0
        return .success(.number(0, location))
    }

    private func evaluateIf(arguments: [ZILExpression], at location: SourceLocation) -> EvaluationResult {
        guard arguments.count == 2 || arguments.count == 3 else {
            return .error("IF requires 2 or 3 arguments (condition, then-expr, [else-expr])")
        }

        let condition = arguments[0]
        let thenExpr = arguments[1]
        let elseExpr = arguments.count > 2 ? arguments[2] : ZILExpression.number(0, location)

        let conditionResult = evaluate(condition)
        switch conditionResult {
        case .success(let expr):
            if isExpressionTruthy(expr) {
                return evaluate(thenExpr)
            } else {
                return evaluate(elseExpr)
            }
        case .error(let message):
            return .error(message)
        case .notEvaluable:
            return .notEvaluable
        }
    }

    private func evaluateLength(arguments: [ZILExpression], at location: SourceLocation) -> EvaluationResult {
        guard arguments.count == 1 else {
            return .error("LENGTH requires exactly one argument")
        }

        let result = evaluate(arguments[0])
        switch result {
        case .success(let expr):
            switch expr {
            case .list(let elements, _):
                return .success(.number(Int16(elements.count), location))
            case .string(let value, _):
                return .success(.number(Int16(value.count), location))
            default:
                return .error("LENGTH can only be applied to lists or strings")
            }
        case .error(let message):
            return .error(message)
        case .notEvaluable:
            return .notEvaluable
        }
    }

    private func evaluateNth(arguments: [ZILExpression], at location: SourceLocation) -> EvaluationResult {
        guard arguments.count == 2 else {
            return .error("NTH requires exactly two arguments (index, list)")
        }

        let indexResult = evaluate(arguments[0])
        let listResult = evaluate(arguments[1])

        switch (indexResult, listResult) {
        case (.success(let indexExpr), .success(let listExpr)):
            guard case .number(let index, _) = indexExpr else {
                return .error("NTH index must be a number")
            }
            guard case .list(let elements, _) = listExpr else {
                return .error("NTH second argument must be a list")
            }

            let i = Int(index) - 1  // ZIL uses 1-based indexing
            if i >= 0 && i < elements.count {
                return .success(elements[i])
            } else {
                return .error("NTH index out of bounds")
            }
        case (.error(let message), _), (_, .error(let message)):
            return .error(message)
        default:
            return .notEvaluable
        }
    }

    private func evaluateRest(arguments: [ZILExpression], at location: SourceLocation) -> EvaluationResult {
        guard arguments.count == 1 else {
            return .error("REST requires exactly one argument")
        }

        let result = evaluate(arguments[0])
        switch result {
        case .success(let expr):
            guard case .list(let elements, _) = expr else {
                return .error("REST can only be applied to lists")
            }

            if elements.isEmpty {
                return .success(.list([], location))
            } else {
                return .success(.list(Array(elements.dropFirst()), location))
            }
        case .error(let message):
            return .error(message)
        case .notEvaluable:
            return .notEvaluable
        }
    }

    private func evaluateSubstring(arguments: [ZILExpression], at location: SourceLocation) -> EvaluationResult {
        guard arguments.count == 3 else {
            return .error("SUBSTRING requires exactly three arguments (string, start, length)")
        }

        let stringResult = evaluate(arguments[0])
        let startResult = evaluate(arguments[1])
        let lengthResult = evaluate(arguments[2])

        switch (stringResult, startResult, lengthResult) {
        case (.success(let stringExpr), .success(let startExpr), .success(let lengthExpr)):
            guard case .string(let string, _) = stringExpr else {
                return .error("SUBSTRING first argument must be a string")
            }
            guard case .number(let start, _) = startExpr else {
                return .error("SUBSTRING second argument must be a number")
            }
            guard case .number(let length, _) = lengthExpr else {
                return .error("SUBSTRING third argument must be a number")
            }

            if let substring = StringProcessor.substring(string, start: Int(start), length: Int(length)) {
                return .success(.string(substring, location))
            } else {
                return .error("SUBSTRING index out of bounds")
            }
        case (.error(let message), _, _), (_, .error(let message), _), (_, _, .error(let message)):
            return .error(message)
        default:
            return .notEvaluable
        }
    }

    private func evaluateStringConcat(arguments: [ZILExpression], at location: SourceLocation) -> EvaluationResult {
        guard !arguments.isEmpty else {
            return .error("STRING-CONCAT requires at least one argument")
        }

        var strings: [String] = []
        for arg in arguments {
            let result = evaluate(arg)
            switch result {
            case .success(let expr):
                guard case .string(let string, _) = expr else {
                    return .error("STRING-CONCAT arguments must be strings")
                }
                strings.append(string)
            case .error(let message):
                return .error(message)
            case .notEvaluable:
                return .notEvaluable
            }
        }

        let concatenated = StringProcessor.concatenate(strings)
        return .success(.string(concatenated, location))
    }

    private func evaluateStringLength(arguments: [ZILExpression], at location: SourceLocation) -> EvaluationResult {
        guard arguments.count == 1 else {
            return .error("STRING-LENGTH requires exactly one argument")
        }

        let result = evaluate(arguments[0])
        switch result {
        case .success(let expr):
            guard case .string(let string, _) = expr else {
                return .error("STRING-LENGTH argument must be a string")
            }
            let length = StringProcessor.length(string)
            return .success(.number(Int16(length), location))
        case .error(let message):
            return .error(message)
        case .notEvaluable:
            return .notEvaluable
        }
    }

    private func evaluateStringUpper(arguments: [ZILExpression], at location: SourceLocation) -> EvaluationResult {
        guard arguments.count == 1 else {
            return .error("STRING-UPPER requires exactly one argument")
        }

        let result = evaluate(arguments[0])
        switch result {
        case .success(let expr):
            guard case .string(let string, _) = expr else {
                return .error("STRING-UPPER argument must be a string")
            }
            let uppercased = StringProcessor.uppercase(string)
            return .success(.string(uppercased, location))
        case .error(let message):
            return .error(message)
        case .notEvaluable:
            return .notEvaluable
        }
    }

    private func evaluateStringLower(arguments: [ZILExpression], at location: SourceLocation) -> EvaluationResult {
        guard arguments.count == 1 else {
            return .error("STRING-LOWER requires exactly one argument")
        }

        let result = evaluate(arguments[0])
        switch result {
        case .success(let expr):
            guard case .string(let string, _) = expr else {
                return .error("STRING-LOWER argument must be a string")
            }
            let lowercased = StringProcessor.lowercase(string)
            return .success(.string(lowercased, location))
        case .error(let message):
            return .error(message)
        case .notEvaluable:
            return .notEvaluable
        }
    }

    private func evaluateStringIndex(arguments: [ZILExpression], at location: SourceLocation) -> EvaluationResult {
        guard arguments.count == 2 else {
            return .error("STRING-INDEX requires exactly two arguments (string, substring)")
        }

        let stringResult = evaluate(arguments[0])
        let substringResult = evaluate(arguments[1])

        switch (stringResult, substringResult) {
        case (.success(let stringExpr), .success(let substringExpr)):
            guard case .string(let string, _) = stringExpr else {
                return .error("STRING-INDEX first argument must be a string")
            }
            guard case .string(let substring, _) = substringExpr else {
                return .error("STRING-INDEX second argument must be a string")
            }

            let index = StringProcessor.indexOf(string, substring: substring)
            return .success(.number(Int16(index), location))
        case (.error(let message), _), (_, .error(let message)):
            return .error(message)
        default:
            return .notEvaluable
        }
    }
}