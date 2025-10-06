/// Z-Machine Debugger - Interactive debugging and inspection
///
/// Provides debug commands for inspecting and manipulating VM state during execution.
/// The debugger is UI-agnostic and returns structured results that can be displayed
/// by any frontend (terminal, GUI, etc.).
import Foundation

public class ZMachineDebugger {
    /// Reference to the Z-Machine VM
    weak var zmachine: ZMachine?

    /// Whether debug mode is currently enabled
    public var isEnabled: Bool = false

    /// Breakpoints (PC addresses where execution should pause)
    private var breakpoints: Set<UInt32> = []

    /// Watchpoints (memory addresses to monitor for writes)
    private var watchpoints: Set<UInt32> = []

    /// Single-step mode flag
    private var singleStepMode: Bool = false

    /// Continue execution flag
    private var shouldContinue: Bool = false

    /// Initialize debugger attached to a Z-Machine instance
    public init(zmachine: ZMachine) {
        self.zmachine = zmachine
    }

    /// Process a debug command and return result
    ///
    /// Returns nil if not a debug command (doesn't start with @) or debugger is disabled.
    /// This allows the UI layer to check for debug commands before sending input to the game.
    ///
    /// - Parameter input: User input string (may or may not be a debug command)
    /// - Returns: DebugResult if a debug command was processed, nil otherwise
    public func processCommand(_ input: String) -> DebugResult? {
        guard isEnabled else { return nil }
        guard input.hasPrefix("@") else { return nil }

        guard let command = parseCommand(input) else {
            return .error("Unknown debug command: \(input)\nType @help for available commands")
        }

        return executeCommand(command)
    }

    /// Parse debug command string into DebugCommand enum
    private func parseCommand(_ input: String) -> DebugCommand? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("@") else { return nil }

        let parts = trimmed.dropFirst().split(separator: " ", omittingEmptySubsequences: true)
        guard !parts.isEmpty else { return nil }

        let command = String(parts[0]).lowercased()
        let args = parts.dropFirst().map(String.init)

        switch command {
        case "global":
            if args.isEmpty {
                return .global(index: nil)
            } else if let idx = Int(args[0]) {
                return .global(index: idx)
            }
        case "globals":
            return .globals
        case "setglobal":
            guard args.count >= 2,
                  let idx = Int(args[0]),
                  let val = parseValue(args[1]) else { return nil }
            return .setGlobal(index: idx, value: val)
        case "local":
            guard let idx = Int(args.first ?? "") else { return nil }
            return .local(index: idx)
        case "setlocal":
            guard args.count >= 2,
                  let idx = Int(args[0]),
                  let val = parseValue(args[1]) else { return nil }
            return .setLocal(index: idx, value: val)
        case "stack":
            return .stack
        case "peek":
            guard let addr = parseAddress(args.first ?? "") else { return nil }
            return .peek(address: addr)
        case "peekw":
            guard let addr = parseAddress(args.first ?? "") else { return nil }
            return .peekw(address: addr)
        case "dump":
            guard args.count >= 2,
                  let addr = parseAddress(args[0]),
                  let len = Int(args[1]) else { return nil }
            return .dump(address: addr, length: len)
        case "move", "mv":
            let cleanArgs = args.filter { $0.lowercased() != "to" }
            guard cleanArgs.count >= 2,
                  let obj = UInt16(cleanArgs[0]),
                  let parent = UInt16(cleanArgs[1]) else { return nil }
            return .move(object: obj, parent: parent)
        case "object", "obj":
            guard let num = UInt16(args.first ?? "") else { return nil }
            return .object(number: num)
        case "objects":
            return .objects
        case "tree":
            guard let num = UInt16(args.first ?? "") else { return nil }
            return .tree(object: num)
        case "find":
            let text = args.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            guard !text.isEmpty else { return nil }
            return .find(text: text)
        case "where":
            guard let num = UInt16(args.first ?? "") else { return nil }
            return .whereIs(object: num)
        case "attr":
            guard args.count >= 1,
                  let obj = UInt16(args[0]) else { return nil }
            if args.count == 1 {
                // Just display attributes
                return .attr(object: obj, attribute: nil, toggle: false)
            } else if let attr = UInt8(args[1]) {
                // Toggle specific attribute if present
                return .attr(object: obj, attribute: attr, toggle: true)
            }
            return nil
        case "prop":
            guard args.count >= 2,
                  let obj = UInt16(args[0]),
                  let prop = UInt8(args[1]) else { return nil }
            // Check if there's a value to set
            if args.count >= 3, let val = parseValue(args[2]) {
                return .prop(object: obj, property: prop, value: val)
            } else {
                return .prop(object: obj, property: prop, value: nil)
            }
        case "break", "b":
            if args.isEmpty {
                return .breakpoint(address: nil)  // List all breakpoints
            } else if let addr = parseAddress(args[0]) {
                return .breakpoint(address: addr)
            }
        case "step", "s":
            return .step
        case "continue", "c":
            return .continueExecution
        case "pc":
            return .pc
        case "backtrace", "bt":
            return .backtrace
        case "dictionary", "dict":
            if args.isEmpty {
                return .dictionary(word: nil)
            } else {
                let word = args.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return .dictionary(word: word)
            }
        case "version", "ver":
            return .version
        case "itable", "table":
            guard let addr = parseAddress(args.first ?? "") else { return nil }
            let count = args.count >= 2 ? Int(args[1]) : nil
            return .itable(address: addr, count: count)
        case "help":
            return .help
        default:
            return nil
        }

