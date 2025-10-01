# Swift ZIL - Interactive Fiction Development Environment

A complete development environment for interactive fiction using ZIL (Zork Implementation Language) and the Z-Machine virtual machine, implemented in Swift.

## Overview

This project provides a modern Swift implementation of the classic ZIL toolchain used to create interactive fiction games like Zork, Enchanter, and other Infocom classics. It includes a compiler, assembler, and virtual machine that can build and run Z-Machine story files across all supported versions (3, 4, 5, 6, and 8).

**Note**: This project was developed with the aid of Claude Code as part of experiments to learn how to make effective use of AI-assisted development tools.

## Features

- **ZIL Compiler**: Transforms ZIL source code into ZAP assembly language
- **Z-Machine Assembler**: Converts ZAP assembly into Z-Machine bytecode
- **Z-Machine Virtual Machine**: Executes Z-Machine story files for all versions
- **Unified CLI Tool**: Single `zil` command with multiple subcommands
- **Comprehensive Error Handling**: Detailed diagnostics with source location tracking
- **Cross-Platform**: Supports Apple platforms (macOS, iOS, tvOS, watchOS, visionOS)

## Architecture

The implementation consists of:

- **ZEngine Library**: Core functionality for compilation, assembly, and execution
- **CLI Tool**: Command-line interface with `build`, `run`, and `analyze` subcommands
- **Comprehensive Testing**: Full test coverage using Swift Testing framework

### Z-Machine Version Support

| Version | Memory Limit | Features |
|---------|-------------|----------|
| v3 | 128KB | Basic text adventures |
| v4 | 128KB | Sound effects, extended objects |
| v5 | 256KB | Color support, mouse input |
| v6 | 256KB | Graphics, multiple windows |
| v8 | 256KB+ | Unicode support, modern extensions |

## Installation

### Requirements

- Swift 6.2 or later
- Xcode 26.0+ (for Apple platforms)

### Building

```bash
# Clone the repository
git clone <repository-url>
cd swift-zil

# Build the project
swift build

# Run tests
swift test
```

## Usage

### Command Line Interface

The `zil` tool provides three main commands:

#### Build Command
Compile ZIL source to Z-Machine bytecode:

```bash
swift run zil build [source] --output game.z5 --version 5
```

Options:
- `--output, -o`: Output file path
- `--assembly-only, -S`: Stop after compilation, output ZAP assembly only
- `--version`: Target Z-Machine version (3, 4, 5, 6, 8)
- `--debug`: Generate debug symbols
- `--optimize`: Optimization level (0-2)

#### Run Command
Compile (if necessary) and launch game in Z-Machine VM:

```bash
swift run zil run [source] --debug
```

Options:
- `--debug`: Enable VM debug mode
- `--transcript`: Record gameplay transcript to file
- `--save-dir`: Directory for save games

#### Analyze Command
Analyze structure and content of Z-Machine story files:

```bash
swift run zil analyze [story-file] --all
```

Options:
- `--header`: Show story file header information
- `--objects`: Display object tree and properties
- `--dictionary`: Show parser dictionary contents
- `--strings`: List all strings and abbreviations
- `--routines`: Show routine table and disassembly
- `--memory`: Display memory layout and usage
- `--all`: Show all sections

## Language Support

### ZIL Language Features

ZIL is a Lisp-like domain-specific language for interactive fiction:

- S-expression syntax with `< >` brackets
- Objects with properties, flags, and hierarchical relationships
- Rooms with exits and descriptions
- Routines with local variables and control flow
- Global variables and constants
- Parser integration with syntax definitions
- Event system with interrupts and scheduling

### Example ZIL Code

