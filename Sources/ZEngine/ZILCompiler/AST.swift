import Foundation

/// Protocol for all ZIL Abstract Syntax Tree nodes.
///
/// All AST nodes conform to this protocol, enabling uniform traversal
/// and transformation operations across the syntax tree.
public protocol ZILNode: Sendable {
    /// Source location where this node originated
    var location: SourceLocation { get }
}

/// ZIL expression types representing values and computations.
///
/// Expressions are the core building blocks of ZIL code, representing
/// everything from literal values to complex function calls and variable references.
public indirect enum ZILExpression: Sendable, Equatable {
    /// Atomic identifier (e.g., `HELLO`, `WINNER`)
    case atom(String, SourceLocation)

    /// Numeric literal (e.g., `123`, `$FF`, `%77`)
    case number(Int16, SourceLocation)

    /// String literal (e.g., `"Hello, World!"`)
    case string(String, SourceLocation)

    /// Global variable reference (e.g., `,WINNER`, `,SCORE`)
    case globalVariable(String, SourceLocation)

    /// Local variable reference (e.g., `.VAL`, `.TEMP`)
    case localVariable(String, SourceLocation)

    /// Property reference (e.g., `P?DESC`, `P?ACTION`)
    case propertyReference(String, SourceLocation)

    /// Flag reference (e.g., `F?TAKEBIT`, `F?LIGHTBIT`)
    case flagReference(String, SourceLocation)

    /// List expression - S-expression with multiple elements (e.g., `<TELL "Hello">`)
    case list([ZILExpression], SourceLocation)

    /// Table literal - array/table initialization (e.g., `<ITABLE 10 5 2>`, `<LTABLE "STR1" "STR2">`)
    case table(ZILTableType, [ZILExpression], SourceLocation)

    /// Indirection expression - runtime dereference (e.g., `!ATOM`, `!,GLOBAL`)
    case indirection(ZILExpression, SourceLocation)
}

/// ZIL table types for different kinds of table literals.
///
/// ZIL supports various table types with different storage characteristics
/// and initialization patterns.
public enum ZILTableType: Sendable, Equatable {
    /// ITABLE - Integer table with initial values
    case itable

    /// LTABLE - Length-prefixed table
    case ltable

    /// TABLE - Basic table without length prefix
    case table

    /// PTABLE - Property table
    case ptable

    /// BTABLE - Byte table for character data
    case btable
}

/// ZIL declaration types representing top-level definitions.
///
/// Declarations define the structure and behavior of ZIL programs,
/// including routines, objects, global variables, and other top-level constructs.
public enum ZILDeclaration: Sendable, Equatable {
    /// Routine definition with parameters and body
    case routine(ZILRoutineDeclaration)

    /// Object definition with properties and flags
    case object(ZILObjectDeclaration)

    /// Global variable assignment
    case global(ZILGlobalDeclaration)

    /// Property definition
    case property(ZILPropertyDeclaration)

    /// Constant definition
    case constant(ZILConstantDeclaration)

    /// File insertion directive
    case insertFile(ZILInsertFileDeclaration)

    /// Version specification
    case version(ZILVersionDeclaration)

    /// Compile-time print directive
    case princ(ZILPrincDeclaration)

    /// Story name directive
    case sname(ZILSnameDeclaration)

    /// Compile-time variable assignment
    case set(ZILSetDeclaration)

    /// Direction definitions directive
    case directions(ZILDirectionsDeclaration)

    /// Parser syntax rule definition
    case syntax(ZILSyntaxDeclaration)

    /// Word synonym definition
    case synonym(ZILSynonymDeclaration)

    /// Macro definition
    case defmac(ZILDefmacDeclaration)

    /// Buzzword definition (ignored words)
    case buzz(ZILBuzzDeclaration)
}

/// Parameter with optional default value.
///
/// Used for routine parameters that may have default values.
public struct ZILParameter: Sendable, Equatable {
    /// Parameter name
    public let name: String

    /// Default value (nil for required parameters)
    public let defaultValue: ZILExpression?

    /// Source location of the parameter
    public let location: SourceLocation

