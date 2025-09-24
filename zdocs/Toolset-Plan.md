# Detailed ZIL Development Environment Implementation Plan

Based on the architectural design from the ZIL expert advisor, here's an expanded implementation plan with detailed sub-phases:

---

## **Phase 1: Core Infrastructure**

### **1.1 Swift Package Structure Setup**
- Configure Package.swift with targets:
  - `ZILInterpreter` library target (core functionality)
  - `zil` executable target (unified command-line tool)
- Set up source directory structure with proper target separation
- Configure swift-argument-parser dependency for CLI tool
- Create test target structure with unit and integration test directories

### **1.2 Foundational Error Handling System**
- Implement hierarchical error types (`ZILError`, `ParseError`, `RuntimeError`, `AssemblyError`)
- Create `SourceLocation` struct for precise error reporting with file, line, column
- Build `DiagnosticManager` for collecting and reporting multiple errors
- Implement error recovery strategies for each component (lexer, parser, assembler, VM)
- Create error formatting utilities for user-friendly error messages

### **1.3 File Management Infrastructure**
- Implement `FileManager` abstraction for cross-platform file operations
- Create include file resolution system for ZIL's `<INSERT-FILE>` directive
- Build path utilities for handling relative includes and project structures
- Implement file watching capabilities for development workflow
- Create temporary file management for intermediate compilation artifacts

### **1.4 Shared Data Structures**
- Design `SourceLocation` for tracking source positions through compilation pipeline
- Create `Version` enum for Z-Machine version handling (V3, V4, V5, V6, V8)
- Implement `ByteStream` utilities for efficient binary data processing
- Build `StringTable` and `ObjectTable` structures shared across components
- Create debugging and inspection utilities for development tools

---

## **Phase 2: ZIL Compiler Implementation**

### **2.1 ZIL Lexical Analysis**
- Implement `ZILLexer` class with character-by-character processing
- Create token definitions for all ZIL syntax elements:
  - Angle brackets `< >` for function calls
  - Parentheses `( )` for lists and property definitions
  - String literals with escape sequence handling
  - Atoms (identifiers) with ZIL naming conventions
  - Numbers (16-bit signed integers)
  - Variable references (`,GLOBAL` and `.LOCAL`)
  - Comments (`;` line comments and `"` string comments)
- Build lexer state management for proper bracket matching
- Implement robust error recovery for malformed input

### **2.2 ZIL Abstract Syntax Tree Design**
- Define protocol-based AST node hierarchy with `ZILNode` protocol
- Create expression types (`ZILExpression` enum):
  - Atoms, numbers, strings, lists
  - Function calls with argument lists
  - Global and local variable references
- Design declaration types (`ZILDeclaration` enum):
  - Routine declarations with parameters and local variables
  - Object declarations with properties, flags, and hierarchy
  - Global variable and constant declarations
  - Syntax definitions for parser integration
  - Macro definitions with parameter lists
- Implement visitor pattern for AST traversal and transformation

### **2.3 ZIL Parser Implementation**
- Build recursive descent parser for S-expression syntax
- Implement parsing methods for each ZIL construct:
  - `parseRoutine()` for function definitions with parameter handling
  - `parseObject()` for game entity definitions with property parsing
  - `parseGlobal()` and `parseConstant()` for variable declarations
  - `parseSyntax()` for parser syntax definitions
  - `parseMacro()` for macro system integration
- Create robust error handling with synchronization points
- Implement lookahead and backtracking for ambiguous constructs

### **2.4 Symbol Table Management**
- Design multi-scope symbol table with stack-based scope management
- Implement symbol types for different ZIL entities:
  - Routines with parameter lists and return types
  - Objects with property definitions and flag sets
  - Global variables with type information
  - Constants with compile-time values
  - Local variables with scope tracking
- Create symbol resolution algorithm with proper scoping rules
- Build cross-reference tracking for undefined symbol detection

