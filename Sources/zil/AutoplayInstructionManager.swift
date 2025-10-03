import Foundation
import ZEngine

/// Manages autoplay instruction execution for automated story file verification
public class AutoplayInstructionManager {

    // MARK: - Types

    /// Compiled track pattern for efficient output processing
    internal struct CompiledTrackPattern {
        let regex: Regex<AnyRegexOutput>
        let counterName: String
        let originalPattern: String
    }

    /// Wound level enum for diagnosis
    enum WoundLevel: Int {
        case healthy = 0
        case light = 1
        case serious = 2
        case several = 3
        case critical = 4
    }

    // MARK: - Static Compiled Regexes for Diagnosis

    private nonisolated(unsafe) static let perfectHealthRegex = try! Regex(#"(?i)\bperfect health\b"#)
    private nonisolated(unsafe) static let lightWoundRegex = try! Regex(#"(?i)\blight wound\b"#)
    private nonisolated(unsafe) static let seriousWoundRegex = try! Regex(#"(?i)\bserious wound\b"#)
    private nonisolated(unsafe) static let severalWoundsRegex = try! Regex(#"(?i)\bseveral wounds\b"#)
    private nonisolated(unsafe) static let seriousWoundsRegex = try! Regex(#"(?i)\bserious wounds\b"#)

    /// Represents different types of instruction directives
    public enum InstructionDirective {
        case command(String)                    // Plain command to send to game
        case setCounter(String, Int)            // !SET counter = value
        case regex(String, String)              // !REGEX name = "pattern"
        case trackPattern(String, String)       // !TRACK regex "pattern" counter
        case loop                               // !LOOP
        case until(String)                      // !UNTIL regex "pattern"
        case untilRef(String)                   // !UNTIL regex name
        case ifRegex(String)                    // !IF regex "pattern" THEN
        case ifRegexRef(String)                 // !IF regex name THEN
        case ifCounter(String, String, Int)     // !IFCOUNTER name op value THEN
        case end                                // !END
        case wait(Int)                          // !WAIT turns
        case heal(String?)                      // !HEAL [counter]
        case diagnose(String)                   // !DIAGNOSE counter
        case waitUntil(String)                  // !WAIT-UNTIL regex "pattern"
    }

    /// Current execution state
    public struct AutoplayState {
        var counters: [String: Int] = [:]
        var regexes: [String: Regex<AnyRegexOutput>] = [:]     // Compiled named regexes from !REGEX directive
        var currentInstructionIndex: Int = 0
        var loopStack: [Int] = []               // Stack of loop start positions for nested loops
        var commandQueue: [String] = []         // Queue for multi-command sequences like !HEAL and !WAIT
        var savedLampState: String? = nil       // For !HEAL lamp state restoration
        var lastOutputLength: Int = 0           // For auto-timing calculations
        var lastInputWasEmpty: Bool = false     // Track if last manual input was empty (for timing)
        var activeTrackPatterns: [CompiledTrackPattern] = [] // Currently active track patterns in scope
        var outputBuffer: String = ""           // Accumulate output text for pattern matching
        var pendingDiagnoseCounter: String? = nil  // Counter to update after diagnose command
    }

    /// Configuration for autoplay execution
    public struct AutoplayConfig {
        let interval: Int?                      // Fixed delay in seconds
        let isManualMode: Bool                  // Manual-advance mode
        let verbosity: Int                      // Logging level (0, 1, 2, 3)

        public init(interval: Int? = nil, isManualMode: Bool = false, verbosity: Int = 0) {
            self.interval = interval
            self.isManualMode = isManualMode
            self.verbosity = verbosity
        }
    }

    // MARK: - Properties

    private let config: AutoplayConfig
    internal var state: AutoplayState
    private var instructions: [InstructionDirective]
    private var zmachine: ZMachine?
    private var terminalDelegate: ZMachineTerminalDelegate?

    // MARK: - Initialization

    public init(config: AutoplayConfig) {
        self.config = config
        self.state = AutoplayState()
        self.instructions = []
    }

    // MARK: - Public Interface

    /// Load and parse instruction file
    /// - Parameter filePath: Path to instruction file
    /// - Throws: InstructionError for parsing or file errors
    public func loadInstructions(from filePath: String) throws {
        let fileURL = URL(fileURLWithPath: filePath)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        self.instructions = try parseInstructions(content)

        if config.verbosity >= 1 {
            print("Loaded \(instructions.count) instructions from \(filePath)")
        }
    }

    /// Execute autoplay with given Z-Machine instance
    /// - Parameters:
    ///   - zmachine: Z-Machine instance to control
    public func execute(with zmachine: ZMachine) throws {
        // Create our custom terminal delegate that handles autoplay
        let autoplayDelegate = AutoplayTerminalDelegate(manager: self, zmachine: zmachine)
        zmachine.inputDelegate = autoplayDelegate
        zmachine.outputDelegate = autoplayDelegate

        if config.verbosity >= 1 {
            print("Starting autoplay execution with \(instructions.count) instructions")
        }

        // Start the Z-Machine - it will call our delegate when it needs input
        try zmachine.run()
    }

    // MARK: - Internal Methods

    /// Parse instruction file content into directives
    private func parseInstructions(_ content: String) throws -> [InstructionDirective] {
        var directives: [InstructionDirective] = []
        let lines = content.components(separatedBy: .newlines)

        for (lineNumber, line) in lines.enumerated() {
            do {
                if let directive = try parseLine(line, lineNumber: lineNumber + 1) {
                    directives.append(directive)
                }
            } catch {
                throw InstructionError.parseError("Line \(lineNumber + 1): \(error.localizedDescription)")
            }
        }

        return directives
    }

    /// Parse a single line into an instruction directive
    private func parseLine(_ line: String, lineNumber: Int) throws -> InstructionDirective? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip empty lines
        if trimmed.isEmpty {
            return nil
        }

        // Handle comments - remove everything after #
        let beforeComment = trimmed.components(separatedBy: "#").first ?? ""
        let cleanLine = beforeComment.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanLine.isEmpty {
            return nil
        }

        // Check for directives (lines starting with !)
        if cleanLine.hasPrefix("!") {
            return try parseDirective(cleanLine, lineNumber: lineNumber)
        } else {
            // Plain command
            return .command(cleanLine)
        }
    }

    /// Parse a directive line (starting with !)
    private func parseDirective(_ line: String, lineNumber: Int) throws -> InstructionDirective {
        let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let directive = parts.first?.uppercased() else {
            throw InstructionError.parseError("Empty directive")
        }

        switch directive {
        case "!SET":
            return try parseSetDirective(parts)
        case "!REGEX":
            return try parseRegexDirective(parts)
        case "!TRACK":
            return try parseTrackDirective(parts)
        case "!LOOP":
            return .loop
        case "!UNTIL":
            return try parseUntilDirective(parts)
        case "!IF":
            return try parseIfDirective(parts)
        case "!IFCOUNTER":
            return try parseIfCounterDirective(parts)
        case "!END":
            return .end
        case "!WAIT":
            return try parseWaitDirective(parts)
        case "!WAIT-UNTIL":
            return try parseWaitUntilDirective(parts)
        case "!HEAL":
            return try parseHealDirective(parts)
        case "!DIAGNOSE":
            return try parseDiagnoseDirective(parts)
        default:
            throw InstructionError.parseError("Unknown directive: \(directive)")
        }
    }

    /// Parse !SET counter = value
    private func parseSetDirective(_ parts: [String]) throws -> InstructionDirective {
        guard parts.count >= 4,
              parts[2] == "=" else {
            throw InstructionError.parseError("!SET requires format: !SET counter = value")
        }

        let counter = parts[1]
        guard let value = Int(parts[3]) else {
            throw InstructionError.parseError("!SET value must be an integer")
        }

        return .setCounter(counter, value)
    }

    /// Parse !REGEX name = "pattern"
    private func parseRegexDirective(_ parts: [String]) throws -> InstructionDirective {
        guard parts.count >= 4,
              parts[2] == "=" else {
            throw InstructionError.parseError("!REGEX requires format: !REGEX name = \"pattern\"")
        }

        let name = parts[1]

        // Find quoted pattern
        let fullLine = parts.joined(separator: " ")
        guard let patternStart = fullLine.firstIndex(of: "\""),
              let patternEnd = fullLine.lastIndex(of: "\""),
              patternStart != patternEnd else {
            throw InstructionError.parseError("!REGEX pattern must be quoted")
        }

        let pattern = String(fullLine[fullLine.index(after: patternStart)..<patternEnd])
        return .regex(name, pattern)
    }

    /// Parse !TRACK regex "pattern" counter
    private func parseTrackDirective(_ parts: [String]) throws -> InstructionDirective {
        guard parts.count >= 4,
              parts[1].uppercased() == "REGEX" else {
            throw InstructionError.parseError("!TRACK requires format: !TRACK regex \"pattern\" counter")
        }

        // Find quoted pattern
        let fullLine = parts.joined(separator: " ")
        guard let patternStart = fullLine.firstIndex(of: "\""),
              let patternEnd = fullLine.lastIndex(of: "\""),
              patternStart != patternEnd else {
            throw InstructionError.parseError("!TRACK pattern must be quoted")
        }

        let pattern = String(fullLine[fullLine.index(after: patternStart)..<patternEnd])
        let counter = parts.last!

        return .trackPattern(pattern, counter)
    }

    /// Parse !IF regex "pattern" THEN or !IF regex name THEN
    private func parseIfDirective(_ parts: [String]) throws -> InstructionDirective {
        guard parts.count >= 4,
              parts[1].uppercased() == "REGEX",
              parts.last?.uppercased() == "THEN" else {
            throw InstructionError.parseError("!IF requires format: !IF regex \"pattern\" THEN or !IF regex name THEN")
        }

        // Check if it's a quoted pattern or a reference
        let fullLine = parts.joined(separator: " ")
        if let patternStart = fullLine.firstIndex(of: "\""),
           let patternEnd = fullLine.lastIndex(of: "\""),
           patternStart != patternEnd {
            // Quoted pattern - inline regex
            let pattern = String(fullLine[fullLine.index(after: patternStart)..<patternEnd])
            return .ifRegex(pattern)
        } else {
            // No quotes - reference to named regex
            // Format: !IF regex name THEN
            guard parts.count >= 4 else {
                throw InstructionError.parseError("!IF requires regex name or quoted pattern")
            }
            let name = parts[2]
            return .ifRegexRef(name)
        }
    }

    /// Parse !UNTIL regex "pattern" or !UNTIL regex name
    private func parseUntilDirective(_ parts: [String]) throws -> InstructionDirective {
        guard parts.count >= 3,
              parts[1].uppercased() == "REGEX" else {
            throw InstructionError.parseError("!UNTIL requires format: !UNTIL regex \"pattern\" or !UNTIL regex name")
        }

        // Check if it's a quoted pattern or a reference
        let fullLine = parts.joined(separator: " ")
        if let patternStart = fullLine.firstIndex(of: "\""),
           let patternEnd = fullLine.lastIndex(of: "\""),
           patternStart != patternEnd {
            // Quoted pattern - inline regex
            let pattern = String(fullLine[fullLine.index(after: patternStart)..<patternEnd])
            return .until(pattern)
        } else {
            // No quotes - reference to named regex
            guard parts.count >= 3 else {
                throw InstructionError.parseError("!UNTIL requires regex name or quoted pattern")
            }
            let name = parts[2]
            return .untilRef(name)
        }
    }

    /// Parse !IFCOUNTER name op value THEN
    private func parseIfCounterDirective(_ parts: [String]) throws -> InstructionDirective {
        guard parts.count >= 5,
              parts.last?.uppercased() == "THEN" else {
            throw InstructionError.parseError("!IFCOUNTER requires format: !IFCOUNTER counter op value THEN")
        }

        let counter = parts[1]
        let op = parts[2]
        guard let value = Int(parts[3]) else {
            throw InstructionError.parseError("!IFCOUNTER value must be an integer")
        }

        guard ["<", "<=", ">", ">=", "==", "!="].contains(op) else {
            throw InstructionError.parseError("!IFCOUNTER operator must be one of: <, <=, >, >=, ==, !=")
        }

        return .ifCounter(counter, op, value)
    }

    /// Parse !WAIT turns
    private func parseWaitDirective(_ parts: [String]) throws -> InstructionDirective {
        guard parts.count >= 2 else {
            throw InstructionError.parseError("!WAIT requires format: !WAIT turns")
        }

        guard let turns = Int(parts[1]) else {
            throw InstructionError.parseError("!WAIT turns must be an integer")
        }

        return .wait(turns)
    }

    /// Parse !HEAL [counter]
    private func parseHealDirective(_ parts: [String]) throws -> InstructionDirective {
        if parts.count >= 2 {
            return .heal(parts[1])
        } else {
            return .heal(nil)
        }
    }

    /// Parse !DIAGNOSE counter
    private func parseDiagnoseDirective(_ parts: [String]) throws -> InstructionDirective {
        guard parts.count >= 2 else {
            throw InstructionError.parseError("!DIAGNOSE requires format: !DIAGNOSE counter")
        }

        let counter = parts[1]
        return .diagnose(counter)
    }

    /// Parse !WAIT-UNTIL regex "pattern"
    private func parseWaitUntilDirective(_ parts: [String]) throws -> InstructionDirective {
        guard parts.count >= 3,
              parts[1].uppercased() == "REGEX" else {
            throw InstructionError.parseError("!WAIT-UNTIL requires format: !WAIT-UNTIL regex \"pattern\"")
        }

        // Find quoted pattern
        let fullLine = parts.joined(separator: " ")
        guard let patternStart = fullLine.firstIndex(of: "\""),
              let patternEnd = fullLine.lastIndex(of: "\""),
              patternStart != patternEnd else {
            throw InstructionError.parseError("!WAIT-UNTIL pattern must be quoted")
        }

        let pattern = String(fullLine[fullLine.index(after: patternStart)..<patternEnd])
        return .waitUntil(pattern)
    }

    // MARK: - Instruction Stream Management

    /// Consume the next instruction from the stream
    /// - Returns: The next instruction, or nil if at end of stream
    private func consumeInstruction() -> InstructionDirective? {
        guard state.currentInstructionIndex < instructions.count else {
            return nil
        }

        let instruction = instructions[state.currentInstructionIndex]
        state.currentInstructionIndex += 1
        return instruction
    }

    /// Consume instructions until matching END directive (for IFCOUNTER skip logic)
    private func consumeUntilEnd() {
        var depth = 1
        while depth > 0 {
            guard let instruction = consumeInstruction() else { break }
            switch instruction {
            case .ifCounter(_, _, _), .ifRegex(_), .ifRegexRef(_):
                depth += 1
            case .end:
                depth -= 1
            default:
                break
            }
        }
    }

    /// Get the next command to execute
    func getNextCommand() -> String? {
        // First, check if we have queued commands from !WAIT or !HEAL
        if !state.commandQueue.isEmpty {
            let command = state.commandQueue.removeFirst()
            if config.verbosity >= 1 {
                print("[Autoplay] Executing queued command: \(command)")
            }
            return command
        }

        // Simple coordination loop: consume instructions until we get a command
        while let instruction = consumeInstruction() {
            if let command = processInstruction(instruction) {
                return command
            }
            // No command produced, but instruction may have queued something
            // Check queue before consuming next instruction
            if !state.commandQueue.isEmpty {
                let command = state.commandQueue.removeFirst()
                if config.verbosity >= 1 {
                    print("[Autoplay] Executing queued command: \(command)")
                }
                return command
            }
        }

        // No more instructions
        if config.verbosity >= 1 {
            print("[Autoplay] All instructions completed")
        }
        return nil
    }

    /// Process game output for pattern matching
    func processOutput(_ text: String) {
        // Accumulate output text for pattern matching across multiple calls
        state.outputBuffer += text

        // Track cumulative output length for auto-timing
        state.lastOutputLength += text.count

        if config.verbosity >= 2 {
            print("[Autoplay] Processing output: \(text.prefix(50))\(text.count > 50 ? "..." : "") (\(text.count) chars)")
            print("[Autoplay] Total accumulated: \(state.outputBuffer.count) chars")
        }

        // Check if we're processing a diagnose command output
        if let counterName = state.pendingDiagnoseCounter {
            let level = woundLevel(from: state.outputBuffer)
            state.counters[counterName] = level.rawValue

            if config.verbosity >= 1 {
                print("[Autoplay] Diagnose result: \(level) (level \(level.rawValue)), set \(counterName) = \(level.rawValue)")
            }

            state.pendingDiagnoseCounter = nil
        }

        // Check active track patterns against accumulated output
        for compiledPattern in state.activeTrackPatterns {
            if state.outputBuffer.firstMatch(of: compiledPattern.regex) != nil {
                // Increment counter
                state.counters[compiledPattern.counterName, default: 0] += 1

                if config.verbosity >= 2 {
                    print("[Autoplay] Pattern '\(compiledPattern.originalPattern)' matched in accumulated output, \(compiledPattern.counterName) = \(state.counters[compiledPattern.counterName, default: 0])")
                }
            }
        }

        // Check for UNTIL conditions if we're in a loop
        if !state.loopStack.isEmpty {
            // TODO: Implement UNTIL pattern checking against game output
            // For now, UNTIL conditions are handled by processInstruction() with simple loop restart
        }

        // Check for MORE prompts
        if text.contains("MORE") && (text.hasSuffix(">") || text.hasSuffix("> ")) {
            // This would be handled automatically by sending newline, but we track it
            if config.verbosity >= 2 {
                print("[Autoplay] MORE prompt detected")
            }
        }
    }

    // MARK: - Private Execution Methods

    /// Process a single instruction and return the command to execute
    private func processInstruction(_ instruction: InstructionDirective) -> String? {
        switch instruction {
        case .command(let command):
            if config.verbosity >= 1 {
                print("[Autoplay] Executing: \(command)")
            }
            return command

        case .setCounter(let name, let value):
            state.counters[name] = value
            if config.verbosity >= 2 {
                print("[Autoplay] Set \(name) = \(value)")
            }
            return nil

        case .regex(let name, let pattern):
            // Compile and store the named regex
            do {
                let regex = try Regex(pattern)
                state.regexes[name] = regex
                if config.verbosity >= 2 {
                    print("[Autoplay] Stored regex '\(name)' = \(pattern)")
                }
            } catch {
                if config.verbosity >= 1 {
                    print("[Autoplay] Warning: Failed to compile regex '\(name)': \(error)")
                }
            }
            return nil

        case .trackPattern(let pattern, let counter):
            // Compile and add track pattern to active list when encountered
            do {
                let regex = try Regex(pattern)
                let compiledPattern = CompiledTrackPattern(
                    regex: regex,
                    counterName: counter,
                    originalPattern: pattern
                )

                // Add to active patterns if not already present
                let alreadyExists = state.activeTrackPatterns.contains { existing in
                    existing.originalPattern == pattern && existing.counterName == counter
                }

                if !alreadyExists {
                    state.activeTrackPatterns.append(compiledPattern)

                    if config.verbosity >= 2 {
                        print("[Autoplay] Activated track pattern: '\(pattern)' -> \(counter)")
                    }
                }
            } catch {
                if config.verbosity >= 1 {
                    print("[Autoplay] Warning: Failed to compile regex pattern '\(pattern)': \(error)")
                }
            }
            return nil

        case .loop:
            // Save current position for potential UNTIL jump back
            state.loopStack.append(state.currentInstructionIndex - 1) // Save position of LOOP instruction
            if config.verbosity >= 2 {
                print("[Autoplay] Entering loop at instruction \(state.currentInstructionIndex - 1)")
            }
            return nil

        case .until(let pattern):
            // Check if we're in a loop and evaluate the pattern
            guard !state.loopStack.isEmpty else {
                if config.verbosity >= 2 {
                    print("[Autoplay] UNTIL outside of loop, ignoring")
                }
                return nil
            }

            // Compile and check the UNTIL pattern against accumulated output
            do {
                let regex = try Regex(pattern)
                if state.outputBuffer.firstMatch(of: regex) != nil {
                    // Pattern matched - exit the loop
                    state.loopStack.removeLast()
                    if config.verbosity >= 2 {
                        print("[Autoplay] UNTIL pattern '\(pattern)' matched, exiting loop")
                    }
                    return nil
                } else {
                    // Pattern not matched - restart loop
                    let loopStart = state.loopStack.last!
                    if config.verbosity >= 2 {
                        print("[Autoplay] UNTIL pattern '\(pattern)' not matched, restarting loop from instruction \(loopStart)")
                    }
                    state.currentInstructionIndex = loopStart + 1  // Jump back to instruction after LOOP
                    return nil
                }
            } catch {
                if config.verbosity >= 1 {
                    print("[Autoplay] Warning: Failed to compile UNTIL regex pattern '\(pattern)': \(error)")
                }
                // If regex compilation fails, exit the loop to avoid infinite loop
                state.loopStack.removeLast()
                return nil
            }

        case .untilRef(let name):
            // Check if we're in a loop and evaluate the named regex
            guard !state.loopStack.isEmpty else {
                if config.verbosity >= 2 {
                    print("[Autoplay] UNTIL outside of loop, ignoring")
                }
                return nil
            }

            // Look up the named regex
            guard let regex = state.regexes[name] else {
                if config.verbosity >= 1 {
                    print("[Autoplay] Warning: Unknown regex reference '\(name)'")
                }
                state.loopStack.removeLast()
                return nil
            }

            // Check the pattern against accumulated output
            if state.outputBuffer.firstMatch(of: regex) != nil {
                // Pattern matched - exit the loop
                state.loopStack.removeLast()
                if config.verbosity >= 2 {
                    print("[Autoplay] UNTIL regex '\(name)' matched, exiting loop")
                }
                return nil
            } else {
                // Pattern not matched - restart loop
                let loopStart = state.loopStack.last!
                if config.verbosity >= 2 {
                    print("[Autoplay] UNTIL regex '\(name)' not matched, restarting loop from instruction \(loopStart)")
                }
                state.currentInstructionIndex = loopStart + 1  // Jump back to instruction after LOOP
                return nil
            }

        case .ifRegex(let pattern):
            // Check if pattern matches current output
            do {
                let regex = try Regex(pattern)
                if state.outputBuffer.firstMatch(of: regex) != nil {
                    // Pattern matched - continue with block
                    if config.verbosity >= 2 {
                        print("[Autoplay] IF regex pattern '\(pattern)' matched, executing block")
                    }
                    return nil
                } else {
                    // Pattern not matched - skip to END
                    if config.verbosity >= 2 {
                        print("[Autoplay] IF regex pattern '\(pattern)' not matched, skipping to END")
                    }
                    consumeUntilEnd()
                    return nil
                }
            } catch {
                if config.verbosity >= 1 {
                    print("[Autoplay] Warning: Failed to compile IF regex pattern '\(pattern)': \(error)")
                }
                consumeUntilEnd()
                return nil
            }

        case .ifRegexRef(let name):
            // Look up named regex and check if it matches current output
            guard let regex = state.regexes[name] else {
                if config.verbosity >= 1 {
                    print("[Autoplay] Warning: Unknown regex reference '\(name)'")
                }
                consumeUntilEnd()
                return nil
            }

            if state.outputBuffer.firstMatch(of: regex) != nil {
                // Pattern matched - continue with block
                if config.verbosity >= 2 {
                    print("[Autoplay] IF regex '\(name)' matched, executing block")
                }
                return nil
            } else {
                // Pattern not matched - skip to END
                if config.verbosity >= 2 {
                    print("[Autoplay] IF regex '\(name)' not matched, skipping to END")
                }
                consumeUntilEnd()
                return nil
            }

        case .ifCounter(let name, let op, let value):
            if evaluateCondition(name: name, operator: op, value: value) {
                // Condition is true, continue normally
                if config.verbosity >= 2 {
                    print("[Autoplay] IFCOUNTER condition true, continuing")
                }
                return nil
            } else {
                // Condition is false, skip until matching END
                if config.verbosity >= 2 {
                    print("[Autoplay] IFCOUNTER condition false, skipping to END")
                }
                consumeUntilEnd()
                return nil
            }

        case .end:
            // Just a marker for conditional blocks, no action needed
            if config.verbosity >= 2 {
                print("[Autoplay] Reached END directive")
            }
            return nil

        case .wait(let turns):
            // Queue wait commands and return first one
            if config.verbosity >= 1 {
                print("[Autoplay] Queuing \(turns) wait commands for rapid execution")
            }

            for _ in 0..<turns {
                state.commandQueue.append("wait")
            }

            // Return the first wait command
            if !state.commandQueue.isEmpty {
                let command = state.commandQueue.removeFirst()
                if config.verbosity >= 2 {
                    print("[Autoplay] Executing first wait command (\(state.commandQueue.count) remaining)")
                }
                return command
            }
            return nil

        case .heal(let counterName):
            // Execute healing sequence with periodic diagnosis checks
            let wounds = counterName != nil ? state.counters[counterName!, default: 0] : 1

            if config.verbosity >= 1 {
                if let counterName = counterName {
                    print("[Autoplay] Executing healing sequence for \(wounds) \(counterName) wounds")
                } else {
                    print("[Autoplay] Executing basic healing sequence")
                }
            }

            // Only heal if there are actual wounds
            guard wounds > 0 else {
                if config.verbosity >= 1 {
                    print("[Autoplay] No wounds to heal, skipping")
                }
                return nil
            }

            // Save lamp state and turn off lamp
            state.savedLampState = "turn on lamp"
            state.commandQueue.append("turn off lamp")

            if let counterName = counterName {
                // Build healing loop with periodic diagnosis checks
                // The number of waits scales with wound level (wounds + 1)
                let waitsPerCheck = wounds + 1

                if config.verbosity >= 2 {
                    print("[Autoplay] Setting up healing loop: wait \(waitsPerCheck), diagnose, repeat if needed")
                }

                // Insert directives at current position:
                // !WAIT (wounds+1)
                // !DIAGNOSE counterName
                // !IFCOUNTER counterName > 0 THEN
                //   !HEAL counterName
                // !END
                // [lamp restoration will be queued after the recursion finishes]

                let waitInstruction = InstructionDirective.wait(waitsPerCheck)
                let diagnoseInstruction = InstructionDirective.diagnose(counterName)
                let ifCounterInstruction = InstructionDirective.ifCounter(counterName, ">", 0)
                let healInstruction = InstructionDirective.heal(counterName)
                let endInstruction = InstructionDirective.end

                instructions.insert(contentsOf: [waitInstruction, diagnoseInstruction, ifCounterInstruction, healInstruction, endInstruction],
                                  at: state.currentInstructionIndex)
            } else {
                // No counter specified, just do a fixed number of waits
                if config.verbosity >= 2 {
                    print("[Autoplay] Queuing 35 wait commands for basic healing")
                }
                for _ in 0..<35 {
                    state.commandQueue.append("wait")
                }
            }

            // Queue lamp restoration
            if let lampCommand = state.savedLampState {
                state.commandQueue.append(lampCommand)
                if config.verbosity >= 2 {
                    print("[Autoplay] Queued lamp restoration command")
                }
            }
            state.savedLampState = nil

            // Return first command from healing sequence
            if !state.commandQueue.isEmpty {
                let command = state.commandQueue.removeFirst()
                if config.verbosity >= 2 {
                    print("[Autoplay] Starting healing sequence with: \(command) (\(state.commandQueue.count) commands remaining)")
                }
                return command
            }
            return nil

        case .diagnose(let counterName):
            // Execute diagnose command and set up to capture the output
            if config.verbosity >= 1 {
                print("[Autoplay] Executing diagnose and updating \(counterName) counter")
            }

            // Mark that we're expecting diagnose output for this counter
            state.pendingDiagnoseCounter = counterName

            // Return the diagnose command
            return "diagnose"

        case .waitUntil(let pattern):
            // Execute wait-until sequence: keep waiting until pattern matches
            do {
                let regex = try Regex(pattern)

                if config.verbosity >= 1 {
                    print("[Autoplay] WAIT-UNTIL checking buffer (\(state.outputBuffer.count) chars): '\(state.outputBuffer.prefix(100))'")
                }

                // Check if pattern already matches current output
                if state.outputBuffer.firstMatch(of: regex) != nil {
                    if config.verbosity >= 1 {
                        print("[Autoplay] WAIT-UNTIL pattern '\(pattern)' matched, exiting")
                    }
                    return nil
                }

                // Pattern not matched, queue a wait command and re-queue this directive
                state.commandQueue.append("wait")

                // Re-queue this WAIT-UNTIL directive to check again after the wait
                if state.currentInstructionIndex > 0 {
                    // Insert this same directive right after the current position
                    instructions.insert(.waitUntil(pattern), at: state.currentInstructionIndex)
                }

                if config.verbosity >= 1 {
                    print("[Autoplay] WAIT-UNTIL pattern '\(pattern)' not matched, queuing wait command")
                }

                // Return nil - the queued wait will be picked up by getNextCommand()
                return nil

            } catch {
                if config.verbosity >= 1 {
                    print("[Autoplay] Warning: Failed to compile WAIT-UNTIL regex pattern '\(pattern)': \(error)")
                }
                return nil
            }
        }
    }

    /// Apply timing delays based on configuration
    internal func applyTiming() {
        // Skip timing for queued commands (WAIT and HEAL sequences)
        if !state.commandQueue.isEmpty {
            return
        }

        // Skip timing in manual mode when user pressed Enter (empty input)
        if config.isManualMode && state.lastInputWasEmpty {
            if config.verbosity >= 2 {
                print("[Autoplay] Skipping delay in manual mode after empty input")
            }
            state.lastInputWasEmpty = false // Reset flag
            return
        }

        if let interval = config.interval {
            // Fixed interval timing
            if interval > 0 {
                Thread.sleep(forTimeInterval: TimeInterval(interval))
            }
        } else {
            // Auto-timing based on last game output length
            let outputLength = state.lastOutputLength
            let delay: TimeInterval

            if outputLength < 40 {
                delay = 1.0  // Short output: 1 second
            } else if outputLength <= 160 {
                delay = 2.0  // Medium output: 2 seconds
            } else {
                delay = 4.0  // Long output: 4 seconds
            }

            if config.verbosity >= 2 {
                print("[Autoplay] Auto-timing: \(outputLength) chars -> \(delay)s delay")
            }

            Thread.sleep(forTimeInterval: delay)
        }
    }

    /// Request manual input in manual-advance mode
    private func requestManualInput() -> String? {
        if config.verbosity >= 1 {
            print("[Manual] Press Enter for next autoplay command, or type command:")
        }

        print("> ", terminator: "")
        if let input = readLine() {
            let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedInput.isEmpty {
                // Empty input means use autoplay
                state.lastInputWasEmpty = true
                return nil
            } else {
                // User provided a command
                state.lastInputWasEmpty = false
                if config.verbosity >= 1 {
                    print("[Manual] User command: \(input)")
                }
                return input
            }
        }
        state.lastInputWasEmpty = false
        return nil
    }

    /// Evaluate a counter condition
    private func evaluateCondition(name: String, operator op: String, value: Int) -> Bool {
        let counterValue = state.counters[name, default: 0]

        let result: Bool
        switch op {
        case ">": result = counterValue > value
        case "<": result = counterValue < value
        case ">=": result = counterValue >= value
        case "<=": result = counterValue <= value
        case "==": result = counterValue == value
        case "!=": result = counterValue != value
        default: result = false
        }

        if config.verbosity >= 2 {
            print("[Autoplay] Condition: \(name)(\(counterValue)) \(op) \(value) = \(result)")
        }

        return result
    }

    /// Check if manual mode is enabled
    var isManualMode: Bool {
        return config.isManualMode
    }

    /// Get verbosity level
    var verbosity: Int {
        return config.verbosity
    }

    /// Check if there are any active TRACK patterns that need pattern matching
    private func hasActiveTrackDirectives() -> Bool {
        return !state.activeTrackPatterns.isEmpty
    }

    /// Analyze diagnose command output and return wound level
    private func woundLevel(from diagnoseOutput: String) -> WoundLevel {
        // Check patterns in order from most specific to least specific
        // "serious wounds" must be checked before "serious wound" (singular)
        if diagnoseOutput.firstMatch(of: Self.perfectHealthRegex) != nil {
            return .healthy
        } else if diagnoseOutput.firstMatch(of: Self.seriousWoundsRegex) != nil {
            return .critical
        } else if diagnoseOutput.firstMatch(of: Self.severalWoundsRegex) != nil {
            return .several
        } else if diagnoseOutput.firstMatch(of: Self.seriousWoundRegex) != nil {
            return .serious
        } else if diagnoseOutput.firstMatch(of: Self.lightWoundRegex) != nil {
            return .light
        }
        return .healthy
    }
}

/// Autoplay terminal delegate that subclasses ZMachineTerminalDelegate for seamless integration
class AutoplayTerminalDelegate: ZMachineTerminalDelegate {
    private let manager: AutoplayInstructionManager

    init(manager: AutoplayInstructionManager, zmachine: ZMachine) {
        self.manager = manager
        super.init(zmachine: zmachine)
    }

    // MARK: - Output Handling

    override func didOutputText(_ text: String) {
        // Always process output for timing and pattern matching
        manager.processOutput(text)

        // Always call super to handle display
        super.didOutputText(text)
    }

    // MARK: - Input Handling

    override func readLineWrapper() -> String? {
        // Clear buffer and reset output length after all processing is complete
        defer {
            manager.state.outputBuffer = ""
            manager.state.lastOutputLength = 0
        }

        // In manual mode, handle user interaction for regular commands
        if manager.isManualMode {
            // Get user input directly without extra prompts
            if let userInput = readLine() {
                let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedInput.isEmpty {
                    // User typed something, return it directly
                    return userInput
                }
                // User pressed Enter (empty input), fall through to autoplay
                manager.state.lastInputWasEmpty = true
            }
        }

        // Get next autoplay command (regular commands, not queued)
        if let command = manager.getNextCommand() {
            // Apply timing delay before showing command (uses lastOutputLength)
            manager.applyTiming()

            // Position cursor back after the prompt and print command with newline
            // The prompt "> " is 2 characters, so position cursor at column 3
            print("\u{1B}[25;3H\(command)")
            return command
        }

        // No autoplay command available, fall back to normal input
        return super.readLineWrapper()
    }
}

/// Errors that can occur during instruction processing
public enum InstructionError: Error, LocalizedError {
    case parseError(String)
    case fileError(String)
    case executionError(String)

    public var errorDescription: String? {
        switch self {
        case .parseError(let message):
            return "Parse error: \(message)"
        case .fileError(let message):
            return "File error: \(message)"
        case .executionError(let message):
            return "Execution error: \(message)"
        }
    }
}
