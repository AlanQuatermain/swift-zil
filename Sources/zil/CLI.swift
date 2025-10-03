import ArgumentParser
import Foundation
import ZEngine
import Logging

/// Main entry point for the ZIL Interactive Fiction Development Environment.
///
/// `ZILTool` provides a comprehensive command-line interface for developing,
/// building, and analyzing interactive fiction games using the ZIL (Zork
/// Implementation Language) and Z-Machine virtual machine.
///
/// ## Available Commands
/// - **build**: Compile ZIL source code to ZAP assembly and/or Z-Machine bytecode
/// - **run**: Execute ZIL projects or Z-Machine story files in the virtual machine
/// - **analyze**: Inspect and analyze the structure of compiled story files
///
/// ## Usage Examples
/// ```bash
/// # Build a ZIL project to story file
/// zil build game.zil --output game.z5 --version 5
///
/// # Run a story file
/// zil run game.z5 --debug
///
/// # Analyze story file structure
/// zil analyze game.z5 --objects --routines
/// ```
@main
struct ZILTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "zil",
        abstract: "ZIL Interactive Fiction Development Environment",
        version: "1.0.0",
        subcommands: [
            BuildCommand.self,
            RunCommand.self,
            AnalyzeCommand.self,
            AutoplayCommand.self
        ]
    )
}

