# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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