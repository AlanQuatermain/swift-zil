/// Debug Command Types for Z-Machine Debugger

public enum DebugCommand {
    // Variable inspection
    case global(index: Int?)
    case globals
    case local(index: Int)
    case stack

    // Variable modification
    case setGlobal(index: Int, value: UInt16)
    case setLocal(index: Int, value: UInt16)

    // Memory inspection
    case peek(address: UInt32)
    case peekw(address: UInt32)
    case dump(address: UInt32, length: Int)

    // Object/Room manipulation
    case move(object: UInt16, parent: UInt16)
    case object(number: UInt16)
    case objects
    case tree(object: UInt16)
    case find(text: String)
    case whereIs(object: UInt16)
    case attr(object: UInt16, attribute: UInt8?, toggle: Bool)
    case prop(object: UInt16, property: UInt8, value: UInt16?)

    // Execution control
    case breakpoint(address: UInt32?)  // nil = list all breakpoints
    case step
    case continueExecution
    case pc
    case backtrace

    // Game state inspection
    case dictionary(word: String?)  // nil = show dictionary info
    case version
    case itable(address: UInt32, count: Int?)  // Display ITABLE contents (nil = read length from table)

    // Help
    case help
}

public enum DebugResult {
    case success(String)
    case error(String)
}
