// Z-Machine simple terminal interface - prints and reads directly to stdin/out
import Foundation

public class SimpleTerminalDelegate: TextInputDelegate, TextOutputDelegate {
    public func requestInput() -> String {
        if let input = readLine() {
            return input.lowercased()
        } else {
            exit(0)
        }
    }
    
    public func requestInputWithTimeout(timeLimit: TimeInterval) -> (input: String?, timedOut: Bool) {
        (requestInput(), false)
    }
    
    public func didOutputText(_ text: String) {
        print(text)
    }
    
    public func didQuit() {
        // N/A
    }
}
