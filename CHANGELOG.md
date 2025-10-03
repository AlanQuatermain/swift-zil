# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.2] - 2025-10-02

### Added
- **Comprehensive Autoplay CLI Command** 🤖
  - New `zil autoplay` command for automated Z-Machine story execution
  - Complete instruction script system for testing, walkthroughs, and CI workflows
  - Counter management with `!SET counter = value` directive
  - Pattern tracking with `!TRACK regex "pattern" counter` for dynamic gameplay monitoring
  - Loop structures with `!LOOP ... !UNTIL regex "pattern"` for complex automation scenarios
  - Conditional execution using `!IFCOUNTER name op value THEN ... !END` blocks
  - Automated healing sequences with `!HEAL [counter]` including lamp state management
  - Wait sequences with `!WAIT turns` and `!WAIT-UNTIL regex "pattern"` for timing control
  - Manual-advance mode for debugging and hybrid automated/manual gameplay
  - Auto-timing based on game output length or configurable fixed intervals

### Improved
- **Enhanced Z-Machine Terminal Integration**
  - AutoplayTerminalDelegate subclasses ZMachineTerminalDelegate for seamless integration
  - Proper cursor positioning ensures autoplay commands appear exactly where users expect on prompt line
  - Output accumulation across multiple terminal calls enables reliable pattern matching
  - Queued command execution bypasses manual mode for automated sequences (HEAL, WAIT)
  - Scope-aware pattern matching with Swift native Regex for optimal performance

### Technical Details
- Clean separation of instruction consumption vs semantic processing prevents double-increment bugs
- Swift native Regex replaces NSRegularExpression for better performance and type safety
- Output buffer accumulation ensures patterns spanning multiple `didOutputText()` calls are detected
- Manual mode respects user control for regular commands while automating lengthy sequences
- Comprehensive error handling with regex compilation validation and graceful fallbacks

### Compiler Progress
- Phase 1 ZIL language extensions completed (SYNTAX, SYNONYM, DEFMAC, BUZZ declarations)
- Table literal support and variable arguments system implemented
- FORM construction engine and compile-time evaluation framework operational
- Enhanced string processing and text compression systems ready
- Phases 2-3 pending: Object Property System and Parser Table Generation

This release transforms the ZIL development environment into a comprehensive testing and automation platform, enabling continuous integration workflows and automated game verification while maintaining the robust compilation pipeline.

## [0.4.1] - 2025-10-01

### Added
- Proper terminal renderer based on the classic UNIX ZIP implementation.

## [0.4.0] - 2025-10-01

### Added
- **Full Game Compatibility Achievement** 🎮
  - Complete Zork I playability with all 250 objects properly loaded
  - Fixed critical "You can't see any window here!" bug by enabling Object 243 ("kitchen window")
  - All Z-Machine versions now use consistent object table parsing logic

### Fixed
- **ObjectTree Loading System** - Major breakthrough resolving core Z-Machine compatibility issues
  - Fixed ObjectTree memory access by providing full story file data instead of memory segments
  - Objects are in dynamic memory but property tables are in static memory - both now accessible
  - Replaced hardcoded 255 object assumption with proper boundary detection using Object 1's property table address
  - Added robust object validation checking parent/child/sibling relationships and property table addresses

- **Z-Machine Instruction Execution**
  - Fixed CALL to routine address 0 to properly store return value (returns 0 immediately per spec)
  - Fixed Z-Machine attribute bit ordering for correct TEST_ATTR/SET_ATTR behavior
  - Corrected big-endian word ordering: word 0 (attributes 0-15) maps to high bits
  - Fixed bit position calculation for v3 (32-bit) and v4+ (48-bit) attribute layouts

- **Dictionary and Text Processing**
  - VM now handles dictionary offsets and TEST instructions correctly
  - Enhanced Unicode translation and save/restore system integration
  - Resolved "division by zero" errors in published games caused by incorrect operand size decoding

### Improved
- Enhanced CLI to handle cases where no objects are loaded (prevents range crashes)
- Removed extensive debugging code, resulting in clean production-ready implementation
- All integration tests pass including VM loading, instruction encoding, memory layout validation

### Technical Details
- ObjectTree now loads exactly 250 objects (matching external tools like infodump)
- Attribute 3 now correctly maps to bit position 28 (0x10000000) not 12 (0x1000)
- Perfect consistency between assembler instruction encoding and VM instruction decoding
- Complete Z-Machine instruction set support across all versions (v3, v4, v5, v6, v8)

## [0.3.0] - 2025-09-26

### Fixed
- **Critical Instruction Encoding Bugs** - Resolved all 9 failing tests in ZAP Code Generator and Z-Machine Assembler
  - Fixed 1OP instruction encoding: operand type bits now correctly encoded in bits 5-4 of opcode byte
  - Fixed 2OP instruction encoding: operand type bits now correctly encoded in bits 6-5 of opcode byte
  - Fixed memory layout manager global address calculation to start from address 64 (after header)
  - Fixed SOUND instruction version requirement from V3+ to correct V4+ per Z-Machine specification