/// Command for compiling ZIL source code to assembly and/or bytecode.
///
/// `BuildCommand` handles the compilation pipeline from ZIL source files through
/// ZAP assembly to final Z-Machine story files. It supports various output formats,
/// optimization levels, and debugging options.
///
/// ## Compilation Pipeline
/// 1. **ZIL Parsing**: Parse ZIL source files and resolve includes
/// 2. **Code Generation**: Generate ZAP assembly instructions
/// 3. **Assembly** (optional): Convert ZAP to Z-Machine bytecode
/// 4. **Linking**: Resolve symbols and create final story file
///
/// ## Output Formats
/// - **Assembly only** (`--assembly-only`): Stop after generating ZAP files
/// - **Story file**: Complete Z-Machine executable (default)
///
/// ## Example Usage
/// ```bash
/// # Basic compilation to Z5 story file
/// zil build game.zil --output game.z5
///
/// # Generate assembly only for inspection
/// zil build game.zil --assembly-only --output game.zap
///
/// # Debug build with symbols
/// zil build . --debug --optimize 0
/// ```
struct BuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Compile ZIL source to ZAP assembly and/or Z-Machine bytecode"
    )

    /// Input ZIL source file or project directory.
    ///
    /// If a directory is specified, the build system will look for a main
    /// ZIL file or project configuration to determine the build targets.
    @Argument(help: "ZIL source file or project directory")
    var input: String = "."

    /// Output file path for the generated assembly or story file.
    ///
    /// If not specified, the output filename will be derived from the input
    /// with the appropriate extension (.zap for assembly, .z5 for story files).
    @Option(name: .shortAndLong, help: "Output file path")
    var output: String?

    /// Stop compilation after generating ZAP assembly.
    ///
    /// When enabled, the build process stops after the ZIL-to-ZAP compilation
    /// phase, producing human-readable assembly output for inspection or
    /// further manual processing.
    @Flag(name: [.customShort("S"), .customLong("assembly-only")], help: "Stop after compilation, output ZAP assembly only")
    var assemblyOnly = false

    /// Target Z-Machine version for bytecode generation.
    ///
    /// Different versions support different feature sets:
    /// - Version 3: Basic features, 128KB memory limit
    /// - Version 4: Sound effects, extended objects
    /// - Version 5: Color, mouse input, 256KB memory limit
    /// - Version 6: Graphics support, multiple windows
    /// - Version 8: Unicode support, modern extensions
    @Option(help: "Target Z-Machine version (3, 4, 5, 6, 8)")
    var version: Int = 5

    /// Generate debug symbols and debugging information.
    ///
    /// When enabled, the compiler includes additional metadata in the output
    /// to support debugging tools and enhanced error reporting.
    @Flag(help: "Generate debug symbols")
    var debug = false

    /// Code optimization level.
    ///
    /// Controls the aggressiveness of compiler optimizations:
    /// - 0: No optimization, fastest compilation
    /// - 1: Basic optimizations, balanced performance
    /// - 2: Aggressive optimizations, slower compilation
    @Option(help: "Optimization level (0-2)")
    var optimize: Int = 1

    /// Increase verbosity of library logging output.
    ///
    /// Multiple flags increase verbosity:
    /// - Default: notice level and above
    /// - -v: info level and above
    /// - -vv: debug level and above
    /// - -vvv: trace level and above
    @Flag(name: .shortAndLong, help: "Increase verbosity (-v, -vv, -vvv)")
    var verbose: Int

    /// Computed property to get the appropriate log level based on verbosity
    private var logLevel: Logger.Level {
        switch verbose {
        case 0: return .notice
        case 1: return .info
        case 2: return .debug
        default: return .trace
        }
    }

    /// Executes the build command with the specified options.
    ///
    /// This method orchestrates the compilation pipeline, handling file I/O,
    /// error reporting, and progress feedback.
    ///
    /// - Throws: Various errors related to file access, compilation failures,
    ///           or invalid command-line arguments
    func run() throws {
        // Initialize logging with appropriate verbosity level
        ZILLogger.bootstrap(logLevel: logLevel)

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
        print()

        // Validate Z-Machine version
        guard let zmachineVersion = ZMachineVersion(rawValue: UInt8(version)) else {
            print("Error: Invalid Z-Machine version: \(version). Supported versions: 3, 4, 5, 6, 8")
            throw ExitCode.validationFailure
        }

        // Determine input file
        let inputPath: String
        if input == "." {
            // Look for main ZIL file in current directory
            let fileManager = FileManager.default
            let currentDir = fileManager.currentDirectoryPath
            let zilFiles = try fileManager.contentsOfDirectory(atPath: currentDir)
                .filter { $0.hasSuffix(".zil") }

            if zilFiles.isEmpty {
                print("Error: No ZIL files found in current directory")
                throw ExitCode.validationFailure
            } else if zilFiles.count == 1 {
                inputPath = zilFiles.first!
            } else {
                // Look for main.zil or use the first one
                inputPath = zilFiles.first { $0 == "main.zil" } ?? zilFiles.first!
            }
            print("Using input file: \(inputPath)")
        } else {
            inputPath = input
        }

        // Determine output file
        let outputPath: String
        if let output = output {
            outputPath = output
        } else {
            let baseName = URL(fileURLWithPath: inputPath).deletingPathExtension().lastPathComponent
            if assemblyOnly {
                outputPath = "\(baseName).zap"
            } else {
                outputPath = "\(baseName).z\(version)"
            }
            print("Using output file: \(outputPath)")
        }

        // Load and parse ZIL source
        print("Reading ZIL source...")
        let zilSource = try String(contentsOfFile: inputPath, encoding: .utf8)

        print("Lexing and parsing...")
        let lexer = ZILLexer(source: zilSource, filename: inputPath)
        let parser = try ZILParser(lexer: lexer, filePath: inputPath)
        let declarations = try parser.parseProgram()

        print("Generating ZAP assembly...")
        let symbolTable = SymbolTableManager()
        var codeGenerator = ZAPCodeGenerator(symbolTable: symbolTable, version: zmachineVersion, optimizationLevel: optimize)
        let zapCode = try codeGenerator.generateCode(from: declarations)

        if assemblyOnly {
            // Write ZAP assembly file
            print("Writing ZAP assembly to \(outputPath)...")
            try zapCode.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("Assembly generation complete!")
        } else {
            // Assemble to bytecode
            print("Assembling to Z-Machine bytecode...")
            let assembler = ZAssembler(version: zmachineVersion)
            let bytecode = try assembler.assemble(zapCode)

            // Write story file
            print("Writing story file to \(outputPath)...")
            try bytecode.write(to: URL(fileURLWithPath: outputPath))
            print("Build complete!")
        }
    }
}

