/// Z-Machine Window Management System - Handles multiple windows for v4+ versions
import Foundation

// MARK: - Window Protocol and Types

/// Text style flags for Z-Machine text formatting
public struct TextStyle: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let roman     = TextStyle([])           // Normal text
    public static let reverse   = TextStyle(rawValue: 1)  // Reverse video
    public static let bold      = TextStyle(rawValue: 2)  // Bold text
    public static let italic    = TextStyle(rawValue: 4)  // Italic text
    public static let fixedPitch = TextStyle(rawValue: 8) // Fixed-width font
}

/// Z-Machine color mapping
public enum ZMachineColor: UInt8, CaseIterable, Sendable {
    case current = 0        // Use current interpreter color
    case `default` = 1      // Use default system color
    case black = 2          // Black
    case red = 3            // Red
    case green = 4          // Green
    case yellow = 5         // Yellow
    case blue = 6           // Blue
    case magenta = 7        // Magenta
    case cyan = 8           // Cyan
    case white = 9          // White
    case grey = 10          // Grey (v5+)
    case lightGrey = 11     // Light Grey (v5+)
    case mediumGrey = 12    // Medium Grey (v5+)
    case darkGrey = 13      // Dark Grey (v5+)
    // Reserved: 14-15

    /// Standard RGB values for Z-Machine colors
    public var rgb: (red: UInt8, green: UInt8, blue: UInt8) {
        switch self {
        case .current, .default:
            return (255, 255, 255)  // White default
        case .black:
            return (0, 0, 0)
        case .red:
            return (255, 0, 0)
        case .green:
            return (0, 255, 0)
        case .yellow:
            return (255, 255, 0)
        case .blue:
            return (0, 0, 255)
        case .magenta:
            return (255, 0, 255)
        case .cyan:
            return (0, 255, 255)
        case .white:
            return (255, 255, 255)
        case .grey:
            return (128, 128, 128)
        case .lightGrey:
            return (192, 192, 192)
        case .mediumGrey:
            return (96, 96, 96)
        case .darkGrey:
            return (64, 64, 64)
        }
    }

    /// Create from Z-Machine color code
    public static func from(_ code: UInt8) -> ZMachineColor {
        return ZMachineColor(rawValue: min(code, 13)) ?? .default
    }
}

/// Window type enumeration
public enum WindowType: Sendable {
    case text        // Standard scrolling text window
    case status      // Fixed upper status window
    case graphics    // Graphics window (v6+)
    case input       // Input window (v6+)
}

/// Window properties for window creation and management
public struct WindowProperties: Sendable {
    public let type: WindowType
    public let scrolling: Bool
    public let width: Int
    public let height: Int
    public let foregroundColor: ZMachineColor
    public let backgroundColor: ZMachineColor

    public init(type: WindowType, scrolling: Bool = true, width: Int = 80, height: Int = 25,
                foregroundColor: ZMachineColor = .default, backgroundColor: ZMachineColor = .default) {
        self.type = type
        self.scrolling = scrolling
        self.width = width
        self.height = height
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
}

/// Protocol for individual Z-Machine windows
public protocol Window: AnyObject {
    /// Window identification
    var number: Int { get }
    var type: WindowType { get }

    /// Window dimensions
    var width: Int { get set }
    var height: Int { get set }

    /// Cursor position (1-based coordinates)
    var cursorLine: Int { get set }
    var cursorColumn: Int { get set }

    /// Text properties
    var currentStyle: TextStyle { get set }
    var foregroundColor: ZMachineColor { get set }
    var backgroundColor: ZMachineColor { get set }

    /// Window behavior
    var scrolling: Bool { get }

    /// Text output methods
    func printText(_ text: String)
    func printCharacter(_ character: Character)

    /// Window operations
    func clear()
    func clearLine(_ line: Int)
    func setCursor(line: Int, column: Int)

    /// Style management
    func setStyle(_ style: TextStyle)
    func setColors(foreground: ZMachineColor, background: ZMachineColor)
}

// MARK: - Concrete Window Implementations

/// Standard scrolling text window implementation
public class TextWindow: Window {
    public let number: Int
    public let type: WindowType = .text

    public var width: Int
    public var height: Int
    public var cursorLine: Int = 1
    public var cursorColumn: Int = 1
    public var currentStyle: TextStyle = .roman
    public var foregroundColor: ZMachineColor = .default
    public var backgroundColor: ZMachineColor = .default
    public let scrolling: Bool = true

    /// Text buffer storing window content
    private var textBuffer: [[Character]] = []
    private var styleBuffer: [[TextStyle]] = []

    /// Reference to window manager for output delegation
    private weak var windowManager: WindowManager?