### **2.5 Macro Processing System**
- Implement `MacroProcessor` for ZIL's macro system
- Create macro definition storage and parameter binding
- Build macro expansion engine with recursive expansion support
- Implement hygiene system to prevent variable capture
- Create preprocessor for handling compile-time directives
- Add debugging support for macro expansion tracking

### **2.6 Semantic Analysis**
- Implement `SemanticAnalyzer` class with comprehensive validation
- Create symbol resolution system:
  - Link variable references to definitions across scopes
  - Resolve routine calls to routine definitions
  - Connect object property references to object definitions
  - Validate flag usage against flag definitions
- Build type checking system:
  - Ensure proper usage of ZIL constructs (objects, routines, properties)
  - Validate routine parameter counts and types
  - Check property access patterns and default values
  - Verify flag operations on appropriate objects
- Implement scope validation:
  - Check local variable usage within proper routine scope
  - Validate global variable accessibility
  - Ensure proper parameter and auxiliary variable usage
- Create forward reference resolution:
  - Handle routines and objects defined after use
  - Resolve circular dependencies between constructs
  - Build dependency graphs for proper initialization order
- Integrate with symbol table system:
  - Connect parsed AST nodes with symbol definitions
  - Generate cross-reference tables for IDE support
  - Provide symbol usage analysis and reporting

### **2.7 ZAP Assembly Code Generation**
- Design `ZAPCodeGenerator` class with instruction emission framework
- Implement code generation for each ZIL construct:
  - Routine definitions → `.FUNCT` directives with proper parameter handling
  - Object definitions → object table entries with property encoding
  - Control flow → conditional branches with label generation
  - Arithmetic expressions → Z-Machine instruction sequences
  - Function calls → `CALL` instructions with argument passing
- Build expression compiler:
  - Convert ZIL expressions to Z-Machine instruction sequences
  - Handle operator precedence and associativity
  - Generate efficient code for common patterns
  - Support for all Z-Machine data types and operations
- Create object and property management:
  - Generate object table with hierarchical relationships
  - Encode property values with proper type handling
  - Build flag management and bit manipulation code
  - Handle object location and movement operations
- Implement memory layout planning:
  - Organize global variables and constants
  - Plan string table layout with compression
  - Generate dictionary entries for parser integration
  - Create proper memory segment organization
- Create label management system for forward and backward references
- Build optimization passes for instruction selection and register allocation
- Build debugging support:
  - Generate source line mapping for debugging
  - Create symbol information for development tools
  - Provide assembly output formatting options
  - Support for conditional compilation and optimization levels

---

## **Phase 3: Z-Machine Assembler Implementation**

### **3.1 ZAP Assembly Language Parser**
- Implement line-by-line parser for columnar ZAP format
- Create directive parsing for assembly constructs:
  - `.FUNCT` function declarations with parameter lists
  - `.SEGMENT` memory region organization
  - `.BYTE` and `.WORD` data definitions
  - `.GSTR` string table entries
  - `.INSERT` file inclusion handling
- Build instruction parsing with operand type detection
- Implement comment handling and whitespace management

### **3.2 Assembly Instruction Representation**
- Design `ZAPInstruction` hierarchy for different instruction types
- Create operand type system:
  - Immediate values (numeric literals)
  - Variables (local and global references)
  - Labels (branch targets and addresses)
  - Objects and properties (game entity references)
- Implement instruction validation for operand count and types
- Build instruction formatting utilities for debugging output

### **3.3 Symbol Resolution System**
- Implement two-pass assembly with symbol collection and resolution
- Create `SymbolResolver` with forward reference tracking
- Design symbol types for different assembly entities:
  - Labels with address values
  - Functions with entry points
  - Objects with memory locations
  - Strings with packed addresses
- Build cross-reference resolution with circular dependency detection
- Implement symbol table output for debugging and linking

### **3.4 Memory Layout Management**
- Design `MemoryLayoutManager` for Z-Machine memory organization
- Implement three memory regions with proper access control:
  - Dynamic memory (read/write): Header, objects, globals, stack
  - Static memory (read-only): Dictionary, tables, unchanging data
  - High memory (execute-only): Packed routines and strings
