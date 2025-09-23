import ArgumentParser
import ZEngine

@main
struct ZILTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zil",
        abstract: "ZIL Interactive Fiction Development Environment",
        version: "1.0.0",
        subcommands: [
            BuildCommand.self,
            RunCommand.self,
            AnalyzeCommand.self
        ]
    )
}

struct BuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Compile ZIL source to ZAP assembly and/or Z-Machine bytecode"
    )

    @Argument(help: "ZIL source file or project directory")
    var input: String = "."

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String?

    @Flag(name: [.customShort("S"), .customLong("assembly-only")], help: "Stop after compilation, output ZAP assembly only")
    var assemblyOnly = false

    @Option(help: "Target Z-Machine version (3, 4, 5, 6, 8)")
    var version: Int = 5

    @Flag(help: "Generate debug symbols")
    var debug = false

    @Option(help: "Optimization level (0-2)")
    var optimize: Int = 1

    func run() throws {
        print("Building ZIL project from \(input)")
        print("Target: Z-Machine v\(version)")
        if assemblyOnly {
            print("Output: ZAP assembly only")
        }
        if let output = output {
            print("Output file: \(output)")
        }
        if debug {
            print("Debug symbols enabled")
        }
        print("Optimization level: \(optimize)")
    }
}

struct RunCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Compile (if necessary) and launch game in Z-Machine VM"
    )

    @Argument(help: "ZIL source file, project directory, or story file")
    var input: String = "."

    @Flag(help: "Enable VM debug mode")
    var debug = false

    @Option(help: "Record gameplay transcript to file")
    var transcript: String?

    @Option(help: "Directory for save games")
    var saveDir: String?

    func run() throws {
        print("Running ZIL project/game from \(input)")
        if debug {
            print("VM debug mode enabled")
        }
        if let transcript = transcript {
            print("Recording transcript to: \(transcript)")
        }
        if let saveDir = saveDir {
            print("Save directory: \(saveDir)")
        }
    }
}

struct AnalyzeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "analyze",
        abstract: "Analyze structure and content of Z-Machine story files"
    )

    @Argument(help: "Story file to analyze (if omitted, builds current project)")
    var storyFile: String?

    @Flag(help: "Show story file header information")
    var header = false

    @Flag(help: "Display object tree and properties")
    var objects = false

    @Flag(help: "Show parser dictionary contents")
    var dictionary = false

    @Flag(help: "List all strings and abbreviations")
    var strings = false

    @Flag(help: "Show routine table and disassembly")
    var routines = false

    @Flag(help: "Display memory layout and usage")
    var memory = false

    @Flag(help: "Show all sections (equivalent to all other flags)")
    var all = false

    func run() throws {
        let target = storyFile ?? "[current project]"
        print("Analyzing Z-Machine story file: \(target)")

        if all || header {
            print("- Header information")
        }
        if all || objects {
            print("- Object tree and properties")
        }
        if all || dictionary {
            print("- Parser dictionary")
        }
        if all || strings {
            print("- Strings and abbreviations")
        }
        if all || routines {
            print("- Routine table and disassembly")
        }
        if all || memory {
            print("- Memory layout and usage")
        }

        if !all && !header && !objects && !dictionary && !strings && !routines && !memory {
            print("- All sections (default)")
        }
    }
}