    public init(number: Int, width: Int = 80, height: Int = 25, windowManager: WindowManager?) {
        self.number = number
        self.width = width
        self.height = height
        self.windowManager = windowManager
        initializeBuffers()
    }

    private func initializeBuffers() {
        textBuffer = Array(repeating: Array(repeating: " ", count: width), count: height)
        styleBuffer = Array(repeating: Array(repeating: .roman, count: width), count: height)
    }

    public func printText(_ text: String) {
        for character in text {
            printCharacter(character)
        }
    }

    public func printCharacter(_ character: Character) {
        // Handle special characters
        if character == "\n" {
            newLine()
            return
        }

        // Bounds check
        guard cursorLine >= 1 && cursorLine <= height &&
              cursorColumn >= 1 && cursorColumn <= width else {
            return
        }

        // Store character and style
        let lineIndex = cursorLine - 1
        let columnIndex = cursorColumn - 1
        textBuffer[lineIndex][columnIndex] = character
        styleBuffer[lineIndex][columnIndex] = currentStyle

        // Advance cursor
        cursorColumn += 1
        if cursorColumn > width {
            newLine()
        }

        // Notify delegate of output with full style and color information
        windowManager?.notifyStyledOutput(character: character, window: number,
                                          style: currentStyle,
                                          foreground: foregroundColor,
                                          background: backgroundColor)
    }

    private func newLine() {
        cursorLine += 1
        cursorColumn = 1

        // Handle scrolling
        if scrolling && cursorLine > height {
            scrollUp()
            cursorLine = height
        }
    }

    private func scrollUp() {
        // Move all lines up by one
        for i in 1..<height {
            textBuffer[i-1] = textBuffer[i]
            styleBuffer[i-1] = styleBuffer[i]
        }
        // Clear bottom line
        textBuffer[height-1] = Array(repeating: " ", count: width)
        styleBuffer[height-1] = Array(repeating: .roman, count: width)
    }

    public func clear() {
        initializeBuffers()
        cursorLine = 1
        cursorColumn = 1
        windowManager?.notifyWindowCleared(number)
    }

    public func clearLine(_ line: Int) {
        guard line >= 1 && line <= height else { return }

        let lineIndex = line - 1
        for col in cursorColumn-1..<width {
            textBuffer[lineIndex][col] = " "
            styleBuffer[lineIndex][col] = .roman
        }

        windowManager?.notifyLineClear(window: number, line: line)
    }

    public func setCursor(line: Int, column: Int) {
        // Validate bounds
        cursorLine = max(1, min(line, height))
        cursorColumn = max(1, min(column, width))

        windowManager?.notifyCursorMove(window: number, line: cursorLine, column: cursorColumn)
    }

    public func setStyle(_ style: TextStyle) {
        currentStyle = style
        windowManager?.delegate?.styleWasSet(window: number, style: style)
    }

    public func setColors(foreground: ZMachineColor, background: ZMachineColor) {
        self.foregroundColor = foreground
        self.backgroundColor = background
        windowManager?.delegate?.colorsWereSet(window: number, foreground: foreground, background: background)
    }
}

/// Fixed upper status window implementation
public class StatusWindow: Window {
    public let number: Int = 1  // Window 1 is the upper status window
    public let type: WindowType = .status

    public var width: Int
    public var height: Int
    public var cursorLine: Int = 1
    public var cursorColumn: Int = 1
    public var currentStyle: TextStyle = .roman
    public var foregroundColor: ZMachineColor = .default
    public var backgroundColor: ZMachineColor = .default
    public let scrolling: Bool = false  // Status window never scrolls

    /// Text buffer storing window content
    private var textBuffer: [[Character]] = []
    private var styleBuffer: [[TextStyle]] = []

    /// Reference to window manager for output delegation
    private weak var windowManager: WindowManager?

    public init(width: Int = 80, height: Int = 1, windowManager: WindowManager?) {
        self.width = width
        self.height = height
        self.windowManager = windowManager
        initializeBuffers()
    }

    private func initializeBuffers() {
        textBuffer = Array(repeating: Array(repeating: " ", count: width), count: height)
        styleBuffer = Array(repeating: Array(repeating: .roman, count: width), count: height)
    }

    public func printText(_ text: String) {
        for character in text {
            printCharacter(character)
        }
    }

