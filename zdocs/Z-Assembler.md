# Z-Machine Assembler (ZAP) - Comprehensive Language Reference

## Overview

ZAP (Z-Machine Assembler) is the assembly language used to generate Z-Machine bytecode. It serves as an intermediate representation between high-level ZIL code and the final binary Z-Machine story file. ZAP provides direct access to Z-Machine instructions while maintaining human readability and symbolic references.

## Language Structure

### File Organization

ZAP files are typically organized into several types:
- **Main assembly file**: Contains header information and file inclusions
- **Code segments**: Function definitions and executable code
- **Data segments**: Object definitions, tables, and constants
- **String segments**: Text string definitions

### Basic Syntax

ZAP uses a columnar format with labels, opcodes, and operands:

```zap
LABEL:     OPCODE    OPERAND1, OPERAND2    ; Comment
.DIRECTIVE VALUE
```

### Comments

Comments start with semicolons:

```zap
; This is a full-line comment
EQUAL? PRSA,V?TAKE \FALSE    ; Inline comment
```

## Directives and Structure

### File Structure Directives

#### .INSERT - File Inclusion
```zap
.INSERT "SS:<PLANETFALL>PLANETFALLDAT"    ; Include data file
.INSERT "SS:<PLANETFALL>MISC"             ; Include misc code
```

#### .END - End of File
```zap
.END    ; Marks end of assembly file
```

### Segment Directives

#### .SEGMENT - Code/Data Segments
```zap
.SEGMENT "0"        ; Start new segment
    ; Code goes here
.ENDSEG            ; End segment
```

### Function Definitions

#### .FUNCT - Function Declaration
```zap
.FUNCT FUNCTION-NAME,ARG1,ARG2,"AUX",LOCAL1,LOCAL2
    ; Function body
    ; Automatic RSTACK at end
```

Function parameters:
- **Required arguments**: Listed first
- **"AUX"**: Marks beginning of local variables
- **Local variables**: Auxiliary variables for function use

### Memory Layout Directives

#### Header Structure
```zap
; Z-Machine header
%ZVERSION::    .BYTE   0           ; Z-Machine version
              .BYTE   FLAGS        ; Interpreter flags
%ZORKID::     ZORKID              ; Game ID
%ENDLOD::     ENDLOD              ; End of loadable memory
%START::      START               ; Starting routine address
%VOCAB::      VOCAB               ; Dictionary address
%OBJECT::     OBJECT              ; Object table address
%GLOBAL::     GLOBAL              ; Global variables address
%PURBOT::     IMPURE              ; Start of impure area
%FLAGS::      .WORD   64          ; Status line type
%SERIAL::     .WORD   0           ; Serial number
```

### Data Definition Directives

#### .BYTE - Byte Values
```zap
.BYTE   0           ; Single byte
.BYTE   FLAGS       ; Symbolic byte value
```

#### .WORD - Word Values
```zap
.WORD   0           ; 16-bit word (2 bytes)
.WORD   64          ; Numeric word value
```

#### .GSTR - Global Strings
```zap
.GSTR STR?1,"Hello, world!"              ; Define global string
.GSTR STR?2,"This is a longer string"    ; Another string
```

### Constants and Symbols

#### Symbolic Constants
```zap
TRUE-VALUE=1            ; Boolean true
FALSE-VALUE=0           ; Boolean false
FATAL-VALUE=2          ; Fatal error value

; Object flags with bit positions
TAKEBIT=25             ; Flag number
FX?TAKEBIT=64          ; Flag bitmask (2^25 mod 65536)

; Parser constants
PS?OBJECT=128          ; Parts of speech mask
PS?VERB=64
PS?ADJECTIVE=32
```

#### Labels and Addresses
```zap
STRBEG::               ; String table start
WORDS::                ; Word table start
OBJECT::               ; Object table start
```

## Z-Machine Instructions

### Instruction Format

ZAP instructions map directly to Z-Machine opcodes:

```zap
OPCODE   OPERAND1,OPERAND2,RESULT    ; Basic format
OPCODE   OPERAND >RESULT             ; Store result
OPCODE   OPERAND /LABEL              ; Branch on true
OPCODE   OPERAND \LABEL              ; Branch on false
```

### Operand Types

#### Immediate Values
```zap
EQUAL?  5,10 \FALSE        ; Numeric literals
PRINTI  "Hello"            ; String literals
```

#### Variables
```zap
SET     'GLOBAL-VAR,10     ; Global variable (quote prefix)
SET     LOCAL-VAR,5        ; Local variable (no prefix)
GET     TABLE,0 >RESULT    ; Table access
```

#### Objects and Properties
```zap
IN?     SWORD,ADVENTURER   ; Object references
GETP    OBJECT,PROPERTY    ; Property access
FSET?   OBJECT,FLAG        ; Flag testing
```

