/// Builds syntax tables for Z-Machine parser from SYNTAX declarations
import Foundation

/// Operand flags for SYNTAX patterns
public struct OperandFlags: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    // Location constraints
    public static let have = OperandFlags(rawValue: 1 << 0)       // Must be possessed
    public static let held = OperandFlags(rawValue: 1 << 1)       // Must be held
    public static let carried = OperandFlags(rawValue: 1 << 2)    // Same as HELD
    public static let take = OperandFlags(rawValue: 1 << 3)       // Attempt implicit taking
    public static let onGround = OperandFlags(rawValue: 1 << 4)   // Must be in room at top level
    public static let inRoom = OperandFlags(rawValue: 1 << 5)     // Must be accessible in room

    // Search constraints
    public static let find = OperandFlags(rawValue: 1 << 6)       // GWIM search with flag

    // Quantity constraints
    public static let many = OperandFlags(rawValue: 1 << 7)       // Allow multiple objects

    /// Parse flags from ZIL syntax element constraints
    public static func parse(from constraints: [String]) -> (flags: OperandFlags, findFlag: String?) {
        var flags = OperandFlags()
        var findFlag: String? = nil

        var i = 0
        while i < constraints.count {
            let constraint = constraints[i].uppercased()

            switch constraint {
            case "HAVE":
                flags.insert(.have)
            case "HELD":
                flags.insert(.held)
            case "CARRIED":
                flags.insert(.carried)
            case "TAKE":
                flags.insert(.take)
            case "ON-GROUND":
                flags.insert(.onGround)
            case "IN-ROOM":
                flags.insert(.inRoom)
            case "MANY":
                flags.insert(.many)
            case "FIND":
                flags.insert(.find)
                // Next element should be the flag name
                if i + 1 < constraints.count {
                    findFlag = constraints[i + 1]
                    i += 1  // Skip next element
                }
            default:
                break
            }

            i += 1
        }

        return (flags, findFlag)
    }
}

/// Syntax pattern element (part of a SYNTAX declaration)
public enum SyntaxPatternElement: Sendable, Equatable {
    case object(OperandFlags, String?)  // flags, findFlag
    case preposition(String)
}

/// Complete syntax pattern for a verb
public struct SyntaxPattern: Sendable {
    /// Verb name (canonical)
    public let verb: String
    /// Verb number
    public let verbNumber: UInt8
    /// Pattern elements
    public let elements: [SyntaxPatternElement]
    /// Action handler routine
    public let action: String
    /// Optional preaction handler
    public let preaction: String?
    /// Source location
    public let location: SourceLocation

    public init(verb: String, verbNumber: UInt8, elements: [SyntaxPatternElement], action: String, preaction: String?, location: SourceLocation) {
        self.verb = verb
        self.verbNumber = verbNumber
        self.elements = elements
        self.action = action
        self.preaction = preaction
        self.location = location
    }
}

/// Builds syntax tables from SYNTAX declarations
public struct SyntaxTableBuilder: Sendable {

    // MARK: - Properties

    /// All syntax patterns
    private var patterns: [SyntaxPattern] = []

    // MARK: - Initialization

    public init() {
    }

    // MARK: - Pattern Management

    /// Add SYNTAX declaration
    public mutating func addSyntax(_ declaration: ZILSyntaxDeclaration, vocabularyManager: inout VocabularyManager) throws {
        // Get or assign verb number
        let verbNumber = vocabularyManager.addVerb(declaration.verb)

        // Parse pattern elements
        var elements: [SyntaxPatternElement] = []

        for syntaxElement in declaration.pattern {
            switch syntaxElement {
            case .object(let name, let constraints):
                // Extract constraint strings from expressions
                let constraintStrings = constraints.compactMap { expr -> String? in
                    switch expr {
                    case .atom(let atom, _):
                        return atom
                    default:
                        return nil
                    }
                }
                let (flags, findFlag) = OperandFlags.parse(from: constraintStrings)
                elements.append(.object(flags, findFlag))

            case .preposition(let prep):
                vocabularyManager.addWord(prep, type: .preposition)
                elements.append(.preposition(prep))

            case .optional(let innerElement):
                // Handle optional elements recursively
                // For now, we'll just process the inner element
                // A full implementation would mark it as optional in the pattern
                switch innerElement {
                case .object(let name, let constraints):
                    let constraintStrings = constraints.compactMap { expr -> String? in
                        switch expr {
                        case .atom(let atom, _):
                            return atom
                        default:
                            return nil
                        }
                    }
                    let (flags, findFlag) = OperandFlags.parse(from: constraintStrings)
                    elements.append(.object(flags, findFlag))
                case .preposition(let prep):
                    vocabularyManager.addWord(prep, type: .preposition)
                    elements.append(.preposition(prep))
                case .optional:
                    // Nested optionals - skip for now
                    break
                }
            }
        }

        // Extract action and preaction
        let actionParts = declaration.action.split(separator: " ").map(String.init)
        let action = actionParts.first ?? declaration.action
        let preaction = actionParts.count > 1 ? actionParts[1] : nil

        // Create pattern
        let pattern = SyntaxPattern(
            verb: declaration.verb,
            verbNumber: verbNumber,
            elements: elements,
            action: action,
            preaction: preaction,
            location: declaration.location
        )

        patterns.append(pattern)
    }