        return nil
    }

    /// Parse address string (hex with 0x prefix or decimal)
    private func parseAddress(_ input: String) -> UInt32? {
        if input.hasPrefix("0x") {
            return UInt32(input.dropFirst(2), radix: 16)
        } else {
            return UInt32(input)
        }
    }

    /// Parse value string (hex with 0x prefix, decimal, or signed decimal)
    private func parseValue(_ input: String) -> UInt16? {
        if input.hasPrefix("0x") {
            return UInt16(input.dropFirst(2), radix: 16)
        } else if input.hasPrefix("-") {
            // Parse as signed and convert to unsigned
            if let signed = Int16(input) {
                return UInt16(bitPattern: signed)
            }
            return nil
        } else {
            return UInt16(input)
        }
    }

    /// Execute a parsed debug command
    private func executeCommand(_ command: DebugCommand) -> DebugResult {
        guard let vm = zmachine else {
            return .error("No VM attached to debugger")
        }

        switch command {
        case .global(let index):
            return .success(formatGlobal(vm, index: index))
        case .globals:
            return .success(formatAllGlobals(vm))
        case .setGlobal(let index, let value):
            return executeSetGlobal(vm, index: index, value: value)
        case .local(let index):
            return .success(formatLocal(vm, index: index))
        case .setLocal(let index, let value):
            return executeSetLocal(vm, index: index, value: value)
        case .stack:
            return .success(formatStack(vm))
        case .peek(let address):
            return .success(formatPeek(vm, address: address))
        case .peekw(let address):
            return .success(formatPeekWord(vm, address: address))
        case .dump(let address, let length):
            return .success(formatDump(vm, address: address, length: length))
        case .move(let obj, let parent):
            return executeMoveObject(vm, object: obj, parent: parent)
        case .object(let num):
            return .success(formatObject(vm, number: num))
        case .objects:
            return .success(executeListObjects(vm))
        case .tree(let obj):
            return .success(executeTreeView(vm, object: obj))
        case .find(let text):
            return .success(executeFindObject(vm, text: text))
        case .whereIs(let obj):
            return .success(executeWhereObject(vm, object: obj))
        case .attr(let obj, let attr, let toggle):
            return executeAttr(vm, object: obj, attribute: attr, toggle: toggle)
        case .prop(let obj, let prop, let value):
            return executeProp(vm, object: obj, property: prop, value: value)
        case .breakpoint(let address):
            return executeBreakpoint(address)
        case .step:
            return executeStep()
        case .continueExecution:
            return executeContinue()
        case .pc:
            return executePC(vm)
        case .backtrace:
            return executeBacktrace(vm)
        case .dictionary(let word):
            return executeDictionary(vm, word: word)
        case .version:
            return executeVersion(vm)
        case .itable(let address, let count):
            return executeItable(vm, address: address, count: count)
        case .help:
            return .success(helpText)
        }
    }

    // MARK: - Variable Inspection Formatters

    private func formatGlobal(_ vm: ZMachine, index: Int?) -> String {
        if let idx = index {
            guard idx >= 0 && idx < 240 else {
                return "Error: Global index must be 0-239"
            }
            let value = vm.globals[idx]
            let signed = Int16(bitPattern: value)
            return "Global[\(idx)] = \(value) (0x\(String(value, radix: 16))) = \(signed) signed"
        } else {
            var output = "Non-zero globals:\n"
            for i in 0..<240 {
                let value = vm.globals[i]
                if value != 0 {
                    let signed = Int16(bitPattern: value)
                    output += "  [\(i)] = \(value) (\(signed))\n"
                }
            }
            return output
        }
    }

    private func formatAllGlobals(_ vm: ZMachine) -> String {
        var output = "All global variables:\n"
        for i in 0..<240 {
            if i % 8 == 0 {
                output += String(format: "\n[%3d-%3d]: ", i, min(i+7, 239))
            }
            let value = vm.globals[i]
            output += String(format: "%5d ", Int16(bitPattern: value))
        }
        return output + "\n"
    }

    private func formatLocal(_ vm: ZMachine, index: Int) -> String {
        guard !vm.locals.isEmpty else {
            return "Error: No local variables (not in a routine)"
        }
        guard index >= 0 && index < vm.locals.count else {
            return "Error: Local index must be 0-\(vm.locals.count - 1)"
        }

        let value = vm.locals[index]
        let signed = Int16(bitPattern: value)
        return "Local[\(index)] = \(value) (0x\(String(value, radix: 16))) = \(signed) signed"
    }

    private func formatStack(_ vm: ZMachine) -> String {
        let stack = vm.evaluationStack
        guard !stack.isEmpty else {
            return "Evaluation stack is empty"
        }

        var output = "Evaluation stack (top to bottom):\n"
        for (i, value) in stack.reversed().enumerated() {
            let unsigned = UInt16(bitPattern: value)
            output += "  [\(i)] = \(value) (0x\(String(unsigned, radix: 16)))\n"
        }
        return output
    }

    // MARK: - Variable Modification

    private func executeSetGlobal(_ vm: ZMachine, index: Int, value: UInt16) -> DebugResult {
        guard index >= 0 && index < 240 else {
            return .error("Error: Global index must be 0-239")
        }

        let oldValue = vm.globals[index]
        vm.globals[index] = value
        let signed = Int16(bitPattern: value)
        let oldSigned = Int16(bitPattern: oldValue)

        return .success("Global[\(index)] changed from \(oldValue) (\(oldSigned)) to \(value) (\(signed))")
    }

    private func executeSetLocal(_ vm: ZMachine, index: Int, value: UInt16) -> DebugResult {
        guard !vm.locals.isEmpty else {
            return .error("Error: No local variables (not in a routine)")
        }
        guard index >= 0 && index < vm.locals.count else {
            return .error("Error: Local index must be 0-\(vm.locals.count - 1)")
        }

        let oldValue = vm.locals[index]
        vm.locals[index] = value
        let signed = Int16(bitPattern: value)
        let oldSigned = Int16(bitPattern: oldValue)

        return .success("Local[\(index)] changed from \(oldValue) (\(oldSigned)) to \(value) (\(signed))")
    }

    // MARK: - Memory Inspection Formatters

    private func formatPeek(_ vm: ZMachine, address: UInt32) -> String {
        do {
            let byte = try vm.readByte(at: address)
            return "Byte at 0x\(String(address, radix: 16)) = \(byte) (0x\(String(byte, radix: 16)))"
        } catch {
            return "Error reading address 0x\(String(address, radix: 16)): \(error)"
        }
    }

    private func formatPeekWord(_ vm: ZMachine, address: UInt32) -> String {
        do {
            let word = try vm.readWord(at: address)
            let signed = Int16(bitPattern: word)
            return "Word at 0x\(String(address, radix: 16)) = \(word) (0x\(String(word, radix: 16))) = \(signed) signed"
        } catch {
            return "Error reading address 0x\(String(address, radix: 16)): \(error)"
        }
    }

    private func formatDump(_ vm: ZMachine, address: UInt32, length: Int) -> String {
        var output = "Memory dump at 0x\(String(address, radix: 16)):\n"

        for offset in 0..<length {
            if offset % 16 == 0 {
                output += String(format: "%08x: ", address + UInt32(offset))
            }

            do {
                let byte = try vm.readByte(at: address + UInt32(offset))
                output += String(format: "%02x ", byte)

                if offset % 16 == 15 || offset == length - 1 {
                    let lineStart = (offset / 16) * 16
                    let lineEnd = min(offset + 1, length)
                    output += String(repeating: "   ", count: 15 - (offset % 16))
                    output += " |"
                    for i in lineStart..<lineEnd {
                        let b = try? vm.readByte(at: address + UInt32(i))
                        if let b = b, b >= 32 && b <= 126 {
                            output += String(UnicodeScalar(b))
                        } else {
                            output += "."
                        }
                    }
                    output += "|\n"
                }
            } catch {
                output += "?? "
            }
        }

        return output
    }

    // MARK: - Object/Room Manipulation

    private func executeMoveObject(_ vm: ZMachine, object: UInt16, parent: UInt16) -> DebugResult {
        do {
            let objName = (try? vm.readObjectShortDescription(object)) ?? "object \(object)"
            let parentName = (try? vm.readObjectShortDescription(parent)) ?? "object \(parent)"

            try vm.objectTree.moveObject(object, toParent: parent)

            return .success("Moved '\(objName)' to '\(parentName)'")
        } catch {
            return .error("Error moving object: \(error)")
        }
    }

    private func formatObject(_ vm: ZMachine, number: UInt16) -> String {
        guard let obj = vm.objectTree.getObject(number) else {
            return "Error: Object \(number) does not exist"
        }

        let name = (try? vm.readObjectShortDescription(number)) ?? "Unknown"
        var output = "Object \(number): '\(name)'\n"
        output += "  Parent:  \(obj.parent) (\((try? vm.readObjectShortDescription(obj.parent)) ?? "none"))\n"
        output += "  Sibling: \(obj.sibling) (\((try? vm.readObjectShortDescription(obj.sibling)) ?? "none"))\n"
        output += "  Child:   \(obj.child) (\((try? vm.readObjectShortDescription(obj.child)) ?? "none"))\n"

        var attrs: [Int] = []
        for i in 0..<32 {
            if obj.hasAttribute(UInt8(i)) {
                attrs.append(i)
            }
        }
        if !attrs.isEmpty {
            output += "  Attributes: \(attrs.map(String.init).joined(separator: ", "))\n"
        }

        output += "  Properties:\n"
        for (propNum, propValue) in obj.getAllProperties().sorted(by: { $0.key > $1.key }) {
            output += "    [\(propNum)] = \(propValue)\n"
        }

        return output
    }

    private func executeFindObject(_ vm: ZMachine, text: String) -> String {
        guard let matches = vm.objectTree.searchObjects(containing: text) else {
            return "Error: Debug mode not properly initialized on object tree"
        }

        if matches.isEmpty {
            return "No objects found matching '\(text)'"
        }

        var output = "Objects matching '\(text)':\n"
        for (num, name) in matches.prefix(20) {
            if let obj = vm.objectTree.getObject(num) {
                let location = obj.parent > 0 ?
                    " (in \((try? vm.readObjectShortDescription(obj.parent)) ?? "?"))" :
                    " (nowhere)"
                output += "  [\(num)] \(name)\(location)\n"
            }
        }

        if matches.count > 20 {
            output += "  ... and \(matches.count - 20) more\n"
        }

        return output
    }

    private func executeWhereObject(_ vm: ZMachine, object: UInt16) -> String {
        guard let obj = vm.objectTree.getObject(object) else {
            return "Error: Object \(object) does not exist"
        }

        let name = (try? vm.readObjectShortDescription(object)) ?? "object \(object)"

        if obj.parent == 0 {
            return "'\(name)' is not in any container (parent = 0)"
        }

        var location = ""
        var current = obj.parent
        var depth = 0

        while current != 0 && depth < 10 {
            let parentName = (try? vm.readObjectShortDescription(current)) ?? "object \(current)"
            location += parentName

            if let parent = vm.objectTree.getObject(current) {
                current = parent.parent
                if current != 0 {
                    location += " -> "
                }
            } else {
                break
            }
            depth += 1
        }

        return "'\(name)' is in: \(location)"
    }

    private func executeListObjects(_ vm: ZMachine) -> String {
        let allObjects = vm.objectTree.getAllObjectNumbers()

        guard !allObjects.isEmpty else {
            return "No objects found in object tree"
        }

        var output = "All objects (\(allObjects.count) total):\n"

        for objNum in allObjects {
            if let obj = vm.objectTree.getObject(objNum) {
                let name = (try? vm.readObjectShortDescription(objNum)) ?? "object \(objNum)"
                let location = obj.parent > 0 ?
                    " (in \((try? vm.readObjectShortDescription(obj.parent)) ?? "?"))" :
                    " (nowhere)"
                output += "  [\(objNum)] \(name)\(location)\n"
            }
        }

        return output
    }

    private func executeTreeView(_ vm: ZMachine, object: UInt16) -> String {
        guard vm.objectTree.getObject(object) != nil else {
            return "Error: Object \(object) does not exist"
        }

        let name = (try? vm.readObjectShortDescription(object)) ?? "object \(object)"
        var output = "Object tree for [\(object)] \(name):\n"

        // Display the object and its children recursively
        output += formatTreeNode(vm, object: object, depth: 0)

        return output
    }

    private func formatTreeNode(_ vm: ZMachine, object: UInt16, depth: Int) -> String {
        guard let obj = vm.objectTree.getObject(object) else {
            return ""
        }

        let indent = String(repeating: "  ", count: depth)
        let name = (try? vm.readObjectShortDescription(object)) ?? "object \(object)"
        var output = "\(indent)[\(object)] \(name)\n"

        // Recursively display children
        var childNum = obj.child
        var visited: Set<UInt16> = []

        while childNum != 0 {
            // Prevent infinite loops from circular references
            guard !visited.contains(childNum) else { break }
            visited.insert(childNum)

            output += formatTreeNode(vm, object: childNum, depth: depth + 1)

            guard let child = vm.objectTree.getObject(childNum) else { break }
            childNum = child.sibling
        }

        return output
    }

    private func executeAttr(_ vm: ZMachine, object: UInt16, attribute: UInt8?, toggle: Bool) -> DebugResult {
        guard let obj = vm.objectTree.getObject(object) else {
            return .error("Error: Object \(object) does not exist")
        }

        let name = (try? vm.readObjectShortDescription(object)) ?? "object \(object)"
        let maxAttr = vm.version.rawValue >= 4 ? 47 : 31

        if let attr = attribute {
            // Toggle or display specific attribute
            guard attr <= maxAttr else {
                return .error("Error: Attribute \(attr) out of range (0-\(maxAttr))")
            }

            if toggle {
                // Toggle the attribute
                let currentValue = vm.objectTree.getAttribute(object, attribute: attr)
                do {
                    try vm.objectTree.setAttribute(object, attribute: attr, value: !currentValue)
                    let newValue = !currentValue
                    return .success("Object [\(object)] '\(name)' attribute \(attr): \(currentValue ? "SET" : "CLEAR") -> \(newValue ? "SET" : "CLEAR")")
                } catch {
                    return .error("Error toggling attribute: \(error)")
                }
            } else {
                // Just display attribute status
                let isSet = vm.objectTree.getAttribute(object, attribute: attr)
                return .success("Object [\(object)] '\(name)' attribute \(attr): \(isSet ? "SET" : "CLEAR")")
            }
        } else {
            // Display all set attributes
            var attrs: [Int] = []
            for i in 0...maxAttr {
                if obj.hasAttribute(UInt8(i)) {
                    attrs.append(Int(i))
                }
            }

            if attrs.isEmpty {
                return .success("Object [\(object)] '\(name)' has no attributes set")
            } else {
                return .success("Object [\(object)] '\(name)' attributes: \(attrs.map(String.init).joined(separator: ", "))")
            }
        }
    }

    private func executeProp(_ vm: ZMachine, object: UInt16, property: UInt8, value: UInt16?) -> DebugResult {
        guard vm.objectTree.getObject(object) != nil else {
            return .error("Error: Object \(object) does not exist")
        }

        let name = (try? vm.readObjectShortDescription(object)) ?? "object \(object)"
        let maxProp = vm.version.rawValue >= 4 ? 63 : 31

        guard property > 0 && property <= maxProp else {
            return .error("Error: Property \(property) out of range (1-\(maxProp))")
        }

        if let newValue = value {
            // Set property value
            do {
                let oldValue = vm.objectTree.getProperty(object, property: property)
                try vm.objectTree.setProperty(object, property: property, value: newValue)
                return .success("Object [\(object)] '\(name)' property \(property): \(oldValue) -> \(newValue)")
            } catch {
                return .error("Error setting property: \(error)")
            }
        } else {
            // Display property value
            let propValue = vm.objectTree.getProperty(object, property: property)
            let signed = Int16(bitPattern: propValue)
            return .success("Object [\(object)] '\(name)' property \(property) = \(propValue) (0x\(String(propValue, radix: 16))) = \(signed) signed")
        }
    }

    // MARK: - Execution Control

    private func executeBreakpoint(_ address: UInt32?) -> DebugResult {
        if let addr = address {
            // Toggle breakpoint at address
            if breakpoints.contains(addr) {
                breakpoints.remove(addr)
                return .success("Breakpoint removed at 0x\(String(addr, radix: 16))")
            } else {
                breakpoints.insert(addr)
                return .success("Breakpoint set at 0x\(String(addr, radix: 16))")
            }
        } else {
            // List all breakpoints
            if breakpoints.isEmpty {
                return .success("No breakpoints set")
            } else {
                var output = "Breakpoints:\n"
                for addr in breakpoints.sorted() {
                    output += "  0x\(String(addr, radix: 16)) (\(addr))\n"
                }
                return .success(output)
            }
        }
    }

    private func executeStep() -> DebugResult {
        singleStepMode = true
        shouldContinue = true
        return .success("Step: Executing next instruction...")
    }

    private func executeContinue() -> DebugResult {
        singleStepMode = false
        shouldContinue = true
        return .success("Continue: Resuming execution...")
    }

    private func executePC(_ vm: ZMachine) -> DebugResult {
        let pc = vm.programCounter
        return .success("Program Counter (PC) = 0x\(String(pc, radix: 16)) (\(pc))")
    }

    private func executeBacktrace(_ vm: ZMachine) -> DebugResult {
        let stack = vm.callStack

        if stack.isEmpty {
            return .success("Call stack is empty (at top level)")
        }

        var output = "Call Stack (most recent first):\n"
        for (index, frame) in stack.enumerated().reversed() {
            output += "  #\(stack.count - index - 1): PC=0x\(String(frame.returnPC, radix: 16))"
            output += ", locals=\(frame.localCount)"
            output += ", stack_base=\(frame.evaluationStackBase)\n"
        }

        output += "\nCurrent PC: 0x\(String(vm.programCounter, radix: 16))"
        return .success(output)
    }

    /// Check if execution should pause at current PC
    public func shouldBreak(at pc: UInt32) -> Bool {
        return breakpoints.contains(pc) || singleStepMode
    }

    /// Check if debugger wants to continue execution
    public func wantsToContinue() -> Bool {
        let result = shouldContinue
        if singleStepMode {
            shouldContinue = false  // Reset after single step
        }
        return result
    }

    // MARK: - Game State Inspection

    private func executeDictionary(_ vm: ZMachine, word: String?) -> DebugResult {
        if let searchWord = word {
            // Look up specific word in dictionary
            let truncatedWord = String(searchWord.prefix(vm.version.rawValue >= 4 ? 9 : 6).lowercased())

            if let entry = vm.dictionary.lookup(truncatedWord) {
                var output = "Dictionary entry for '\(searchWord)':\n"
                output += "  Address: 0x\(String(entry.address, radix: 16))\n"

                // Show encoded word as hex bytes
                let encodedBytes = entry.encodedWord.map { String(format: "0x%02X", $0) }.joined(separator: " ")
                output += "  Encoded: \(encodedBytes)\n"

                // Show metadata (flags) if present
                if !entry.metadata.isEmpty {
                    let metadataBytes = entry.metadata.map { String(format: "0x%02X", $0) }.joined(separator: " ")
                    output += "  Metadata: \(metadataBytes)\n"
                }

                return .success(output)
            } else {
                return .success("Word '\(searchWord)' not found in dictionary")
            }
        } else {
            // Show dictionary statistics
            let entryCount = vm.dictionary.entryCount
            let wordLength = vm.version.rawValue >= 4 ? 9 : 6
            var output = "Dictionary Information:\n"
            output += "  Entry count: \(entryCount)\n"
            output += "  Word length: \(wordLength) characters\n"
            output += "  Entry size: \(vm.dictionary.entryLength) bytes\n"
            output += "\nUse @dictionary <word> to look up a specific word"
            return .success(output)
        }
    }

    private func executeVersion(_ vm: ZMachine) -> DebugResult {
        var output = "Z-Machine Information:\n"
        output += "  Version: \(vm.version.rawValue)\n"
        output += "  Story file size: \(vm.storyData.count) bytes\n"
        output += "  Static memory base: 0x\(String(vm.header.staticMemoryBase, radix: 16)) (\(vm.header.staticMemoryBase))\n"
        output += "  High memory base: 0x\(String(vm.header.highMemoryBase, radix: 16)) (\(vm.header.highMemoryBase))\n"
        output += "  Initial PC: 0x\(String(vm.header.initialPC, radix: 16))\n"
        output += "  Serial number: \(vm.header.serialNumber)\n"
        output += "  Checksum: 0x\(String(vm.header.checksum, radix: 16, uppercase: true))\n"
        output += "  Dictionary at: 0x\(String(vm.header.dictionaryAddress, radix: 16))\n"
        output += "  Object table at: 0x\(String(vm.header.objectTableAddress, radix: 16))\n"
        output += "  Global table at: 0x\(String(vm.header.globalTableAddress, radix: 16))\n"
        return .success(output)
    }

    private func executeItable(_ vm: ZMachine, address: UInt32, count: Int?) -> DebugResult {
        do {
            // Read table length from first word if count not specified
            let tableLength: Int
            if let specifiedCount = count {
                tableLength = specifiedCount
            } else {
                let lengthWord = try vm.readWord(at: address)
                tableLength = Int(lengthWord)
            }

            guard tableLength >= 0 && tableLength <= 10000 else {
                return .error("Table length \(tableLength) out of reasonable range (0-10000)")
            }

            var output = "ITABLE at 0x\(String(address, radix: 16)):\n"
            output += "  Length: \(tableLength) entries\n\n"

            // Display table contents
            let dataStart = count != nil ? address : address + 2 // Skip length word if reading from table
            for i in 0..<min(tableLength, 100) { // Limit to 100 entries for display
                let entryAddress = dataStart + UInt32(i * 2)
                let value = try vm.readWord(at: entryAddress)
                let signed = Int16(bitPattern: value)

                output += String(format: "  [%3d] = %5d (0x%04X) = %6d signed\n",
                               i, value, value, signed)
            }

            if tableLength > 100 {
                output += "  ... (\(tableLength - 100) more entries)\n"
            }

            return .success(output)
        } catch {
            return .error("Error reading table at 0x\(String(address, radix: 16)): \(error)")
        }
    }

    // MARK: - Help Text

    private var helpText: String {
        return """
        Z-Machine Debugger Commands:

        Variable Inspection:
          @global [index]     - Show global variable (or all non-zero if no index)
          @globals            - Show all 240 global variables
          @local <index>      - Show local variable
          @stack              - Show evaluation stack

        Variable Modification:
          @setglobal <idx> <value> - Set global variable
          @setlocal <idx> <value>  - Set local variable

        Memory Inspection:
          @peek <addr>        - Read byte at address (hex: 0x1234 or decimal)
          @peekw <addr>       - Read word at address
          @dump <addr> <len>  - Hex dump memory region

        Object/Room Manipulation:
          @move <obj> <dest>  - Move object to destination (also: @mv)
          @object <number>    - Show object details (also: @obj)
          @objects            - List all objects with locations
          @tree <object>      - Display object tree hierarchy
          @find <text>        - Search for objects by name
          @where <object>     - Show object's location chain
          @attr <obj> [attr]  - Display/toggle object attribute
          @prop <obj> <prop> [value] - Display/set object property

        Execution Control:
          @break [addr]       - Set/remove breakpoint at address (also: @b)
          @break              - List all breakpoints
          @step               - Execute single instruction (also: @s)
          @continue           - Resume execution (also: @c)
          @pc                 - Show program counter
          @backtrace          - Show call stack (also: @bt)

        Game State Inspection:
          @dictionary [word]  - Show dictionary info or look up word (also: @dict)
          @version            - Show Z-Machine and story file info (also: @ver)
          @itable <addr> [count] - Display ITABLE contents (also: @table)

        Help:
          @help               - Show this help message

        Examples:
          @global             - Show non-zero globals
          @global 0           - Show HERE (current room) in Zork I/II/III
          @setglobal 0 42     - Set current room to object 42
          @find adventurer    - Find the player object (e.g., 'adventurer' or 'cretin')
          @move 40 137        - Move object 40 to room 137
          @objects            - List all objects
          @tree 137           - Show tree for object 137
          @find lamp          - Search for objects with "lamp" in name
          @where 123          - Show location of object 123
          @attr 59            - Show all attributes for object 59
          @attr 59 5          - Toggle attribute 5 on object 59
          @prop 59 15         - Show property 15 of object 59
          @prop 59 15 100     - Set property 15 of object 59 to 100

        Teleportation Workflow:
          1. @find adventurer      - Find player object number (varies by game)
          2. @move <player> <room> - Move player to room
          3. @setglobal 0 <room>   - Update HERE to match

        Timer/Interrupt Inspection:
          1. Find C-TABLE global (alphabetically sorted, typically near 'C')
          2. @global <index>       - Get C-TABLE address
          3. @itable <address>     - Display interrupt table contents

        Note: Global variable indices are game-specific and determined by
        alphabetical sorting of variable names during compilation.

        Zork I/II/III Key Globals (alphabetically sorted):
          Global 0 (HERE)     - Current room object number (H comes first)
          Use @global or @globals to find other variable indices
        """
    }
}