### Control Flow Instructions

#### Conditional Operations
```zap
EQUAL?  VAR1,VAR2 /LABEL          ; Branch if equal
ZERO?   COUNTER \LOOP              ; Branch if not zero
GRTR?   SCORE,100 /WIN-GAME       ; Branch if greater
LESS?   HEALTH,0 /DEATH           ; Branch if less
```

#### Function Calls
```zap
CALL    ROUTINE-NAME               ; Simple call
CALL    ROUTINE,ARG1,ARG2          ; Call with arguments
CALL2   ROUTINE,ARG >RESULT        ; Call storing result
ICALL   ROUTINE,ARG1,ARG2          ; Indirect call
```

#### Jumps and Returns
```zap
JUMP    ?LABEL                     ; Unconditional jump
RTRUE                              ; Return true
RFALSE                             ; Return false
RETURN  VALUE                      ; Return value
RSTACK                             ; Return (from stack)
```

### Arithmetic Instructions

```zap
ADD     A,B >RESULT                ; Addition
SUB     A,B >RESULT                ; Subtraction
MUL     A,B >RESULT                ; Multiplication
DIV     A,B >RESULT                ; Division
MOD     A,B >RESULT                ; Modulo
RANDOM  N >RESULT                  ; Random 1 to N
```

### Memory Operations

#### Variable Assignment
```zap
SET     'GLOBAL-VAR,VALUE          ; Set global variable
SET     LOCAL-VAR,VALUE            ; Set local variable
```

#### Table Operations
```zap
GET     TABLE,INDEX >RESULT        ; Get table element
PUT     TABLE,INDEX,VALUE          ; Set table element
GETB    TABLE,INDEX >RESULT        ; Get byte from table
PUTB    TABLE,INDEX,VALUE          ; Set byte in table
```

#### Property Operations
```zap
GETP    OBJECT,PROPERTY >VALUE     ; Get object property
PUTP    OBJECT,PROPERTY,VALUE      ; Set object property
NEXTP   OBJECT,PROPERTY >NEXT      ; Next property
PTSIZE  PROPERTY >SIZE             ; Property size
```

### Object Manipulation

#### Location Operations
```zap
IN?     OBJECT,CONTAINER \FALSE    ; Test containment
LOC     OBJECT >LOCATION           ; Get object location
MOVE    OBJECT,NEW-LOCATION        ; Move object
REMOVE  OBJECT                     ; Remove from game
```

#### Object Traversal
```zap
FIRST?  CONTAINER >CHILD           ; First child object
NEXT?   OBJECT >SIBLING            ; Next sibling object
```

#### Flag Operations
```zap
FSET?   OBJECT,FLAG \FALSE         ; Test object flag
FSET    OBJECT,FLAG                ; Set object flag
FCLEAR  OBJECT,FLAG                ; Clear object flag
```

### Text Output

#### Text Printing
```zap
PRINTI  "Literal text"             ; Print inline string
PRINT   STRING-VAR                 ; Print string variable
PRINTD  OBJECT                     ; Print object description
PRINTN  NUMBER                     ; Print number
PRINTC  CHARACTER                  ; Print character
PRINTT  TABLE,OFFSET               ; Print text from table
CRLF                               ; Print newline
```

#### Advanced Text
```zap
PRINTB  PACKED-STRING              ; Print packed string
PRINTR  "Text and return"          ; Print and return true
```

### Input Operations

```zap
READ    TEXT-BUFFER,PARSE-BUFFER   ; Read player input
INPUT   DEVICE >CHARACTER          ; Read single character
```

### Stack Operations

```zap
PUSH    VALUE                      ; Push to stack
POP     >RESULT                    ; Pop from stack
```

### Program Control

```zap
QUIT                               ; End program
RESTART                            ; Restart program
SAVE    >RESULT                    ; Save game state
RESTORE >RESULT                    ; Restore game state
VERIFY  >RESULT                    ; Verify story file
```

## Label and Branch Targets

### Branch Labels

ZAP uses various label prefixes for different branch types:

```zap
?CND6:          ; Condition label
?ELS8:          ; Else label
?PRG11:         ; Program/loop label
?CCL3:          ; Code clause label
?THN32:         ; Then label
/FALSE          ; Branch to false
\TRUE           ; Branch to true (negated)
```

### Local Labels

Local labels are automatically generated with prefixes:

```zap
?TMP1           ; Temporary variable
?ELS5           ; Else clause
?CND10          ; Condition check
?PRG1           ; Program loop
```

## Data Structures

### Object Definitions

Objects are defined with property tables:

