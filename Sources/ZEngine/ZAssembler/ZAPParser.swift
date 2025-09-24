/// ZAP Assembly Parser - Parses ZAP assembly source into structured statements
import Foundation

/// Parser for ZAP (Z-Machine Assembly Program) source code
public class ZAPParser {

    private var lines: [String] = []
    private var currentLine = 0

    /// Parse ZAP source code into assembly statements
    ///
    /// - Parameter source: ZAP assembly source code as string
    /// - Returns: Array of parsed ZAP statements
    /// - Throws: AssemblyError for parsing failures
    public func parse(_ source: String) throws -> [ZAPStatement] {
        lines = source.components(separatedBy: .newlines)
        currentLine = 0

        var statements: [ZAPStatement] = []

        while currentLine < lines.count {
            let line = lines[currentLine].trimmingCharacters(in: .whitespaces)
            let location = SourceLocation(file: "assembly", line: currentLine + 1, column: 1)

            // Skip empty lines and comments
            if line.isEmpty || line.hasPrefix(";") {
                currentLine += 1
                continue
            }

            do {
                let statement = try parseLine(line, at: location)
                statements.append(statement)
            } catch {
                throw AssemblyError.invalidInstruction(line, location: location)
            }

            currentLine += 1
        }

        return statements
    }

    private func parseLine(_ line: String, at location: SourceLocation) throws -> ZAPStatement {
        // Handle labels (either standalone or with instruction on same line)
        if line.contains(":") {
            let colonIndex = line.firstIndex(of: ":")!
            let labelName = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let remainder = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            if remainder.isEmpty {
                // Standalone label
                return .label(labelName, location)
            } else {
                // Label with instruction on same line - parse the instruction part
                let instructionStatement = try parseInstruction(remainder, at: location)
                // Extract the instruction from the statement
                if case .instruction(let instruction, _) = instructionStatement {
                    return .instruction(instruction, location)
                } else {
                    // This shouldn't happen, but handle gracefully
                    return instructionStatement
                }
            }
        }

        // Handle directives (start with .)
        if line.hasPrefix(".") {
            return try parseDirective(line, at: location)
        }

        // Handle regular instructions
        return try parseInstruction(line, at: location)
    }

    private func parseDirective(_ line: String, at location: SourceLocation) throws -> ZAPStatement {
        let parts = splitInstruction(line)
        guard let directiveName = parts.first?.uppercased() else {
            throw AssemblyError.invalidInstruction(line, location: location)
        }

        let arguments = Array(parts.dropFirst())
        let parsedArgs = try arguments.map { try parseArgument($0) }

        let directive = ZAPDirective(
            name: String(directiveName.dropFirst()), // Remove the leading dot
            arguments: parsedArgs
        )

        return .directive(directive, location)
    }

    private func parseInstruction(_ line: String, at location: SourceLocation) throws -> ZAPStatement {
        let parts = splitInstruction(line)
        guard let opcode = parts.first?.uppercased() else {
            throw AssemblyError.invalidInstruction(line, location: location)
        }

        let operands = Array(parts.dropFirst())
        let parsedOperands = try operands.map { try parseArgument($0) }

        // Extract branch target and result target if present
        var branchTarget: String? = nil
        var resultTarget: String? = nil
        var finalOperands = parsedOperands

        // Look for branch targets (/label or \label)
        if let lastOperand = parsedOperands.last,
           case .atom(let atomValue) = lastOperand,
           (atomValue.hasPrefix("/") || atomValue.hasPrefix("\\")) {
            branchTarget = String(atomValue.dropFirst())
            finalOperands = Array(parsedOperands.dropLast())
        }

        // Look for result targets (>variable)
        if let lastOperand = finalOperands.last,
           case .atom(let atomValue) = lastOperand,
           atomValue.hasPrefix(">") {
            resultTarget = String(atomValue.dropFirst())
            finalOperands = Array(finalOperands.dropLast())
        }

        let instruction = ZAPInstruction(
            opcode: opcode,
            operands: finalOperands,
            label: nil, // Labels are handled separately
            branchTarget: branchTarget,
            resultTarget: resultTarget
        )

        return .instruction(instruction, location)
    }

    private func parseArgument(_ arg: String) throws -> ZValue {
        let trimmed = arg.trimmingCharacters(in: .whitespaces)

        // Handle string literals
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
            let content = String(trimmed.dropFirst().dropLast())
            return .string(unescapeString(content))
        }

        // Handle numbers (including hex)
        if let number = parseNumber(trimmed) {
            return .number(number)
        }

        // Handle special atoms with prefixes
        if trimmed.hasPrefix("'") {
            // Global variable reference
            return .atom(trimmed)
        }

        if trimmed.hasPrefix("P?") {
            // Property reference
            return .atom(trimmed)
        }

        if trimmed.hasPrefix("F?") {
            // Flag reference
            return .atom(trimmed)
        }

        // Default to atom
        return .atom(trimmed)
    }

    private func parseNumber(_ str: String) -> Int16? {
        // Handle hexadecimal
        if str.hasPrefix("0x") || str.hasPrefix("0X") {
            return Int16(str.dropFirst(2), radix: 16)
        }

        // Handle decimal
        return Int16(str)
    }

    private func splitInstruction(_ line: String) -> [String] {
        // Split on whitespace and commas, preserving quoted strings
        var parts: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]

            if char == "\"" {
                inQuotes.toggle()
                current.append(char)
            } else if inQuotes {
                current.append(char)
            } else if char.isWhitespace || char == "," {
                if !current.isEmpty {
                    parts.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }

            i = line.index(after: i)
        }

        if !current.isEmpty {
            parts.append(current)
        }

        return parts
    }

    private func unescapeString(_ str: String) -> String {
        return str
            .replacingOccurrences(of: "\\\\", with: "\\")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\r")
            .replacingOccurrences(of: "\\t", with: "\t")
    }
}