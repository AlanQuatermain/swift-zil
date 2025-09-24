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
public enum ZILExpression: Sendable, Equatable {
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

    /// Optional parameters (marked with "OPT")
    public let optionalParameters: [String]

    /// Auxiliary variables (marked with "AUX")
    public let auxiliaryVariables: [String]

    /// Routine body expressions
    public let body: [ZILExpression]

    /// Source location of the routine declaration
    public let location: SourceLocation

    public init(name: String, parameters: [String] = [], optionalParameters: [String] = [], auxiliaryVariables: [String] = [], body: [ZILExpression], location: SourceLocation) {
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
             .list(_, let location):
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