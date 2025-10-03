/// Z-Machine Terminal Interface - Provides authentic v3 terminal experience
import Foundation

/// Terminal interface delegate that provides a full-screen Z-Machine v3 experience
/// matching the behavior of the original Infocom PEZ interpreter.
///
/// Features:
/// - Status bar at top (line 1) with reverse video
/// - Word-wrapping text output with 79-character width
/// - Proper screen positioning and buffer management
/// - ANSI escape sequence support for cursor control
/// - Authentic Z-Machine v3 layout and behavior
open class ZMachineTerminalDelegate: TextOutputDelegate, TextInputDelegate {

    // MARK: - Configuration

    /// Terminal configuration matching PEZ implementation
    private struct TerminalConfig {
        static let rightMargin = 80      // RM from PEZ
        static let leftMargin = 1        // LM from PEZ
        static let textWidth = 79        // RM - LM
        static let statusLine = 1        // Status bar row (STATLEN)
        static let textStartLine = 2     // Text area starts at row 2 (toplin)
        static let windowLength = 22     // Effective text window height
        static let bottomLine = 25       // Bottom of terminal
        static let bufferSize = 100      // OBUFSIZ from PEZ
    }

    // MARK: - State Variables

    /// Output buffer for word wrapping (matches PEZ outbuf)
    private var outputBuffer = [Character]()

    /// Current buffer position (matches PEZ chrptr)
    private var bufferPosition = 0

    /// Maximum buffer size before forced wrap (matches PEZ endbuf)
    private let bufferLimit = TerminalConfig.textWidth

    /// Line count for "MORE" pagination (matches PEZ linecnt)
    private var lineCount = 0

    /// Status line content
    private var statusText = ""

    /// Reference to VM for status line updates
    private weak var zmachine: ZMachine?

    // MARK: - Initialization

    public init(zmachine: ZMachine? = nil) {
        self.zmachine = zmachine
        setupTerminal()
    }

    /// Initialize terminal with proper screen setup
    private func setupTerminal() {
        // Clear screen and position cursor (VT100 style like PEZ)
        print("\u{1B}[2J\u{1B}[H", terminator: "")

        // Initialize status line
        updateStatusLine()

        // Position cursor at bottom for text output (windowed scrolling model)
        positionCursor(row: TerminalConfig.bottomLine, column: TerminalConfig.leftMargin)

        // Reset line count
        lineCount = 0

        // Flush output
        fflush(stdout)
    }

    // MARK: - TextOutputDelegate Implementation

    open func didOutputText(_ text: String) {
        for char in text {
            if char == "\n" {
                // Handle newline - flush current buffer and do windowed scroll
                flushOutputBuffer()
                newLine()
            } else if char.isASCII && char.asciiValue! >= 32 && char.asciiValue! <= 126 {
                // Add printable character to buffer
                addCharacterToBuffer(char)
            }
            // Skip non-printable characters except newline
        }
    }

    public func didQuit() {
        // Clear screen and show quit message
        flushOutputBuffer()
        newLine()
        print("\n[Game ended]")
        restoreTerminal()
    }

    // MARK: - TextInputDelegate Implementation

    public func requestInput() -> String {
        // Update status line before input (matching PEZ behavior)
        updateStatusLine()

        // Flush any pending output (including the ">" prompt)
        flushOutputBuffer()

        // Reset each time the user enters text. We only want to count the
        // number of lines per-message, because we only want to break single
        // messages that exceed the available vertical space.
        lineCount = 0

        // Read input (cursor should be at bottom of screen where text appears)
        if let input = readLineWrapper() {
            // Scroll to next line to write output.
            newLine()
            return input.lowercased() // PEZ converts input to lowercase
        } else {
            // EOF detected - exit gracefully
            print("\n[Input stream closed - terminating]")
            restoreTerminal()
            exit(0)
        }
    }

    /// Wrapper for readLine() that can be overridden by subclasses
    open func readLineWrapper() -> String? {
        return readLine()
    }

    public func requestInputWithTimeout(timeLimit: TimeInterval) -> (input: String?, timedOut: Bool) {
        // Simple implementation for now - real timeout would need platform-specific code
        let input = requestInput()
        return (input, false)
    }

    // MARK: - Buffer Management (matching PEZ putchr logic)

    /// Add character to output buffer with word wrapping
    private func addCharacterToBuffer(_ char: Character) {
        if bufferPosition < bufferLimit {
            // Room in buffer - add character
            if outputBuffer.count <= bufferPosition {
                outputBuffer.append(char)
            } else {
                outputBuffer[bufferPosition] = char
            }
            bufferPosition += 1
        } else {
            // Buffer full - need to wrap
            handleBufferOverflow(newChar: char)
        }
    }

    /// Handle buffer overflow with word wrapping (matches PEZ algorithm)
    private func handleBufferOverflow(newChar: Character) {
        // Search backwards for a space to break line (PEZ algorithm)
        var breakPoint = bufferPosition - 1
        var foundSpace = false

        while breakPoint >= 0 {
            if outputBuffer[breakPoint] == " " {
                foundSpace = true
                break
            }
            breakPoint -= 1
        }

        if foundSpace && breakPoint > 0 {
            // Found space - break line there (PEZ algorithm)
            let lineText = String(outputBuffer[0..<breakPoint])
            print(lineText, terminator: "") // Print without newline (like PEZ mprnt)
            fflush(stdout)

            // Clear the printed portion from buffer BEFORE calling newLine
            if breakPoint + 1 < bufferPosition {
                let remainder = Array(outputBuffer[(breakPoint + 1)..<bufferPosition])
                outputBuffer = remainder
                bufferPosition = remainder.count
            } else {
                // No remainder text
                outputBuffer.removeAll()
                bufferPosition = 0
            }

            // Do windowed scroll (matches PEZ mprnt calling mcrlf on null terminator)
            newLine()

            // Add the new character
            if bufferPosition < bufferLimit {
                outputBuffer.append(newChar)
                bufferPosition += 1
            }
        } else {
            // No space found - force break (PEZ behavior)
            flushOutputBuffer()
            newLine()

            // Start new line with the character
            outputBuffer = [newChar]
            bufferPosition = 1
        }
    }