    public init(name: String, defaultValue: ZILExpression? = nil, location: SourceLocation) {
        self.name = name
        self.defaultValue = defaultValue
        self.location = location
    }
}

/// Macro parameter types for DEFMAC declarations.
///
/// ZIL macros support various parameter patterns including variable arguments,
/// quoted parameters, and optional parameters.
public enum ZILMacroParameter: Sendable, Equatable {
    /// Standard parameter name
    case standard(String)

    /// Variable arguments parameter ("ARGS" paramName)
    case variableArgs(String)

    /// Quoted parameter ('paramName)
    case quoted(String)

    /// Optional parameter ("OPTIONAL" paramName)
    case optional(String, ZILExpression?)

    /// Get the parameter name regardless of type
    public var name: String {
        switch self {
        case .standard(let name), .variableArgs(let name), .quoted(let name):
            return name
        case .optional(let name, _):
            return name
        }
    }

    /// Check if this parameter accepts multiple arguments
    public var isVariadic: Bool {
        if case .variableArgs = self {
            return true
        }
        return false
    }
}

/// Routine definition structure.
///
/// Represents ZIL routine definitions with parameters, optional parameters,
/// auxiliary variables, and the routine body.
public struct ZILRoutineDeclaration: Sendable, Equatable {
    /// Routine name
    public let name: String

    /// Required parameters
    public let parameters: [String]

    /// Optional parameters with default values (marked with "OPT")
    public let optionalParameters: [ZILParameter]

    /// Auxiliary variables with optional default values (marked with "AUX")
    public let auxiliaryVariables: [ZILParameter]

    /// Routine body expressions
    public let body: [ZILExpression]

    /// Source location of the routine declaration
    public let location: SourceLocation

    public init(name: String, parameters: [String] = [], optionalParameters: [ZILParameter] = [], auxiliaryVariables: [ZILParameter] = [], body: [ZILExpression], location: SourceLocation) {
        self.name = name
        self.parameters = parameters
        self.optionalParameters = optionalParameters
        self.auxiliaryVariables = auxiliaryVariables
        self.body = body
        self.location = location
    }
}

/// Object definition structure.
///
/// Represents ZIL object definitions with properties, flags, and hierarchical relationships.
public struct ZILObjectDeclaration: Sendable, Equatable {
    /// Object name
    public let name: String

    /// Object properties as key-value pairs
    public let properties: [ZILObjectProperty]

    /// Source location of the object declaration
    public let location: SourceLocation

    public init(name: String, properties: [ZILObjectProperty], location: SourceLocation) {
        self.name = name
        self.properties = properties
        self.location = location
    }
}

/// Object property representation.
///
/// Represents individual properties within object definitions,
/// such as DESC, FLAGS, IN, etc.
public struct ZILObjectProperty: Sendable, Equatable {
    /// Property name (e.g., "DESC", "FLAGS", "IN")
    public let name: String

    /// Property value expression
    public let value: ZILExpression

    /// Source location of the property
    public let location: SourceLocation

    public init(name: String, value: ZILExpression, location: SourceLocation) {
        self.name = name
        self.value = value
        self.location = location
    }
}

/// Global variable declaration.
///
/// Represents global variable assignments using SETG or GLOBAL.
public struct ZILGlobalDeclaration: Sendable, Equatable {
    /// Variable name
    public let name: String

    /// Initial value expression
    public let value: ZILExpression

    /// Source location of the declaration
    public let location: SourceLocation

    public init(name: String, value: ZILExpression, location: SourceLocation) {
        self.name = name
        self.value = value
        self.location = location
    }
}

/// Property definition declaration.
///
/// Represents PROPDEF statements that define object property types.
public struct ZILPropertyDeclaration: Sendable, Equatable {
    /// Property name
    public let name: String

    /// Default value expression
    public let defaultValue: ZILExpression

    /// Source location of the declaration
    public let location: SourceLocation

    public init(name: String, defaultValue: ZILExpression, location: SourceLocation) {
        self.name = name
        self.defaultValue = defaultValue
        self.location = location
    }
}