    /// Get all syntax patterns
    public func getPatterns() -> [SyntaxPattern] {
        return patterns
    }

    // MARK: - ZAP Code Generation

    /// Generate ZAP assembly for syntax tables
    public func generateZAPCode() -> [String] {
        var lines: [String] = []

        // Group patterns by verb number
        let groupedPatterns: [UInt8: [SyntaxPattern]] = .init(grouping: patterns, by: { $0.verbNumber })

        // Generate action tables for each verb
        for (verbNum, verbPatterns) in groupedPatterns.sorted(by: { $0.key < $1.key }) {
            guard let firstPattern = verbPatterns.first else { continue }

            lines.append("")
            lines.append("; Syntax patterns for \(firstPattern.verb)")

            // Generate routing table for this verb
            for (index, pattern) in verbPatterns.enumerated() {
                let syntaxLabel = "SYNTAX-\(pattern.verb.uppercased())-\(index + 1)"

                lines.append("\(syntaxLabel)::")

                // Encode pattern
                lines.append("\t; Pattern: \(describePattern(pattern))")

                // Emit pattern structure (simplified for now)
                // In full implementation, this would encode:
                // - Pattern elements (object slots, prepositions)
                // - Operand flags
                // - Action handler reference
                // - Preaction handler reference

                lines.append("\t.WORD \(pattern.action)")
                if let preaction = pattern.preaction {
                    lines.append("\t.WORD \(preaction)")
                } else {
                    lines.append("\t.WORD 0")
                }

                // Encode pattern elements
                for element in pattern.elements {
                    switch element {
                    case .object(let flags, let findFlag):
                        lines.append("\t.WORD $\(String(flags.rawValue, radix: 16, uppercase: true))")
                        if let flag = findFlag {
                            lines.append("\t.WORD \(flag)")
                        }
                    case .preposition(let prep):
                        lines.append("\t.WORD ?\(prep.uppercased())")
                    }
                }

                lines.append("\t.WORD 0\t; End of pattern")
            }
        }

        return lines
    }

    /// Describe pattern for comments
    private func describePattern(_ pattern: SyntaxPattern) -> String {
        var desc = pattern.verb

        for element in pattern.elements {
            switch element {
            case .object(let flags, let findFlag):
                desc += " OBJECT"
                if !flags.isEmpty {
                    desc += "("
                    var flagDescs: [String] = []
                    if flags.contains(.many) { flagDescs.append("MANY") }
                    if flags.contains(.have) { flagDescs.append("HAVE") }
                    if flags.contains(.held) { flagDescs.append("HELD") }
                    if flags.contains(.carried) { flagDescs.append("CARRIED") }
                    if flags.contains(.take) { flagDescs.append("TAKE") }
                    if flags.contains(.onGround) { flagDescs.append("ON-GROUND") }
                    if flags.contains(.inRoom) { flagDescs.append("IN-ROOM") }
                    if flags.contains(.find), let flag = findFlag {
                        flagDescs.append("FIND \(flag)")
                    }
                    desc += flagDescs.joined(separator: " ")
                    desc += ")"
                }
            case .preposition(let prep):
                desc += " \(prep)"
            }
        }

        desc += " = \(pattern.action)"
        if let preaction = pattern.preaction {
            desc += " \(preaction)"
        }

        return desc
    }

    // MARK: - Statistics

    /// Get syntax table statistics
    public func getStatistics() -> String {
        let verbCount = Set(patterns.map { $0.verbNumber }).count
        return "Syntax Table Statistics:\n" +
               "  Total patterns: \(patterns.count)\n" +
               "  Unique verbs: \(verbCount)\n"
    }
}