    /// Flush output buffer to screen
    private func flushOutputBuffer() {
        if bufferPosition > 0 {
            let text = String(outputBuffer[0..<bufferPosition])
            print(text, terminator: "")
            outputBuffer.removeAll()
            bufferPosition = 0
            fflush(stdout)
        }
    }

    /// Handle newline - do windowed scroll (matches PEZ mcrlf)
    private func newLine() {
        // Windowed scroll (matches PEZ mcrlf function exactly)
        // Position cursor at top of text window
        positionCursor(row: TerminalConfig.textStartLine, column: TerminalConfig.leftMargin)

        // Insert line at top (VT100 \033[M) - pushes content down
        print("\u{1B}[M", terminator: "")

        // Position cursor at bottom for next output
        positionCursor(row: TerminalConfig.bottomLine, column: TerminalConfig.leftMargin)

        lineCount += 1

        // Handle "MORE" pagination (matches PEZ behavior)
        if lineCount >= TerminalConfig.windowLength {
            print("** MORE **", terminator: "")
            fflush(stdout)
            _ = readLine() // Wait for user input

            // Clear the "MORE" prompt (\033[10D moves left 10, \033[K clears to end)
            print("\u{1B}[10D\u{1B}[K", terminator: "")
            lineCount = 1
        }

        fflush(stdout)
    }

    // MARK: - Status Line Management (matching PEZ statusln)

    /// Update status line with current game state
    public func updateStatusLine() {
        guard let vm = zmachine else {
            displayStatusLine("Swift ZIL - No Game Loaded")
            return
        }

        // Get current location (global variable 16 in PEZ)
        let currentLocation = vm.getVariable(16) // G_HERE from PEZ

        // Get score and moves (or time for time-based games)
        let scoreOrTime = vm.getVariable(17) // G_SCORE or G_HOURS
        let movesOrMinutes = vm.getVariable(18) // G_MOVES or G_MINS

        // Try to get location description
        var locationName = "Unknown Location"
        if currentLocation > 0 {
            do {
                locationName = try vm.readObjectShortDescription(currentLocation)
                if locationName.isEmpty {
                    locationName = "Object \(currentLocation)"
                }
            } catch {
                locationName = "Location \(currentLocation)"
            }
        }

        // Format status line (80 characters, matching PEZ format)
        let leftSide = " \(locationName)"
        let rightSide = "Score: \(scoreOrTime)  Moves: \(movesOrMinutes) "

        // Pad to exactly 80 characters
        let totalPadding = TerminalConfig.rightMargin - leftSide.count - rightSide.count
        let padding = totalPadding > 0 ? String(repeating: " ", count: totalPadding) : ""

        let statusLine = leftSide + padding + rightSide
        let truncatedStatus = String(statusLine.prefix(TerminalConfig.rightMargin))

        displayStatusLine(truncatedStatus)
    }

    /// Display status line with reverse video formatting
    private func displayStatusLine(_ text: String) {
        // Position cursor at status line (row 1, col 1)
        positionCursor(row: TerminalConfig.statusLine, column: TerminalConfig.leftMargin)

        // Enable reverse video (matching PEZ hilite(REVERSE))
        print("\u{1B}[7m", terminator: "")

        // Print status line, padded to exact width
        let paddedText = text.padding(toLength: TerminalConfig.rightMargin, withPad: " ", startingAt: 0)
        print(paddedText, terminator: "")

        // Restore normal video (matching PEZ hilite(NORMAL))
        print("\u{1B}[0m", terminator: "")

        // Return to bottom of screen for output
        positionCursor(row: TerminalConfig.bottomLine, column: TerminalConfig.leftMargin)

        fflush(stdout)
    }

    // MARK: - Cursor Control (matching PEZ locate function)

    /// Position cursor using ANSI escape sequences (matches PEZ locate)
    private func positionCursor(row: Int, column: Int) {
        print("\u{1B}[\(row);\(column)H", terminator: "")
        fflush(stdout)
    }

    /// Clear screen (matches PEZ cls function)
    private func clearScreen() {
        print("\u{1B}[2J\u{1B}[H", terminator: "")
        positionCursor(row: TerminalConfig.bottomLine, column: TerminalConfig.leftMargin)
        lineCount = 0
        fflush(stdout)
    }

    // MARK: - Terminal Cleanup

    /// Restore terminal to normal state
    private func restoreTerminal() {
        // Ensure normal video mode
        print("\u{1B}[0m", terminator: "")

        // Move cursor to bottom of screen
        positionCursor(row: 25, column: 1)

        fflush(stdout)
    }
}

// MARK: - Extensions

extension ZMachine {
    /// Get a global variable value for status line display
    internal func getVariable(_ number: UInt8) -> UInt16 {
        // Global variables are stored in the globals array
        // Variables 16-255 are globals (subtract 16 for array index)
        if number >= 16 && number < 16 + globals.count {
            let globalIndex = Int(number) - 16
            return globals[globalIndex]
        }
        return 0
    }
}