/// Constant definition declaration.
///
/// Represents CONSTANT statements for compile-time constants.
public struct ZILConstantDeclaration: Sendable, Equatable {
    /// Constant name
    public let name: String

    /// Constant value expression
    public let value: ZILExpression

    /// Source location of the declaration
    public let location: SourceLocation

    public init(name: String, value: ZILExpression, location: SourceLocation) {
        self.name = name
        self.value = value
        self.location = location
    }
}

/// File insertion declaration.
///
/// Represents INSERT-FILE directives for including other ZIL files.
public struct ZILInsertFileDeclaration: Sendable, Equatable {
    /// File name to insert
    public let filename: String

    /// Whether to insert with T flag
    public let withTFlag: Bool

    /// Source location of the declaration
    public let location: SourceLocation

    public init(filename: String, withTFlag: Bool = false, location: SourceLocation) {
        self.filename = filename
        self.withTFlag = withTFlag
        self.location = location
    }
}

/// Version specification declaration.
///
/// Represents VERSION directives specifying the target Z-Machine version.
public struct ZILVersionDeclaration: Sendable, Equatable {
    /// Version type (e.g., "ZIP", "EZIP")
    public let version: String

    /// Source location of the declaration
    public let location: SourceLocation

    public init(version: String, location: SourceLocation) {
        self.version = version
        self.location = location
    }
}

/// Compile-time print directive declaration.
///
/// The PRINC directive outputs text during compilation for debugging
/// and informational purposes.
public struct ZILPrincDeclaration: Sendable, Equatable {
    /// The text or expression to print
    public let text: ZILExpression
    /// Source location of the declaration
    public let location: SourceLocation

    public init(text: ZILExpression, location: SourceLocation) {
        self.text = text
        self.location = location
    }
}

/// Story name directive declaration.
///
/// The SNAME directive sets the internal name of the story file.
public struct ZILSnameDeclaration: Sendable, Equatable {
    /// The story name
    public let name: String
    /// Source location of the declaration
    public let location: SourceLocation

    public init(name: String, location: SourceLocation) {
        self.name = name
        self.location = location
    }
}

/// Compile-time variable assignment directive declaration.
///
/// The SET directive assigns values to compile-time variables during compilation.
public struct ZILSetDeclaration: Sendable, Equatable {
    /// The variable name
    public let name: String
    /// The value to assign
    public let value: ZILExpression
    /// Source location of the declaration
    public let location: SourceLocation

    public init(name: String, value: ZILExpression, location: SourceLocation) {
        self.name = name
        self.value = value
        self.location = location
    }
}

/// Direction definitions directive declaration.
///
/// The DIRECTIONS directive defines the standard movement directions for the game.
public struct ZILDirectionsDeclaration: Sendable, Equatable {
    /// List of direction atoms
    public let directions: [String]
    /// Source location of the declaration
    public let location: SourceLocation

    public init(directions: [String], location: SourceLocation) {
        self.directions = directions
        self.location = location
    }
}

/// Parser syntax rule declaration.
///
/// The SYNTAX directive defines parser grammar rules for command recognition.
/// Example: SYNTAX TAKE OBJECT (FIND TAKEBIT) (ON GROUND) = V-TAKE
public struct ZILSyntaxDeclaration: Sendable, Equatable {
    /// The verb being defined
    public let verb: String
    /// Syntax pattern elements
    public let pattern: [ZILSyntaxElement]
    /// Action routine to call
    public let action: String
    /// Source location of the declaration
    public let location: SourceLocation

    public init(verb: String, pattern: [ZILSyntaxElement], action: String, location: SourceLocation) {
        self.verb = verb
        self.pattern = pattern
        self.action = action
        self.location = location
    }
}

/// Syntax pattern element for SYNTAX declarations.
///
/// Represents different types of elements in syntax patterns like OBJECT, prepositions, etc.
public indirect enum ZILSyntaxElement: Sendable, Equatable {
    /// Object reference with optional constraints
    case object(String, constraints: [ZILExpression])
    /// Literal preposition or word
    case preposition(String)
    /// Optional element
    case optional(ZILSyntaxElement)
}