- Create address allocation system with proper alignment
- Build memory image generation with region boundary management
- Implement version-specific memory limits and addressing modes

### **3.5 Z-Machine Instruction Encoding**
- Implement `InstructionEncoder` for all Z-Machine opcode formats:
  - Short form (0-1 operands) with type encoding
  - Long form (exactly 2 operands) with type flags
  - Variable form (0-4 operands) with type bytes
  - Extended form (VAR opcodes) for versions 5+
- Create operand encoding system with proper type detection
- Build packed address calculation for routines and strings
- Implement version-specific instruction availability checking

### **3.6 Story File Generation**
- Design `StoryFileBuilder` with version-specific header generation
- Implement header field calculation:
  - Memory layout pointers with proper addressing
  - File length and checksum calculation
  - Version-specific feature flags
  - Screen dimensions and color support (later versions)
- Create object table generation with property encoding
- Build dictionary generation with word sorting and encoding
- Implement string table generation with ZSCII compression
- Add story file validation and integrity checking

---

## **Phase 4: Z-Machine Virtual Machine Implementation**

### **4.1 Story File Loading and Validation**
- Implement `StoryFileLoader` with comprehensive validation
- Create header parsing with version detection and feature checking
- Build memory image reconstruction from story file sections
- Implement checksum verification and integrity checking
- Create version compatibility checking and feature detection
- Build error reporting for malformed or unsupported story files

### **4.2 Z-Machine Memory Management**
- Design `ZMachineMemory` with three-region architecture
- Implement memory access control with region-specific permissions:
  - Dynamic memory: Full read/write access
  - Static memory: Read-only access with write protection
  - High memory: Execute-only access with read protection
- Create efficient byte and word access with endianness handling
- Build memory protection system with bounds checking
- Implement memory debugging and inspection tools

### **4.3 Execution Engine Core**
- Design `InstructionProcessor` with fetch-decode-execute cycle
- Implement program counter management with proper branching
- Create stack management with overflow/underflow protection
- Build call stack management for routine invocation
- Implement instruction decoding for all opcode formats
- Create execution statistics and profiling capabilities

### **4.4 Z-Machine Instruction Set Implementation**
- Implement complete instruction set organized by category:
  - **Arithmetic**: `ADD`, `SUB`, `MUL`, `DIV`, `MOD`, `RANDOM`
  - **Logic/Comparison**: `EQUAL?`, `LESS?`, `GRTR?`, `ZERO?`, `AND`, `OR`, `NOT`
  - **Memory Access**: `LOAD`, `STORE`, `LOADW`, `STOREW`, `LOADB`, `STOREB`
  - **Object Manipulation**: `GET_PROP`, `PUT_PROP`, `GET_SIBLING`, `INSERT_OBJ`, etc.
  - **Control Flow**: `JUMP`, `JZ`, `JE`, `JL`, `JG`, `CALL`, `RET`, `RTRUE`, `RFALSE`
  - **Input/Output**: `READ`, `PRINT`, `PRINT_RET`, `NEW_LINE`, `SPLIT_WINDOW`
  - **Stack Operations**: `PUSH`, `PULL`, `CATCH`, `THROW` (version-specific)
- Create instruction dispatch system with jump tables for performance
- Implement version-specific instruction availability and behavior
- Build instruction tracing and debugging support

### **4.5 Object System Implementation**
- Design `ObjectManager` for game entity management
- Implement object tree navigation (parent, sibling, child relationships)
- Create property system with get/set operations and default values
- Build attribute system with flag testing and modification
- Implement object movement and location tracking
- Create object validation and integrity checking
- Build object debugging and inspection tools

### **4.6 Text Processing System**
- Implement `TextProcessor` with ZSCII encoding/decoding
- Create Z-character compression with alphabet table support
- Build string decoding with abbreviation expansion
- Implement text output formatting with style support
- Create input processing with dictionary lookup integration
- Build Unicode support for Z-Machine version 8
- Implement text debugging and character encoding inspection