```zap
; Object property structure (conceptual representation)
OBJECT-NAME:
    .WORD   PARENT          ; Parent object
    .WORD   SIBLING         ; Next sibling
    .WORD   CHILD           ; First child
    .WORD   PROPERTIES      ; Property table address
    .WORD   FLAGS           ; Object flags
```

### Property Tables

Properties store object attributes:

```zap
; Property table format
PROPERTY-TABLE:
    .BYTE   TEXT-LENGTH     ; Short name length
    .TEXT   "object name"   ; Object short name
    .BYTE   PROP-ID, SIZE   ; Property ID and size
    .WORD   PROP-DATA       ; Property data
    ; More properties...
    .BYTE   0               ; End marker
```

### String Tables

Strings are stored in compressed format:

```zap
STRBEG::
    .GSTR STR?1,"First string"
    .GSTR STR?2,"Second string"
    ; String reference
    P-SOMETHING=STR?11
```

### Dictionary Structure

The dictionary stores recognized words:

```zap
WORDS::
    .BYTE   SEPARATOR-CHARS    ; Word separators
    .BYTE   ENTRY-LENGTH       ; Bytes per entry
    .WORD   NUM-ENTRIES        ; Number of words
    ; Dictionary entries follow
```

## Advanced Features

### Conditional Assembly

ZAP supports conditional compilation through symbol testing:

```zap
ASSIGNED? 'SYMBOL /?DEFINED
; Code if symbol not defined
JUMP ?ENDIF
?DEFINED:
; Code if symbol defined
?ENDIF:
```

### Memory Segments

Different memory areas serve different purposes:

```zap
.SEGMENT "0"        ; Dynamic memory (read/write)
.SEGMENT "1"        ; Static memory (read-only)
.SEGMENT "2"        ; High memory (code only)
```

### Macro-like Constructs

Some instructions provide macro-like functionality:

```zap
CALL1   ROUTINE             ; Call with 1 argument
CALL2   ROUTINE,ARG         ; Call with 2 arguments
XCALL   ROUTINE,ARG1,ARG2   ; Extended call
```

## Error Handling and Flow Control

### Error Conditions

```zap
ZERO?   RESULT \ERROR-HANDLER     ; Check for errors
EQUAL?  STATUS,FATAL-VALUE /FATAL ; Fatal error check
```

### Stack Management

```zap
PUSH    CURRENT-STATE            ; Save state
; Risky operation
POP     >RESTORED-STATE          ; Restore if needed
```

## Optimization Patterns

### Common Code Patterns

#### Object Property Access
```zap
GETP    OBJECT,P?PROPERTY >VALUE     ; Get property
ZERO?   VALUE /USE-DEFAULT           ; Check if exists
```

#### Loop Constructs
```zap
?LOOP:
    ; Loop body
    SET     COUNTER,<SUB COUNTER,1>
    ZERO?   COUNTER \?LOOP
```

#### Function Epilogue
```zap
    ; Function body
    RSTACK              ; Return (automatic for .FUNCT)
```

### Memory Efficiency

ZAP optimizes for the Z-Machine's limited memory:
- Uses packed addresses for code and strings
- Employs bit flags for boolean properties
- Compresses text with custom encoding
- Shares common code through function calls

## Integration with Z-Machine

### Memory Layout

ZAP generates code for specific Z-Machine memory regions:

- **Dynamic Memory**: Variables, objects, stack
- **Static Memory**: Unchanging data, tables
- **High Memory**: Code, compressed strings

### Instruction Encoding

ZAP instructions map to Z-Machine opcode formats:
- **Short form**: 0-1 operands
- **Long form**: 2 operands
- **Variable form**: 0-4 operands
- **Extended form**: VAR opcodes with 5-8 operands

### Version Compatibility

ZAP adapts to different Z-Machine versions:
- **Version 3**: Standard Zork games
- **Version 4**: Enhanced features
- **Version 5**: Extended memory model
- **Version 6**: Graphics and sound
- **Version 8**: Unicode support

## Development Workflow

### Compilation Process

1. **ZIL Compilation**: ZIL source → ZAP assembly
2. **Assembly**: ZAP assembly → Z-Machine bytecode
3. **Linking**: Combine segments into story file
4. **Optimization**: Compress and optimize final output

### Debugging Support

ZAP maintains symbolic information for debugging:
- Function names and entry points
- Variable names and scopes
- Source line correlations
- Object and property mappings

### Cross-References

The assembler tracks symbol usage:
- Forward references resolved in second pass
- Undefined symbol detection
- Duplicate definition warnings
- Dead code elimination

This comprehensive reference covers the essential aspects of ZAP for implementing an assembler and virtual machine. The language provides direct access to Z-Machine capabilities while maintaining the abstraction needed for efficient interactive fiction development.