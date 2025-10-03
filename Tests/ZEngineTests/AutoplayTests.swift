import Testing
import Foundation
@testable import zil
import ZEngine

@Suite("Autoplay Instruction Manager Tests")
struct AutoplayInstructionManagerTests {

    @Test("Basic instruction parsing")
    func basicInstructionParsing() throws {
        let manager = AutoplayInstructionManager(config: .init())

        let instructionContent = """
        # This is a comment
        north
        get lamp

        # Another comment
        south
        """

        // Create temporary file
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_instructions.txt")

        try instructionContent.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Test loading instructions should not throw
        try manager.loadInstructions(from: tempURL.path)
    }

    @Test("SET directive parsing")
    func setDirectiveParsing() throws {
        let manager = AutoplayInstructionManager(config: .init())

        let instructionContent = """
        !SET wounds = 0
        !SET health = 100
        !SET score = 50
        """

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_set_instructions.txt")

        try instructionContent.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Should not throw during parsing
        try manager.loadInstructions(from: tempURL.path)
    }

    @Test("Configuration options")
    func configurationOptions() throws {
        // Test different configuration options
        let config1 = AutoplayInstructionManager.AutoplayConfig(
            interval: 5,
            isManualMode: true,
            verbosity: 2
        )
        let _ = AutoplayInstructionManager(config: config1)

        let config2 = AutoplayInstructionManager.AutoplayConfig()
        let _ = AutoplayInstructionManager(config: config2)

        // If we reach here, both configurations worked
        #expect(true)
    }

    @Test("Invalid directive parsing errors")
    func invalidDirectiveErrors() throws {
        let manager = AutoplayInstructionManager(config: .init())

        // Test invalid SET directive
        let invalidSetContent = "!SET wounds"
        let tempURL1 = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_invalid_set.txt")

        try invalidSetContent.write(to: tempURL1, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL1) }

        #expect(throws: InstructionError.self) {
            try manager.loadInstructions(from: tempURL1.path)
        }
    }

    @Test("File not found error")
    func fileNotFoundError() throws {
        let manager = AutoplayInstructionManager(config: .init())

        #expect(throws: Error.self) {
            try manager.loadInstructions(from: "/nonexistent/file.txt")
        }
    }
}

@Suite("Autoplay Error Handling Tests")
struct AutoplayErrorTests {

    @Test("InstructionError types")
    func instructionErrorTypes() throws {
        let parseError = InstructionError.parseError("Test parse error")
        let fileError = InstructionError.fileError("Test file error")
        let executionError = InstructionError.executionError("Test execution error")

        #expect(parseError.errorDescription?.contains("Test parse error") == true)
        #expect(fileError.errorDescription?.contains("Test file error") == true)
        #expect(executionError.errorDescription?.contains("Test execution error") == true)
    }

    @Test("InstructionError localized descriptions")
    func errorLocalizedDescriptions() throws {
        let parseError = InstructionError.parseError("Invalid syntax")
        #expect(parseError.localizedDescription.contains("Parse error"))
        #expect(parseError.localizedDescription.contains("Invalid syntax"))

        let fileError = InstructionError.fileError("File not found")
        #expect(fileError.localizedDescription.contains("File error"))
        #expect(fileError.localizedDescription.contains("File not found"))

        let executionError = InstructionError.executionError("Runtime failure")
        #expect(executionError.localizedDescription.contains("Execution error"))
        #expect(executionError.localizedDescription.contains("Runtime failure"))
    }
}