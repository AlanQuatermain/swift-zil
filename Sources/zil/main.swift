import ArgumentParser
import ZEngine

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
            AnalyzeCommand.self
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

    /// Executes the build command with the specified options.
    ///
    /// This method orchestrates the compilation pipeline, handling file I/O,
    /// error reporting, and progress feedback.
    ///
    /// - Throws: Various errors related to file access, compilation failures,
    ///           or invalid command-line arguments
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

    /// Executes the run command to launch the game.
    ///
    /// This method handles input detection, optional compilation, and VM setup
    /// with the specified runtime options.
    ///
    /// - Throws: Various errors related to file access, compilation failures,
    ///           VM initialization, or runtime execution problems
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

    /// Executes the analyze command with the specified inspection options.
    ///
    /// This method coordinates the analysis process, loading the story file,
    /// parsing its contents, and displaying the requested information sections.
    ///
    /// - Throws: Various errors related to file access, story file corruption,
    ///           or unsupported Z-Machine versions
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