### **4.7 Input/Output System**
- Design `IOManager` with window management support
- Implement text output with proper formatting and styling
- Create input system with line editing and history
- Build window system for screen splitting (versions 3+)
- Implement color and style support (versions 5+)
- Create mouse input handling (versions 5+)
- Build sound effect support (versions 4+) with proper fallbacks

### **4.8 Save/Restore System**
- Implement `SaveManager` with Quetzal format support
- Create memory state serialization with compression
- Build stack state preservation and restoration
- Implement save file validation and version checking
- Create save slot management and metadata handling
- Build save file debugging and inspection tools

---

## **Phase 5: Command-Line Tools & Integration**

### **5.1 CLI Tool Implementation**
- Build unified `zil` command-line tool with subcommands:

#### **5.1.1 `zil build` Subcommand**
- Compile ZIL source to ZAP assembly and/or Z-Machine bytecode
- Options:
  - `--assembly-only` / `-S`: Stop after compilation, output ZAP assembly
  - `--output` / `-o`: Specify output file path
  - `--version`: Target Z-Machine version (3, 4, 5, 6, 8)
  - `--debug`: Generate debug symbols
  - `--optimize`: Optimization level
- Maintain `.zil/` build directory (similar to SwiftPM's `.build/`)
- Track source file dependencies in manifest for incremental compilation
- Support project-level configuration files

#### **5.1.2 `zil run` Subcommand**
- Compile + assemble (if necessary) and launch game in VM
- Options:
  - `--debug`: Enable VM debug mode
  - `--transcript`: Record gameplay transcript
  - `--save-dir`: Specify save game directory
- Automatic rebuilding if source files have changed
- Terminal-based I/O with proper text formatting

#### **5.1.3 `zil analyze` Subcommand**
- Analyze structure and content of compiled Z-Machine files
- Similar to `otool` for examining binary file structure
- Options:
  - `--header`: Show story file header information
  - `--objects`: Display object tree and properties
  - `--dictionary`: Show parser dictionary contents
  - `--strings`: List all strings and abbreviations
  - `--routines`: Show routine table and disassembly
  - `--memory`: Display memory layout and usage
- If no file specified, automatically builds current project and analyzes result

### **5.2 End-to-End Integration Testing**
- Create test harness for complete compilation pipeline
- Build regression tests using existing Infocom games:
  - Compile and assemble each game successfully
  - Verify bytecode compatibility with reference interpreters
  - Test runtime behavior against known game states
- Implement compatibility testing across Z-Machine versions
- Create performance benchmarking suite
- Build memory usage and resource consumption testing

### **5.3 Development Tools and Debugging**
- Implement comprehensive error reporting with source location mapping
- Create debug symbol generation and debugging interface
- Build profiling tools for performance analysis
- Implement memory inspection and object tree visualization
- Create instruction tracing and execution logging
- Build interactive debugger with breakpoint support

### **5.4 Documentation and Examples**
- Create comprehensive API documentation for library components
- Build tutorial examples for each tool and workflow
- Implement example game projects demonstrating language features
- Create migration guides for existing ZIL projects
- Build troubleshooting guides and FAQ documentation

### **5.5 Performance Optimization**
- Profile and optimize critical execution paths
- Implement instruction dispatch optimization with computed gotos
- Create memory access optimization with caching strategies
- Build string processing optimization with efficient algorithms
- Implement save/restore optimization with incremental saves
- Create startup time optimization with lazy loading

### **5.6 Quality Assurance and Testing**
- Implement comprehensive unit test suite for all components
- Create integration tests for cross-component communication
- Build fuzz testing for robust error handling
- Implement property-based testing for algorithm verification
- Create continuous integration pipeline with automated testing
- Build release validation with full game compatibility testing

This detailed implementation plan provides a systematic approach to building a complete, production-ready ZIL development environment that can handle the full complexity of interactive fiction development while maintaining high code quality and performance standards.