- **ZAP Code Generator Issues**
  - Fixed REPEAT loop operand processing bug where dropFirst() incorrectly skipped first body statement
  - Updated VERB? test expectations to match correct EQUAL? 'PRSA,verb expansion
  - Ensured proper tab-separated instruction formatting throughout

### Technical Details
- REPEAT syntax: `(REPEAT action1 action2...)` not `(REPEAT () action1 action2...)`
- VERB? ZIL construct compiles to `EQUAL? 'PRSA,verb` ZAP instruction
- 1OP operand types: bits 5-4 encode small/large/variable (00/01/10)
- 2OP operand types: bit 6 = first operand type, bit 5 = second operand type
- Global variables: allocated sequentially starting at address 64, 2 bytes each
- Sound effects: introduced in Z-Machine V4, not available in V3

### Improved
- All 368 tests now pass successfully
- Complete ZIL→ZAP→bytecode pipeline fully functional
- Integration tests pass including VM loading and instruction encoding validation

## [0.2.0] - 2025-09-24

### Added
- **Complete ZIL Compiler Implementation (Phase 2)**
  - Comprehensive ZIL parser with complete language support including all constructs
  - Full symbol table management system with scoping and type checking
  - Comprehensive semantic analysis system with unused symbol detection
  - ZAP code generation with full ZIL language support

- **ZAP Assembly Code Generator**
  - Support for all ZIL constructs: objects, routines, conditionals, expressions, loops
  - Z-Machine versions 3-8 compatibility with version-specific instruction generation
  - Optimization system with configurable levels and Boolean expression simplification
  - Error handling with detailed diagnostics and source location tracking

- **Advanced Testing Infrastructure**
  - ZAPCodeGeneratorTests with 1500+ lines covering all language constructs
  - ZILToZAPIntegrationTests comparing generated output with Infocom reference ZAP files
  - Enhanced SemanticAnalysisTests with proper unused symbol detection
  - Parameterized tests for comprehensive coverage validation

### Technical Details
- Complete ZIL-to-ZAP compilation pipeline
- Support for complex language features: COND statements, REPEAT loops, property access
- Advanced symbol table with nested scoping and forward reference resolution
- Type-safe AST representation with comprehensive error recovery
- Optimization passes for Boolean expression simplification and dead code elimination

### Improved
- Fixed compiler warnings throughout codebase
- Added @discardableResult to SymbolTable.defineSymbol for flexible usage
- Replaced placeholder assertions with meaningful test validations
- Better project organization with CLI.swift naming

### Documentation
- Added optimization and refactor planning documents
- Comprehensive test coverage documentation
- ZAP generation examples and reference comparisons

## [0.1.0] - 2025-09-23

### Added
- Initial implementation of Swift ZIL development environment
- **Core Infrastructure (Phase 1 Complete)**
  - Swift Package Manager setup with multi-target architecture
  - ZEngine library for core functionality
  - Unified `zil` CLI tool with `build`, `run`, and `analyze` subcommands
  - Comprehensive error handling system with source location tracking
  - Hierarchical error types: ParseError, AssemblyError, RuntimeError, FileError
  - DiagnosticManager for error collection and reporting with color output
  - ErrorUtils for contextual error formatting and fix suggestions

- **Shared Data Structures**
  - ZValue enum for all ZIL/Z-Machine values (numbers, strings, atoms, objects, etc.)
  - Type-safe identifier structs (ObjectID, RoutineID, PropertyID, FlagID, WordID, TableID)
  - ZMachineVersion enum with feature detection and version comparison
  - ZAddress struct for memory addressing with packed/unpacked conversion
  - Comprehensive Z-Machine constants and standard properties/flags
  - Utility functions for identifier validation and value range checking

- **Binary I/O Infrastructure**
  - Full-featured ByteStream class for binary data processing
  - Read/write operations for bytes, words, and double words
  - String operations with encoding support
  - Position management with seek, skip, and alignment operations
  - Patch operations for binary modification
  - Checksum calculation and validation
  - Variable-length integer encoding/decoding

- **Testing Framework**
  - Complete test coverage using Swift Testing framework
  - 46 tests across 28 test suites
  - Parameterized tests for comprehensive coverage
  - Error handling validation
  - Data structure verification
  - Byte stream operation testing
  - Utility function validation

- **Platform Support**
  - Apple platforms (macOS, iOS, tvOS, watchOS, visionOS) version 26.0+
  - Swift 6.2+ compatibility
  - Cross-platform foundation for future expansion

- **Documentation**
  - Comprehensive README with usage examples
  - Linked documentation for ZIL language, Z-Machine assembler, and bytecode format
  - Implementation plan and development roadmap
  - BSD 3-Clause license

### Technical Details
- Sendable conformance for thread-safe operations
- Comparable implementation for Z-Machine version ordering
- Type-safe error handling with protocol hierarchy
- Comprehensive constant definitions for Z-Machine specification
- Binary stream processing with alignment and padding support
- Memory address packing/unpacking for different Z-Machine versions

This release establishes the foundational infrastructure for the complete ZIL development environment, with robust error handling, comprehensive testing, and a solid architecture for future compiler, assembler, and virtual machine components.