    public func printCharacter(_ character: Character) {
        // Handle special characters - status window treats newline as move to next line
        if character == "\n" {
            cursorLine = min(cursorLine + 1, height)
            cursorColumn = 1
            return
        }

        // Bounds check
        guard cursorLine >= 1 && cursorLine <= height &&
              cursorColumn >= 1 && cursorColumn <= width else {
            return
        }

        // Store character and style
        let lineIndex = cursorLine - 1
        let columnIndex = cursorColumn - 1
        textBuffer[lineIndex][columnIndex] = character
        styleBuffer[lineIndex][columnIndex] = currentStyle

        // Advance cursor (no wrapping in status window)
        cursorColumn = min(cursorColumn + 1, width + 1)

        // Notify delegate of output with full style and color information
        windowManager?.notifyStyledOutput(character: character, window: number,
                                          style: currentStyle,
                                          foreground: foregroundColor,
                                          background: backgroundColor)
    }

    public func clear() {
        initializeBuffers()
        cursorLine = 1
        cursorColumn = 1
        windowManager?.notifyWindowCleared(number)
    }

    public func clearLine(_ line: Int) {
        guard line >= 1 && line <= height else { return }

        let lineIndex = line - 1
        for col in cursorColumn-1..<width {
            textBuffer[lineIndex][col] = " "
            styleBuffer[lineIndex][col] = .roman
        }

        windowManager?.notifyLineClear(window: number, line: line)
    }

    public func setCursor(line: Int, column: Int) {
        // Validate bounds - status window allows precise cursor positioning
        cursorLine = max(1, min(line, height))
        cursorColumn = max(1, min(column, width))

        windowManager?.notifyCursorMove(window: number, line: cursorLine, column: cursorColumn)
    }

    public func setStyle(_ style: TextStyle) {
        currentStyle = style
        windowManager?.delegate?.styleWasSet(window: number, style: style)
    }

    public func setColors(foreground: ZMachineColor, background: ZMachineColor) {
        self.foregroundColor = foreground
        self.backgroundColor = background
        windowManager?.delegate?.colorsWereSet(window: number, foreground: foreground, background: background)
    }
}

// MARK: - Window Manager

/// Central manager for Z-Machine multiple window system
public class WindowManager {
    /// Array of active windows indexed by window number
    private var windows: [Int: Window] = [:]

    /// Current active window number
    public private(set) var currentWindow: Int = 0  // Start with main window (window 0)

    /// Default window properties
    private var defaultProperties = WindowProperties(type: .text)

    /// Delegate for window operations
    public weak var delegate: WindowDelegate?

    /// Z-Machine version for feature availability
    private let version: ZMachineVersion

    public init(version: ZMachineVersion) {
        self.version = version
        initializeDefaultWindows()
    }

    /// Initialize default window configuration for the Z-Machine version
    private func initializeDefaultWindows() {
        // All versions have the main text window (window 0)
        let mainWindow = TextWindow(number: 0, windowManager: self)
        windows[0] = mainWindow

        // v4+ versions support upper status window (window 1), but it's created by SPLIT_WINDOW
    }

    /// Get window by number
    public func getWindow(_ number: Int) -> Window? {
        return windows[number]
    }

    /// Get current active window
    public func getCurrentWindow() -> Window? {
        return windows[currentWindow]
    }

    /// Switch to specified window
    public func setCurrentWindow(_ number: Int) {
        // Validate window exists and version supports it
        if windows[number] != nil || (version.rawValue >= 4 && number >= 0 && number <= 1) {
            currentWindow = number
            delegate?.windowBecameActive(number)
        }
    }

    /// Create or resize upper window (SPLIT_WINDOW instruction)
    public func splitWindow(lines: Int) throws {
        guard version.rawValue >= 4 else {
            throw RuntimeError.unsupportedOperation("SPLIT_WINDOW not supported in version \(version.rawValue)",
                                                  location: SourceLocation.unknown)
        }

        if lines == 0 {
            // Remove upper window (window 1)
            if windows[1] != nil {
                windows.removeValue(forKey: 1)
                delegate?.windowWasDestroyed(1)
            }
        } else {
            // Create or resize upper window (window 1)
            if let existingWindow = windows[1] as? StatusWindow {
                // Resize existing window
                existingWindow.height = lines
                delegate?.windowWasResized(1, width: existingWindow.width, height: lines)
            } else {
                // Create new status window (window 1)
                let statusWindow = StatusWindow(height: lines, windowManager: self)
                windows[1] = statusWindow
                delegate?.windowWasCreated(1, type: .status, properties: WindowProperties(type: .status, scrolling: false, height: lines))
            }

            // Set cursor to (1,1) in upper window after split
            windows[1]?.setCursor(line: 1, column: 1)
        }
    }

    /// Clear specified window (ERASE_WINDOW instruction)
    public func eraseWindow(_ windowNumber: Int) {
        if windowNumber == -1 {
            // Clear current window
            getCurrentWindow()?.clear()
        } else if windowNumber == -2 {
            // Clear all windows
            for window in windows.values {
                window.clear()
            }
        } else if let window = windows[windowNumber] {
            // Clear specific window
            window.clear()
        }
    }

