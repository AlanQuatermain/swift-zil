import Foundation

/// Represents the result of FORM construction
public enum FormResult: Sendable, Equatable {
    case success(ZILExpression)
    case error(String)
}

/// Core system for dynamic ZILExpression construction during macro expansion
///
/// The FORM construct in ZIL allows macros to generate code dynamically at compile time.
/// For example: `<FORM PUT .INT ,C-ENABLED? 1>` builds a PUT expression with substituted parameters.
public struct FormBuilder: Sendable {

    /// Build a ZIL expression from a FORM construct
    ///
    /// FORM syntax: `<FORM operation arg1 arg2 ...>`
    /// This takes the operation and arguments and constructs a new ZILExpression list.
    ///
    /// - Parameters:
    ///   - formExpression: The FORM expression to evaluate
    ///   - substitutions: Parameter substitutions from macro expansion
    ///   - location: Source location for the constructed expression
    /// - Returns: FormResult containing the built expression or error
    public static func buildForm(
        _ formExpression: ZILExpression,
        substitutions: [String: ZILExpression],
        at location: SourceLocation
    ) -> FormResult {
        guard case .list(let elements, _) = formExpression else {
            return .error("FORM must be a list expression")
        }

        guard elements.count >= 2 else {
            return .error("FORM requires at least operation and one argument")
        }

        guard case .atom("FORM", _) = elements[0] else {
            return .error("Expression must start with FORM")
        }

        // Extract the operation and arguments
        let operation = elements[1]
        let arguments = Array(elements.dropFirst(2))

        // Apply substitutions to all elements
        let substitutedOperation = applySubstitutions(operation, substitutions: substitutions)
        let substitutedArguments = arguments.map { arg in
            applySubstitutions(arg, substitutions: substitutions)
        }

        // Build the new expression: (operation arg1 arg2 ...)
        var resultElements = [substitutedOperation]
        resultElements.append(contentsOf: substitutedArguments)

        let result = ZILExpression.list(resultElements, location)
        return .success(result)
    }

    /// Apply parameter substitutions to a ZIL expression recursively
    ///
    /// This handles the `.PARAM` and `,GLOBAL` syntax used in FORM expressions.
    ///
    /// - Parameters:
    ///   - expression: The expression to apply substitutions to
    ///   - substitutions: The substitution map
    /// - Returns: The expression with substitutions applied
    public static func applySubstitutions(
        _ expression: ZILExpression,
        substitutions: [String: ZILExpression]
    ) -> ZILExpression {
        switch expression {
        case .atom(let name, _):
            // Direct parameter substitution for atoms
            return substitutions[name] ?? expression

        case .localVariable(let name, _):
            // Local variables (.PARAM) can be substituted
            return substitutions[name] ?? expression

        case .globalVariable(_, _):
            // Global variables (,GLOBAL) are preserved as-is
            return expression

        case .list(let elements, let location):
            // Recursively apply substitutions to list elements
            let substitutedElements = elements.map { element in
                applySubstitutions(element, substitutions: substitutions)
            }
            return .list(substitutedElements, location)

        case .table(let tableType, let elements, let location):
            // Apply substitutions to table elements
            let substitutedElements = elements.map { element in
                applySubstitutions(element, substitutions: substitutions)
            }
            return .table(tableType, substitutedElements, location)

        case .indirection(let targetExpression, let location):
            // Apply substitutions to indirection target
            let substitutedTarget = applySubstitutions(targetExpression, substitutions: substitutions)
            return .indirection(substitutedTarget, location)

        default:
            // Other expression types (numbers, strings, etc.) are returned as-is
            return expression
        }
    }

    /// Check if an expression is a FORM construct
    ///
    /// - Parameter expression: The expression to check
    /// - Returns: True if this is a FORM expression
    public static func isFormExpression(_ expression: ZILExpression) -> Bool {
        guard case .list(let elements, _) = expression else {
            return false
        }

        guard let firstElement = elements.first else {
            return false
        }

        guard case .atom("FORM", _) = firstElement else {
            return false
        }

        return true
    }

    /// Validate a FORM expression structure
    ///
    /// - Parameter expression: The FORM expression to validate
    /// - Returns: Validation result with detailed error message if invalid
    public static func validateFormExpression(_ expression: ZILExpression) -> FormResult {
        guard case .list(let elements, _) = expression else {
            return .error("FORM must be a list expression")
        }

        guard elements.count >= 2 else {
            return .error("FORM requires at least FORM keyword and operation")
        }

        guard case .atom("FORM", _) = elements[0] else {
            return .error("First element must be FORM atom")
        }

        // Validate that the operation is a valid atom or expression
        let operation = elements[1]
        switch operation {
        case .atom(_, _):
            // Valid operation atom
            break
        case .localVariable(_, _), .globalVariable(_, _):
            // Variables that will be substituted are also valid
            break
        default:
            return .error("FORM operation must be an atom or variable reference")
        }

        // The expression is structurally valid
        return .success(expression)
    }

    /// Build a FORM expression from components
    ///
    /// This is a convenience method for constructing FORM expressions programmatically.
    ///
    /// - Parameters:
    ///   - operation: The operation atom or expression
    ///   - arguments: The arguments to the operation
    ///   - location: Source location for the constructed FORM
    /// - Returns: A properly structured FORM expression
    public static func createFormExpression(
        operation: ZILExpression,
        arguments: [ZILExpression],
        at location: SourceLocation
    ) -> ZILExpression {
        var elements = [ZILExpression.atom("FORM", location)]
        elements.append(operation)
        elements.append(contentsOf: arguments)

        return ZILExpression.list(elements, location)
    }
}