/// Command for executing ZIL projects and Z-Machine story files.
///
/// `RunCommand` provides a unified interface for running interactive fiction games,
/// whether they exist as ZIL source code (which will be compiled automatically)
/// or as pre-compiled Z-Machine story files.
///
/// ## Input Types
/// - **ZIL source files**: Automatically compiled before execution
/// - **Project directories**: Built using default configuration
/// - **Story files**: Executed directly in the Z-Machine VM
///
/// ## Features
/// - Automatic compilation of ZIL source when needed
/// - Debug mode with VM inspection capabilities
/// - Transcript recording for gameplay analysis
/// - Save game management with custom directories
///
/// ## Example Usage
/// ```bash
/// # Run a ZIL project (auto-compiles)
/// zil run game.zil
///
/// # Run pre-compiled story file with debug mode
/// zil run game.z5 --debug
///
/// # Record gameplay transcript
/// zil run game.z5 --transcript gameplay.txt
/// ```
struct RunCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Compile (if necessary) and launch game in Z-Machine VM"
    )

    /// Input source file, project directory, or story file to execute.
    ///
    /// The command automatically detects the input type and handles it appropriately:
    /// - `.zil` files: Compiled to temporary story file and executed
    /// - Directories: Searched for main ZIL file or project configuration
    /// - `.z3/.z4/.z5/.z6/.z8` files: Loaded directly into the VM
    @Argument(help: "ZIL source file, project directory, or story file")
    var input: String = "."

    /// Enable debug mode for detailed VM inspection.
    ///
    /// When enabled, the Z-Machine virtual machine provides additional
    /// debugging information including instruction traces, memory dumps,
    /// and interactive debugging commands.
    @Flag(help: "Enable VM debug mode")
    var debug = false

    /// Enable instruction tracing to the specified file.
    ///
    /// All Z-Machine instruction execution will be logged to the trace file
    /// with detailed information about opcodes, operands, and bytes consumed.
    /// Format: <address>: <opcode> (<type>) <operands> [<bytes>]
    @Option(help: "Enable instruction tracing to file")
    var trace: String?

    /// Record gameplay transcript to the specified file.
    ///
    /// All player input and game output will be saved to the transcript file
    /// for later review, testing, or documentation purposes.
    @Option(help: "Record gameplay transcript to file")
    var transcript: String?

    /// Directory for storing save game files.
    ///
    /// If not specified, save games are stored in the default system location
    /// (typically `~/Documents/Interactive Fiction/Saves`).
    @Option(help: "Directory for save games")
    var saveDir: String?

    /// Increase verbosity of library logging output.
    ///
    /// Multiple flags increase verbosity:
    /// - Default: notice level and above
    /// - -v: info level and above
    /// - -vv: debug level and above
    /// - -vvv: trace level and above
    @Flag(name: .shortAndLong, help: "Increase verbosity (-v, -vv, -vvv)")
    var verbose: Int

    /// Computed property to get the appropriate log level based on verbosity
    private var logLevel: Logger.Level {
        switch verbose {
        case 0: return .notice
        case 1: return .info
        case 2: return .debug
        default: return .trace
        }
    }

    /// Executes the run command to launch the game.
    ///
    /// This method handles input detection, optional compilation, and VM setup
    /// with the specified runtime options.
    ///
    /// - Throws: Various errors related to file access, compilation failures,
    ///           VM initialization, or runtime execution problems
    func run() throws {
        // Initialize logging with appropriate verbosity level
        ZILLogger.bootstrap(logLevel: logLevel)

        // Detect input type and handle appropriately
        let storyFileURL: URL

        if input.hasSuffix(".z3") || input.hasSuffix(".z4") || input.hasSuffix(".z5") ||
           input.hasSuffix(".z6") || input.hasSuffix(".z8") {
            // Direct story file
            storyFileURL = URL(fileURLWithPath: input)

            if debug {
                print("Running ZIL project/game from \(input)")
                print("Loading story file: \(input)")
            }
        } else {
            // ZIL source or directory - would need compilation (not implemented yet)
            print("Error: ZIL compilation not yet implemented in run command")
            print("Please provide a compiled story file (.z3, .z4, .z5, .z6, .z8)")
            throw ExitCode.validationFailure
        }

        // Initialize and run Z-Machine VM
        let vm = ZMachine()

        do {
            try vm.loadStoryFile(from: storyFileURL)

            // Enable instruction tracing if requested
            if let traceFile = trace {
                let traceURL = URL(fileURLWithPath: traceFile)
                try vm.enableTracing(to: traceURL)
            }

            // Set up terminal interface for authentic Z-Machine v3 experience
            let terminalDelegate = ZMachineTerminalDelegate(zmachine: vm)
            vm.inputDelegate = terminalDelegate
            vm.outputDelegate = terminalDelegate

            if debug {
                print("✓ Story file loaded successfully")
                print("  Version: \(vm.version.rawValue)")
                print("  Memory validation: \(vm.validateMemoryManagement() ? "✓" : "✗")")
                print("Press Enter to start...")
                _ = readLine()
            }

            // Game starts here - terminal interface handles all output
            try vm.run()

        } catch {
            print("Error running story file: \(error)")
            throw ExitCode.failure
        }
    }
}