/// Word synonym declaration.
///
/// The SYNONYM directive defines word equivalencies for the parser.
/// Example: SYNONYM LAMP LIGHT LANTERN = LAMP
public struct ZILSynonymDeclaration: Sendable, Equatable {
    /// List of synonym words
    public let words: [String]
    /// The canonical word they map to
    public let canonical: String
    /// Source location of the declaration
    public let location: SourceLocation

    public init(words: [String], canonical: String, location: SourceLocation) {
        self.words = words
        self.canonical = canonical
        self.location = location
    }
}

/// Macro definition declaration.
///
/// The DEFMAC directive defines preprocessor macros with parameters and body.
/// Example: DEFMAC ENABLE ('INT) <FORM PUT .INT ,C-ENABLED? 1>>
public struct ZILDefmacDeclaration: Sendable, Equatable {
    /// Macro name
    public let name: String
    /// Parameter list with type information
    public let parameters: [ZILMacroParameter]
    /// Macro body expression
    public let body: ZILExpression
    /// Source location of the declaration
    public let location: SourceLocation

    public init(name: String, parameters: [ZILMacroParameter], body: ZILExpression, location: SourceLocation) {
        self.name = name
        self.parameters = parameters
        self.body = body
        self.location = location
    }

    /// Get parameter names for compatibility with existing code
    public var parameterNames: [String] {
        return parameters.map { $0.name }
    }

    /// Check if this macro accepts variable arguments
    public var hasVariableArgs: Bool {
        return parameters.contains { $0.isVariadic }
    }
}

/// Buzzword declaration.
///
/// The BUZZ directive defines words that should be ignored by the parser.
/// Example: BUZZ A AN THE OF AND TO
public struct ZILBuzzDeclaration: Sendable, Equatable {
    /// List of buzzwords to ignore
    public let words: [String]
    /// Source location of the declaration
    public let location: SourceLocation

    public init(words: [String], location: SourceLocation) {
        self.words = words
        self.location = location
    }
}

// MARK: - ZILNode Conformance

extension ZILExpression: ZILNode {
    public var location: SourceLocation {
        switch self {
        case .atom(_, let location),
             .number(_, let location),
             .string(_, let location),
             .globalVariable(_, let location),
             .localVariable(_, let location),
             .propertyReference(_, let location),
             .flagReference(_, let location),
             .list(_, let location),
             .table(_, _, let location),
             .indirection(_, let location):
            return location
        }
    }
}

extension ZILDeclaration: ZILNode {
    public var location: SourceLocation {
        switch self {
        case .routine(let routine):
            return routine.location
        case .object(let object):
            return object.location
        case .global(let global):
            return global.location
        case .property(let property):
            return property.location
        case .constant(let constant):
            return constant.location
        case .insertFile(let insertFile):
            return insertFile.location
        case .version(let version):
            return version.location
        case .princ(let princ):
            return princ.location
        case .sname(let sname):
            return sname.location
        case .set(let set):
            return set.location
        case .directions(let directions):
            return directions.location
        case .syntax(let syntax):
            return syntax.location
        case .synonym(let synonym):
            return synonym.location
        case .defmac(let defmac):
            return defmac.location
        case .buzz(let buzz):
            return buzz.location
        }
    }
}

extension ZILRoutineDeclaration: ZILNode {}
extension ZILObjectDeclaration: ZILNode {}
extension ZILObjectProperty: ZILNode {}
extension ZILGlobalDeclaration: ZILNode {}
extension ZILPropertyDeclaration: ZILNode {}
extension ZILConstantDeclaration: ZILNode {}
extension ZILInsertFileDeclaration: ZILNode {}
extension ZILVersionDeclaration: ZILNode {}
extension ZILPrincDeclaration: ZILNode {}
extension ZILSnameDeclaration: ZILNode {}
extension ZILSetDeclaration: ZILNode {}
extension ZILDirectionsDeclaration: ZILNode {}
extension ZILSyntaxDeclaration: ZILNode {}
extension ZILSynonymDeclaration: ZILNode {}
extension ZILDefmacDeclaration: ZILNode {}
extension ZILBuzzDeclaration: ZILNode {}