```zil
<OBJECT LANTERN
    (IN LIVING-ROOM)
    (SYNONYM LAMP LANTERN LIGHT)
    (ADJECTIVE BRASS)
    (DESC "brass lantern")
    (FLAGS TAKEBIT LIGHTBIT)
    (ACTION LANTERN-F)>

<ROUTINE LANTERN-F ()
    <COND (<VERB? TAKE>
           <MOVE ,LANTERN ,PLAYER>
           <TELL "Taken." CR>)
          (<VERB? LIGHT>
           <FSET ,LANTERN ,ONBIT>
           <TELL "The lantern is now on." CR>)>>
```

## Development Status

### Phase 1: Core Infrastructure ✅ COMPLETE
- [x] Swift Package structure with multiple targets
- [x] Comprehensive error handling system with diagnostics
- [x] File management infrastructure
- [x] Shared data structures and Z-Machine types
- [x] Binary I/O utilities and byte stream processing
- [x] Complete test coverage (46 tests across 28 suites)

### Phase 2: ZIL Compiler 🔄 NEARLY COMPLETE
- [x] Lexical analyzer for ZIL syntax
- [x] Parser for S-expressions and language constructs
- [x] Abstract Syntax Tree (AST) design
- [x] Symbol table management with scoping and type checking
- [x] Comprehensive semantic analysis system
- [◐] ZAP code generation with full ZIL language support

### Phase 3: Z-Machine Assembler ✅ COMPLETE
- [x] ZAP assembly parser
- [x] Instruction encoding for all Z-Machine versions
- [x] Memory layout and story file generation
- [x] Symbol resolution and linking

### Phase 4: Z-Machine Virtual Machine 🔄 NEARLY COMPLETE
- [x] Story file loader and validator for all versions
- [x] Instruction processor for complete opcode set
- [x] Memory management system with proper region handling
- [x] ZIP-style windowed terminal interface with authentic scrolling
- [x] Object tree loading and property management
- [x] Dictionary and string processing with Unicode support
- [ ] Save/restore functionality with Quetzal format

### Phase 5: Advanced Features 🚧 IN PROGRESS
- [x] Complete game compatibility (Zork I fully playable)
- [x] Authentic terminal renderer matching original ZIP behavior
- [ ] Interactive debugger and development tools
- [ ] Optimization passes for generated code
- [ ] Cross-compilation support
- [ ] Enhanced development workflow tools

## Current Status

**🔄 LARGELY FUNCTIONAL** - The Swift ZIL toolchain has core functionality working across all components. The Z-Machine virtual machine successfully runs existing version 3 story files (proven with Zork I). The compiler and assembler can process valid input and produce correct output, but some ZIL language constructs remain unimplemented. Full end-to-end game compilation from ZIL source has not yet been demonstrated.

## Testing

The project includes comprehensive test coverage:

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter ErrorHandlingTests
```

Test categories:
- Error handling and diagnostics
- Data structure validation
- Byte stream operations
- Utility function verification
- Z-Machine version compatibility

## Contributing

This project follows standard Swift development practices:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

### Code Style

- Use SwiftLint for consistent formatting
- Add comprehensive documentation for public APIs
- Include unit tests for all new functionality
- Follow existing patterns for error handling

## Documentation

- [ZIL Language Reference](zdocs/ZIL.md) - Complete ZIL language specification
- [Z-Machine Assembler Reference](zdocs/Z-Assembler.md) - ZAP assembly language documentation
- [Z-Machine Bytecode Format](zdocs/Z-Machine-Bytecode.md) - Binary format and VM specification
- [Implementation Plan](zdocs/Toolset-Plan.md) - Detailed development roadmap
- [Changelog](CHANGELOG.md) - Version history and changes

## License

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

## References

- [Official Z-Machine Specification](http://inform-fiction.org/zmachine/standards/z1point1/index.html)
- [Interactive Fiction Archive](https://www.ifarchive.org/)
- [Infocom Documentation Project](http://www.infocom-if.org/)

## Acknowledgments

This implementation is inspired by the original Infocom development tools and the rich history of interactive fiction. Special thanks to the Interactive Fiction community for preserving and documenting these classic systems.