/// Command for analyzing Z-Machine story file structure and content.
///
/// `AnalyzeCommand` provides comprehensive inspection capabilities for Z-Machine
/// story files, allowing developers to examine the internal structure, debug
/// compilation issues, and understand the generated bytecode.
///
/// ## Analysis Sections
/// - **Header**: Story file metadata, version info, and memory layout
/// - **Objects**: Object tree hierarchy, properties, and attributes
/// - **Dictionary**: Parser vocabulary and word recognition data
/// - **Strings**: Text storage, abbreviations, and encoding information
/// - **Routines**: Executable code with optional disassembly
/// - **Memory**: Memory regions, usage statistics, and layout
///
/// ## Use Cases
/// - Debugging compilation problems
/// - Optimizing memory usage and story file size
/// - Understanding Z-Machine internals
/// - Verifying correct code generation
/// - Educational exploration of classic games
///
/// ## Example Usage
/// ```bash
/// # Analyze all sections of a story file
/// zil analyze game.z5 --all
///
/// # Show only object tree and routines
/// zil analyze game.z5 --objects --routines
///
/// # Quick header inspection
/// zil analyze game.z5 --header
/// ```
struct AnalyzeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "analyze",
        abstract: "Analyze structure and content of Z-Machine story files"
    )

    /// Story file to analyze.
    ///
    /// If omitted, the current project directory is built automatically and
    /// the resulting story file is analyzed. This is useful for inspecting
    /// the output of ongoing development work.
    @Argument(help: "Story file to analyze (if omitted, builds current project)")
    var storyFile: String?

    /// Display story file header information.
    ///
    /// Shows version number, memory layout, serial number, checksum,
    /// and other metadata stored in the 64-byte story file header.
    @Flag(help: "Show story file header information")
    var header = false

    /// Display the complete object tree and properties.
    ///
    /// Shows object hierarchy, parent-child relationships, object properties,
    /// attributes (flags), and inheritance patterns throughout the game world.
    @Flag(help: "Display object tree and properties")
    var objects = false

    /// Show parser dictionary contents.
    ///
    /// Displays all recognized words, their grammatical classifications,
    /// and the internal dictionary structure used for parsing player input.
    @Flag(help: "Show parser dictionary contents")
    var dictionary = false

    /// List all strings and abbreviations.
    ///
    /// Shows string table contents, abbreviation definitions, text encoding
    /// information, and string compression statistics.
    @Flag(help: "List all strings and abbreviations")
    var strings = false

    /// Show routine table and optional disassembly.
    ///
    /// Displays routine addresses, local variable counts, and optionally
    /// provides disassembly of Z-Machine bytecode instructions.
    @Flag(help: "Show routine table and disassembly")
    var routines = false

    /// Display memory layout and usage statistics.
    ///
    /// Shows memory region boundaries, usage statistics, and helps identify
    /// opportunities for optimization or potential memory issues.
    @Flag(help: "Display memory layout and usage")
    var memory = false

    /// Enable all analysis sections.
    ///
    /// Equivalent to specifying all other flags individually. Provides
    /// comprehensive analysis of every aspect of the story file.
    @Flag(help: "Show all sections (equivalent to all other flags)")
    var all = false

    /// Increase verbosity of library logging output.
    ///
    /// Multiple flags increase verbosity:
    /// - Default: notice level and above
    /// - -v: info level and above
    /// - -vv: debug level and above
    /// - -vvv: trace level and above
    @Flag(name: .shortAndLong, help: "Increase verbosity (-v, -vv, -vvv)")
    var verbose: Int

    /// Computed property to get the appropriate log level based on verbosity
    private var logLevel: Logger.Level {
        switch verbose {
        case 0: return .notice
        case 1: return .info
        case 2: return .debug
        default: return .trace
        }
    }

    /// Executes the analyze command with the specified inspection options.
    ///
    /// This method coordinates the analysis process, loading the story file,
    /// parsing its contents, and displaying the requested information sections.
    ///
    /// - Throws: Various errors related to file access, story file corruption,
    ///           or unsupported Z-Machine versions
    func run() throws {
        // Initialize logging with appropriate verbosity level
        ZILLogger.bootstrap(logLevel: logLevel)

        // Determine story file to analyze
        let targetFile: String
        if let storyFile = storyFile {
            targetFile = storyFile
        } else {
            // Look for story files in current directory
            let fileManager = FileManager.default
            let currentDir = fileManager.currentDirectoryPath
            let storyFiles = try fileManager.contentsOfDirectory(atPath: currentDir)
                .filter { $0.hasSuffix(".z3") || $0.hasSuffix(".z4") || $0.hasSuffix(".z5") ||
                         $0.hasSuffix(".z6") || $0.hasSuffix(".z8") }

            if storyFiles.isEmpty {
                print("Error: No story files found in current directory")
                print("Please specify a story file to analyze or run 'zil build' first")
                throw ExitCode.validationFailure
            } else if storyFiles.count == 1 {
                targetFile = storyFiles.first!
            } else {
                // Use the most recent story file
                targetFile = storyFiles.sorted().last!
            }
        }

        print("Analyzing Z-Machine story file: \(targetFile)")
        print()

        // Determine which sections to show
        let showAll = all || (!header && !objects && !dictionary && !strings && !routines && !memory)

        // Load the story file
        let storyURL = URL(fileURLWithPath: targetFile)
        guard FileManager.default.fileExists(atPath: targetFile) else {
            print("Error: Story file not found: \(targetFile)")
            throw ExitCode.validationFailure
        }

        let vm = ZMachine()
        do {
            try vm.loadStoryFile(from: storyURL)

            // Header Analysis
            if showAll || header {
                print("=== HEADER INFORMATION ===")
                analyzeHeader(vm)
                print()
            }

            // Memory Layout Analysis
            if showAll || memory {
                print("=== MEMORY LAYOUT ===")
                analyzeMemoryLayout(vm)
                print()
            }

            // Objects Analysis
            if showAll || objects {
                print("=== OBJECT TREE ===")
                analyzeObjects(vm)
                print()
            }

            // Dictionary Analysis
            if showAll || dictionary {
                print("=== DICTIONARY ===")
                analyzeDictionary(vm)
                print()
            }

            // Strings Analysis
            if showAll || strings {
                print("=== STRINGS & ABBREVIATIONS ===")
                analyzeStrings(vm)
                print()
            }

            // Routines Analysis
            if showAll || routines {
                print("=== ROUTINES ===")
                analyzeRoutines(vm)
                print()
            }

        } catch {
            print("Error loading story file: \(error)")
            throw ExitCode.failure
        }
    }

    // MARK: - Analysis Methods

    private func analyzeHeader(_ vm: ZMachine) {
        let header = vm.header
        print("Version: \(header.version.rawValue)")
        print("Serial Number: \(header.serialNumber)")
        print("Checksum: 0x\(String(header.checksum, radix: 16, uppercase: true))")
        print("Initial PC: 0x\(String(header.initialPC, radix: 16, uppercase: true))")
        print("Dictionary Address: 0x\(String(header.dictionaryAddress, radix: 16, uppercase: true))")
        print("Object Table Address: 0x\(String(header.objectTableAddress, radix: 16, uppercase: true))")
        print("Global Table Address: 0x\(String(header.globalTableAddress, radix: 16, uppercase: true))")
        print("Static Memory Base: 0x\(String(header.staticMemoryBase, radix: 16, uppercase: true))")
        print("High Memory Base: 0x\(String(header.highMemoryBase, radix: 16, uppercase: true))")

        if header.abbreviationTableAddress > 0 {
            print("Abbreviation Table: 0x\(String(header.abbreviationTableAddress, radix: 16, uppercase: true))")
        }

        if header.version.rawValue >= 5 && header.unicodeTableAddress > 0 {
            print("Unicode Table: 0x\(String(header.unicodeTableAddress, radix: 16, uppercase: true))")
        }

        if header.version.rawValue >= 6 {
            print("Routine Offset: 0x\(String(header.routineOffset, radix: 16, uppercase: true))")
            print("String Offset: 0x\(String(header.stringOffset, radix: 16, uppercase: true))")
        }
    }

    private func analyzeMemoryLayout(_ vm: ZMachine) {
        let header = vm.header
        let dynamicSize = header.staticMemoryBase
        let staticSize = header.highMemoryBase - header.staticMemoryBase
        let totalSize = vm.storyData.count
        let highSize = UInt32(totalSize) - header.highMemoryBase

        print("Total Story File Size: \(totalSize) bytes")
        print("Dynamic Memory: 0x0000 - 0x\(String(dynamicSize-1, radix: 16, uppercase: true)) (\(dynamicSize) bytes)")
        print("Static Memory: 0x\(String(header.staticMemoryBase, radix: 16, uppercase: true)) - 0x\(String(header.highMemoryBase-1, radix: 16, uppercase: true)) (\(staticSize) bytes)")
        print("High Memory: 0x\(String(header.highMemoryBase, radix: 16, uppercase: true)) - 0x\(String(UInt32(totalSize)-1, radix: 16, uppercase: true)) (\(highSize) bytes)")

        let maxSize = ZMachine.getMaxMemorySize(for: header.version)
        let usage = Double(totalSize) / Double(maxSize) * 100
        print("Memory Usage: \(String(format: "%.1f", usage))% of \(maxSize) byte limit")
    }

    private func analyzeObjects(_ vm: ZMachine) {
        let objectTree = vm.objectTree
        var objectCount = 0
        var objectNumber: UInt16 = 1
        var maxObjectNumber: UInt16 = 0

        // Count objects and find highest object number
        while let _ = objectTree.getObject(objectNumber) {
            objectCount += 1
            maxObjectNumber = objectNumber
            objectNumber += 1
        }

        print("Total Objects: \(objectCount)")
        print("Object Range: 1-\(maxObjectNumber)")
        print("Highest Valid Object: \(maxObjectNumber)")
        print()

        // Check for gaps in object numbering
        var gapCount = 0
        guard maxObjectNumber > 0 else {
            print("ERROR: No objects were loaded from the object tree")
            return
        }
        for i in 1...maxObjectNumber {
            if objectTree.getObject(i) == nil {
                gapCount += 1
                if gapCount <= 5 { // Show first 5 gaps
                    print("WARNING: Missing object \(i)")
                }
            }
        }
        if gapCount > 5 {
            print("... and \(gapCount - 5) more missing objects")
        }
        if gapCount > 0 {
            print()
        }

        // Show all objects with their decoded short names
        print("All \(objectCount) objects:")
        for i in 1...maxObjectNumber {
            if let object = objectTree.getObject(i) {
                // Get the object's short name from property table
                do {
                    let shortName = try vm.readObjectShortDescription(i)
                    let displayName = shortName.isEmpty ? "(no name)" : "\"\(shortName)\""
                    print("Object \(i) - \(displayName)")
                    print("  parent=\(object.parent), sibling=\(object.sibling), child=\(object.child)")
                } catch {
                    print("Object \(i) - (decode error: \(error))")
                    print("  parent=\(object.parent), sibling=\(object.sibling), child=\(object.child)")
                }

                // Show decoded properties
                let properties = vm.analyzeObjectProperties(i)
                for prop in properties {
                    if let decodedString = prop.decodedString {
                        print("    \(prop.propertyName) (\(prop.propertyNumber)): \(prop.rawValue) = \"\(decodedString)\" [\(prop.addressInfo)]")
                    } else {
                        print("    \(prop.propertyName) (\(prop.propertyNumber)): \(prop.rawValue) [\(prop.addressInfo)]")
                    }
                }
            }
        }

    }

    private func analyzeDictionary(_ vm: ZMachine) {
        let dict = vm.dictionary
        print("Dictionary Statistics:")
        print("Entry Length: \(dict.entryLength) bytes")
        print("Entry Count: \(dict.entryCount) entries")
        print("Separator Characters: \(dict.separatorCount) separators")

        // Show all dictionary words
        print("\nAll \(dict.entryCount) dictionary words:")
        for i in 0..<Int(dict.entryCount) {
            if let entry = dict.getEntry(at: i) {
                let decodedText = entry.decodeWord()
                print("  \(i + 1): '\(decodedText)' (address: 0x\(String(entry.address, radix: 16, uppercase: true)))")
            }
        }
    }

    private func analyzeStrings(_ vm: ZMachine) {
        print("=== ABBREVIATION TABLE ANALYSIS ===")

        // Show header info first
        if vm.header.abbreviationTableAddress > 0 {
            print("Header Abbreviation Table Address: 0x\(String(vm.header.abbreviationTableAddress, radix: 16, uppercase: true))")
        } else {
            print("Header shows no abbreviation table (address = 0)")
        }

        print("Loaded Abbreviation Table Entries: \(vm.abbreviationTable.count)")

        if vm.abbreviationTable.count > 0 {
            // Use the detailed debugging methods from VMSupport
            print("\n--- Abbreviation Table Validation ---")
            let validationIssues = vm.validateAbbreviationTable()
            for issue in validationIssues {
                print(issue)
            }

            print("\n--- Detailed Abbreviation Analysis ---")
            let abbrevInfo = vm.analyzeAbbreviationTable()

            // Show all abbreviations with their content
            for info in abbrevInfo {
                let status = info.isValid ? "✅" : "❌"
                let address = String(info.address, radix: 16, uppercase: true)
                if let content = info.content {
                    print("  \(status) \(info.tableType)[\(info.abbrevNumber)]: 0x\(address) = '\(content)'")
                } else if let error = info.error {
                    print("  \(status) \(info.tableType)[\(info.abbrevNumber)]: 0x\(address) ERROR: \(error)")
                } else if !info.isValid {
                    print("  \(status) \(info.tableType)[\(info.abbrevNumber)]: 0x\(address) (null address)")
                }
            }

        } else {
            print("❌ No abbreviation entries loaded!")
            print("This suggests a problem with abbreviation table loading.")
            print("Header address: 0x\(String(vm.header.abbreviationTableAddress, radix: 16, uppercase: true))")
        }

        if vm.version.rawValue >= 5 {
            print("\n=== UNICODE TRANSLATION TABLE ===")
            print("Unicode Translation Table: \(vm.unicodeTranslationTable.count) entries")
            if !vm.unicodeTranslationTable.isEmpty {
                print("All Unicode mappings:")
                for (zscii, unicode) in vm.unicodeTranslationTable.sorted(by: { $0.key < $1.key }) {
                    print("  ZSCII \(zscii) -> Unicode U+\(String(unicode, radix: 16, uppercase: true))")
                }
            }
        }
    }

    private func analyzeRoutines(_ vm: ZMachine) {
        print("Routine Analysis:")
        print("Initial PC: 0x\(String(vm.programCounter, radix: 16, uppercase: true))")
        print("Call Stack Depth: \(vm.callStack.count)")
        print("Local Variables: \(vm.locals.count)")
        print("Evaluation Stack Size: \(vm.evaluationStack.count)")

        // Note: Full routine disassembly would require more complex analysis
        print("\nNote: Full routine disassembly not implemented in this version")
        print("Use a dedicated Z-Machine disassembler for detailed bytecode analysis")
    }
}