    /// Clear line in current window (ERASE_LINE instruction)
    public func eraseLine(_ value: Int) {
        if value == 1 {
            // Clear from cursor to end of current line
            getCurrentWindow()?.clearLine(getCurrentWindow()?.cursorLine ?? 1)
        }
    }

    /// Set cursor position in current window (SET_CURSOR instruction)
    public func setCursor(line: Int, column: Int) throws {
        guard let window = getCurrentWindow() else {
            throw RuntimeError.invalidMemoryAccess(-1, location: SourceLocation.unknown)
        }

        // SET_CURSOR works in all windows per Z-Machine specification
        // In scrolling windows, cursor positioning may have different effects
        window.setCursor(line: line, column: column)
    }

    /// Output text to current window
    public func outputText(_ text: String) {
        getCurrentWindow()?.printText(text)
    }

    /// Output character to current window
    public func outputCharacter(_ character: Character) {
        getCurrentWindow()?.printCharacter(character)
    }

    // MARK: - Delegate Notifications

    internal func notifyOutput(character: Character, window: Int, style: TextStyle) {
        delegate?.didOutputCharacter(character, toWindow: window, withStyle: style)
    }

    internal func notifyStyledOutput(character: Character, window: Int, style: TextStyle,
                                     foreground: ZMachineColor, background: ZMachineColor) {
        delegate?.didOutputStyledCharacter(character, toWindow: window, withStyle: style,
                                           foregroundColor: foreground, backgroundColor: background)
    }

    internal func notifyWindowCleared(_ window: Int) {
        delegate?.windowWasCleared(window)
    }

    internal func notifyLineClear(window: Int, line: Int) {
        delegate?.lineWasCleared(window: window, line: line)
    }

    internal func notifyCursorMove(window: Int, line: Int, column: Int) {
        delegate?.cursorWasMoved(window: window, line: line, column: column)
    }
}

// MARK: - Window Delegate Protocol

/// Delegate protocol for handling window operations and output
public protocol WindowDelegate: AnyObject {
    /// Window lifecycle events
    func windowWasCreated(_ number: Int, type: WindowType, properties: WindowProperties)
    func windowWasDestroyed(_ number: Int)
    func windowWasResized(_ number: Int, width: Int, height: Int)
    func windowBecameActive(_ number: Int)

    /// Window content events
    func didOutputCharacter(_ character: Character, toWindow window: Int, withStyle style: TextStyle)
    func didOutputStyledCharacter(_ character: Character, toWindow window: Int,
                                  withStyle style: TextStyle,
                                  foregroundColor: ZMachineColor,
                                  backgroundColor: ZMachineColor)
    func windowWasCleared(_ number: Int)
    func lineWasCleared(window: Int, line: Int)
    func cursorWasMoved(window: Int, line: Int, column: Int)

    /// Style and color change events
    func styleWasSet(window: Int, style: TextStyle)
    func colorsWereSet(window: Int, foreground: ZMachineColor, background: ZMachineColor)

    /// Window queries (for @get_cursor, etc.)
    func getCursorPosition(for window: Int) -> (line: Int, column: Int)
    func getWindowSize(for window: Int) -> (width: Int, height: Int)
}

/// Default implementation of WindowDelegate for backward compatibility
public extension WindowDelegate {
    func windowWasCreated(_ number: Int, type: WindowType, properties: WindowProperties) {}
    func windowWasDestroyed(_ number: Int) {}
    func windowWasResized(_ number: Int, width: Int, height: Int) {}
    func windowBecameActive(_ number: Int) {}

    func didOutputCharacter(_ character: Character, toWindow window: Int, withStyle style: TextStyle) {}
    func didOutputStyledCharacter(_ character: Character, toWindow window: Int,
                                  withStyle style: TextStyle,
                                  foregroundColor: ZMachineColor,
                                  backgroundColor: ZMachineColor) {}
    func windowWasCleared(_ number: Int) {}
    func lineWasCleared(window: Int, line: Int) {}
    func cursorWasMoved(window: Int, line: Int, column: Int) {}

    func styleWasSet(window: Int, style: TextStyle) {}
    func colorsWereSet(window: Int, foreground: ZMachineColor, background: ZMachineColor) {}

    func getCursorPosition(for window: Int) -> (line: Int, column: Int) {
        return (1, 1)  // Default position
    }

    func getWindowSize(for window: Int) -> (width: Int, height: Int) {
        return (80, 25)  // Default size
    }
}