/// Command for automated execution of Z-Machine story files using instruction scripts.
///
/// `AutoplayCommand` provides automated execution of story files through pre-written
/// instruction scripts, enabling automated testing, walkthrough verification, and
/// continuous integration workflows for interactive fiction development.
///
/// ## Features
/// - Instruction file parsing with support for complex directives
/// - Counter management and pattern matching for dynamic gameplay
/// - Loop and conditional execution for complex automation scenarios
/// - Automated healing sequences for combat-intensive games
/// - Manual-advance mode for debugging and hybrid input
/// - Auto-timing based on game output length or fixed intervals
///
/// ## Instruction File Format
/// ```
/// # Comments start with # and are ignored
/// north                    # Plain commands sent directly to game
/// get lamp
/// turn on lamp
///
/// # Counter management
/// !SET wounds = 0
///
/// # Pattern tracking
/// !TRACK regex "hits you" wounds
///
/// # Loop structures
/// !LOOP
///   attack troll with sword
/// !UNTIL regex "black smoke"
///
/// # Conditional execution
/// !IFCOUNTER wounds > 0 THEN
///   go to safe room
///   !HEAL wounds
/// !END
///
/// # Wait and healing automation
/// !WAIT 35                 # Execute 35 "wait" commands rapidly
/// !HEAL                    # Automated healing sequence
/// ```
///
/// ## Example Usage
/// ```bash
/// # Basic autoplay execution
/// zil autoplay game.z5 walkthrough.txt
///
/// # Manual debugging mode with verbose output
/// zil autoplay game.z5 test.txt --manual --verbose
///
/// # Fixed timing interval
/// zil autoplay game.z5 script.txt --interval 2
/// ```
struct AutoplayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "autoplay",
        abstract: "Execute story file with automated instruction script"
    )

    /// Story file to execute (.z3, .z4, .z5, .z6, .z8).
    ///
    /// The story file must be a valid Z-Machine bytecode file. The autoplay
    /// system will load and execute the story while following the instruction
    /// script for automated input.
    @Argument(help: "Z-Machine story file to execute")
    var storyFile: String

    /// Instruction file containing autoplay directives.
    ///
    /// Plain text file with game commands and control directives. Supports
    /// comments, counter management, pattern matching, loops, conditionals,
    /// and automated sequences like healing.
    @Argument(help: "Instruction file with autoplay directives")
    var instructionFile: String

    /// Fixed delay between commands in seconds.
    ///
    /// Overrides automatic timing with a fixed delay. When not specified,
    /// timing is calculated automatically based on game output length:
    /// - Short output (< 40 chars): 1 second
    /// - Medium output (40-160 chars): 2 seconds
    /// - Long output (> 160 chars): 4 seconds
    @Option(help: "Fixed delay between commands (seconds)")
    var interval: Int?

    /// Enable manual-advance mode for debugging.
    ///
    /// In manual mode, the system waits for user input before executing
    /// each autoplay command. If the user presses Enter, the next autoplay
    /// command executes. If the user types a command, that command is sent
    /// to the game instead of the autoplay command.
    @Flag(help: "Enable manual-advance mode for interactive debugging")
    var manual = false

    /// Increase verbosity of autoplay execution.
    ///
    /// Multiple flags increase detail level:
    /// - Default: Basic progress information
    /// - -v: Show each command before execution
    /// - -vv: Show counter updates and pattern matches
    /// - -vvv: Show detailed execution trace
    @Flag(name: .shortAndLong, help: "Increase verbosity (-v, -vv, -vvv)")
    var verbose: Int

    /// Executes the autoplay command with the specified options.
    ///
    /// This method loads the story file, parses the instruction file, and
    /// orchestrates the automated execution with the configured timing and
    /// interaction modes.
    ///
    /// - Throws: Various errors related to file access, instruction parsing,
    ///           VM initialization, or execution failures
    func run() throws {
        print("ZIL Autoplay - Automated Story File Execution")
        print("Story file: \(storyFile)")
        print("Instructions: \(instructionFile)")
        if let interval = interval {
            print("Fixed interval: \(interval) seconds")
        } else {
            print("Auto-timing: Based on output length")
        }
        if manual {
            print("Manual-advance mode: Enabled")
        }
        print("Verbosity level: \(verbose)")
        print()

        // Validate story file exists and is valid format
        guard FileManager.default.fileExists(atPath: storyFile) else {
            print("Error: Story file not found: \(storyFile)")
            throw ExitCode.validationFailure
        }

        guard storyFile.hasSuffix(".z3") || storyFile.hasSuffix(".z4") ||
              storyFile.hasSuffix(".z5") || storyFile.hasSuffix(".z6") ||
              storyFile.hasSuffix(".z8") else {
            print("Error: Story file must be a Z-Machine file (.z3, .z4, .z5, .z6, .z8)")
            throw ExitCode.validationFailure
        }

        // Validate instruction file exists
        guard FileManager.default.fileExists(atPath: instructionFile) else {
            print("Error: Instruction file not found: \(instructionFile)")
            throw ExitCode.validationFailure
        }

        // Create autoplay configuration
        let config = AutoplayInstructionManager.AutoplayConfig(
            interval: interval,
            isManualMode: manual,
            verbosity: verbose
        )

        // Initialize autoplay manager
        let autoplayManager = AutoplayInstructionManager(config: config)

        do {
            // Load instruction file
            print("Loading instruction file...")
            try autoplayManager.loadInstructions(from: instructionFile)

            // Initialize Z-Machine VM
            print("Initializing Z-Machine VM...")
            let vm = ZMachine()
            let storyURL = URL(fileURLWithPath: storyFile)
            try vm.loadStoryFile(from: storyURL)

            print("✓ Story file loaded successfully")
            print("  Version: \(vm.version.rawValue)")
            print("Starting autoplay execution...")
            print()

            // Execute autoplay
            try autoplayManager.execute(with: vm)

        } catch let error as InstructionError {
            print("Instruction file error: \(error.localizedDescription)")
            throw ExitCode.validationFailure
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

// MARK: - CLI I/O Delegates

/// Input delegate for command-line interface
class CLIInputDelegate: TextInputDelegate {
    func requestInput() -> String {
        print("> ", terminator: "")

        // Check if stdin is available and read input
        if let input = readLine() {
            return input
        } else {
            // EOF detected (stdin closed) - exit gracefully
            print("\n[Input stream closed - terminating]")
            _DarwinFoundation3.exit(0)
        }
    }

    func requestInputWithTimeout(timeLimit: TimeInterval) -> (input: String?, timedOut: Bool) {
        // Simple implementation - just return standard input for now
        // A more sophisticated implementation would handle actual timeouts
        let input = requestInput()
        return (input, false)
    }
}

/// Output delegate for command-line interface
class CLIOutputDelegate: TextOutputDelegate {
    func didOutputText(_ text: String) {
        print(text, terminator: "")
    }

    func didQuit() {
        print("\n[Game ended]")
    }
}
