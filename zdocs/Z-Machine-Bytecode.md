# Z-Machine Bytecode Format - Comprehensive Reference

## Overview

The Z-Machine bytecode format is the binary representation of compiled interactive fiction games. Z-Machine story files contain both code and data organized into a specific memory layout designed for the Z-Machine virtual machine. This format provides platform independence while maintaining compact file sizes.

## File Structure

### File Header (64 bytes)

The Z-Machine story file begins with a 64-byte header containing metadata and memory layout information:

```
Offset  Size  Description
------  ----  -----------
0x00    1     Version number (1-8)
0x01    1     Flags 1 (interpreter capabilities)
0x02    2     Release number
0x04    2     High memory base address
0x06    2     Initial program counter (start routine)
0x08    2     Dictionary address
0x0A    2     Object table address
0x0C    2     Global variables address
0x0E    2     Static memory base address
0x10    2     Flags 2 (story file requirements)
0x12    6     Serial number (YYMMDD format)
0x18    2     Abbreviations table address
0x1A    2     File length (divided by 2 for V1-3, by 4 for V4-5, by 8 for V6+)
0x1C    2     File checksum
0x1E    2     Interpreter number
0x20    2     Interpreter version
0x22    1     Screen height (lines)
0x23    1     Screen width (characters)
0x24    2     Screen width (units) - V4+
0x26    2     Screen height (units) - V4+
0x28    1     Font height (units) - V5+/Font width - V6
0x29    1     Font width (units) - V5+/Font height - V6
0x2A    2     Routines offset (divided by 8) - V6+
0x2C    2     Strings offset (divided by 8) - V6+
0x2E    1     Default background color - V5+
0x2F    1     Default foreground color - V5+
0x30    2     Terminating characters table address - V5+
0x32    2     Total width of pixels streamed to output 3 - V6
0x34    2     Standard revision number - V1.0 is 0x0102
0x36    1     Alphabet table address (high byte) - V5+
0x37    1     Alphabet table address (low byte) - V5+
0x38-3F 8     Reserved (must be zero)
```

### Example Header Analysis

From zork1.z3:
```
00: 03        Version 3
01: 00        Flags 1 (no special capabilities required)
02: 00 77    Release 119
04: 4b 54    High memory at 0x4B54
06: 50 d5    Start routine at 0x50D5
08: 38 99    Dictionary at 0x3899
0A: 03 e6    Object table at 0x03E6
0C: 02 b0    Global variables at 0x02B0
0E: 2c 12    Static memory at 0x2C12
10: 00 40    Flags 2 (status line is location/score format)
12: 38 38 30 34 32 39   Serial "880429" (April 29, 1988)
```

## Memory Layout

### Memory Regions

Z-Machine memory is divided into three regions:

#### Dynamic Memory (0x0000 to Static Base)
- **Read/Write**: Can be modified during execution
- **Contains**: Header, object table, global variables
- **Saved**: Included in save games

#### Static Memory (Static Base to High Memory Base)
- **Read-Only**: Cannot be modified during execution
- **Contains**: Dictionary, static strings, tables
- **Not Saved**: Restored from original story file

#### High Memory (High Memory Base to End)
- **Execute-Only**: Contains packed routines and strings
- **Cannot**: Be directly read or written
- **Access**: Through CALL and string printing instructions

## Instruction Encoding

### Instruction Forms

Z-Machine instructions use four different encoding forms:

#### Short Form (1 byte opcode + operands)
```
Bit:  7 6 5 4 3 2 1 0
      1 0 t t o o o o

tt = operand type: 00=large constant, 01=small constant, 10=variable, 11=omitted
oooo = opcode (0-15)
```

#### Long Form (1 byte opcode + operands)
```
Bit:  7 6 5 4 3 2 1 0
      0 a b o o o o o

a = first operand type (0=small constant, 1=variable)
b = second operand type (0=small constant, 1=variable)
oooooo = opcode (0-31)
```

#### Variable Form (1-2 byte opcode + operands)
```
Bit:  7 6 5 4 3 2 1 0
      1 1 t o o o o o

t = 0 for 2OP VAR, 1 for VAR
ooooo = opcode (0-31)

Followed by operand type byte:
Bit:  7 6 5 4 3 2 1 0
      a a b b c c d d

aa,bb,cc,dd = operand types: 00=large constant, 01=small constant, 10=variable, 11=omitted
```

#### Extended Form (Version 5+)
```
0xBE followed by opcode byte, then operand type byte and operands
```

### Operand Types

#### Constants
- **Small constant (0-255)**: 1 byte value
- **Large constant (0-65535)**: 2 byte value (big-endian)

#### Variables
- **0x00**: Top of stack
- **0x01-0x0F**: Local variables 1-15
- **0x10-0xFF**: Global variables 0x10-0xFF

### Branch Format

Many instructions can branch based on their result:

```
Branch byte 1: ?bbb bbbb
Branch byte 2: bbbb bbbb (if bit 6 of byte 1 is 0)

? = branch polarity (1=branch on true, 0=branch on false)
b = branch offset (6 or 14 bits)

Special offsets:
0 = return false (rfalse)
1 = return true (rtrue)
```

### Store Format

Instructions that produce results store them in a variable:

```
Store byte: vvvv vvvv
vvvvvvvv = variable number (same encoding as operands)
```

## Data Structures

### Object Table

Located at address specified in header offset 0x0A:

#### Object Tree Entry (Version 1-3: 9 bytes, Version 4+: 14 bytes)
```
V1-3:
Offset  Size  Description
0       1     Attributes 0-7
1       1     Attributes 8-15
2       1     Attributes 16-23
3       1     Attributes 24-31
4       1     Parent object number
5       1     Sibling object number
6       1     Child object number
7       2     Property table address

V4+:
Offset  Size  Description
0       2     Attributes 0-15
2       2     Attributes 16-31
4       2     Attributes 32-47
6       2     Parent object number
8       2     Sibling object number
10      2     Child object number
12      2     Property table address
```

#### Property Table Format
```
Offset  Description
0       Text length (number of 2-byte words)
1-N     Object short name (ZSCII text)
N+1     Property entries

Property Entry:
Byte 1: LLLL LLLL (V1-3) or 1LLL LLLL (V4+) - Length and property number
        If V4+ and bit 7=1: LLLL LLLL in next byte
Bytes:  Property data
```

### Dictionary

Located at address specified in header offset 0x08:

```
Offset  Size  Description
0       1     Number of input separator characters
1-N     N     Input separator characters
N+1     1     Entry length in bytes
N+2     2     Number of entries (signed)
N+4     ?     Dictionary entries (sorted)

Dictionary Entry:
6 bytes: Encoded word (4 or 6 Z-characters)
Remaining: Word type and other flags
```

### Global Variables

Located at address specified in header offset 0x0C:
- 240 global variables (16-bit words)
- Variables 0x10-0xFF accessible as operands
- Variables 0x00-0x0F reserved for system use

### String Encoding

#### Z-Characters (ZSCII Compression)

Text is encoded using 5-bit Z-characters packed 3 per 16-bit word:

```
Bit: 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
     -- -- -- -- -- a  a  a  a  a b  b  b  b  b c  c
     ^              ^              ^              ^
     |              +-- 1st char   +-- 2nd char  +-- 3rd char
     +-- End bit (1 = last word of string)
```

#### Alphabet Tables

Z-characters 6-31 map to characters through alphabet tables:
- **A0** (chars 6-31): abcdefghijklmnopqrstuvwxyz
- **A1** (chars 6-31): ABCDEFGHIJKLMNOPQRSTUVWXYZ
- **A2** (chars 7-31): ^0123456789.,!?_#'"/\<-:()

Special Z-characters:
- **0**: Space character
- **1-3**: Abbreviations (V2+)
- **4**: Shift to A1 for next character
- **5**: Shift to A2 for next character
- **6** (in A2): Escape sequence for literal ZSCII

### Abbreviation Table (Version 2+)

Located at address specified in header offset 0x18:
- 96 entries (32 for each abbreviation type 1-3)
- Each entry is word address of abbreviated string
- Referenced by Z-characters 1-3 followed by abbreviation number

## Routine Format

### Routine Header
```
Byte 0: Number of local variables (0-15)
Bytes 1-N: Default values for locals (V1-4: 2 bytes each, V5+: absent)
```

### Packed Addresses

Routines and strings use packed addresses to extend addressing range:

- **Version 1-3**: Packed address × 2 = byte address
- **Version 4-5**: Packed address × 4 = byte address
- **Version 6-7**: Packed address × 4 = byte address + routine/string offset
- **Version 8**: Packed address × 8 = byte address

## Instruction Set Summary

### Categories

#### Arithmetic
- **ADD**: Addition
- **SUB**: Subtraction
- **MUL**: Multiplication
- **DIV**: Division
- **MOD**: Modulo
- **RANDOM**: Random number generation

#### Logic and Comparison
- **EQUAL?**: Equality test
- **LESS?**: Less than comparison
- **GRTR?**: Greater than comparison
- **ZERO?**: Zero test
- **AND**: Bitwise AND
- **OR**: Bitwise OR
- **NOT**: Bitwise complement

#### Memory Access
- **LOAD**: Load variable
- **STORE**: Store variable
- **LOADW**: Load word from array
- **STOREW**: Store word to array
- **LOADB**: Load byte from array
- **STOREB**: Store byte to array

#### Object Manipulation
- **GET_PROP**: Get object property
- **PUT_PROP**: Set object property
- **GET_PROP_ADDR**: Get property address
- **GET_NEXT_PROP**: Get next property number
- **GET_SIBLING**: Get sibling object
- **GET_CHILD**: Get child object
- **GET_PARENT**: Get parent object
- **REMOVE_OBJ**: Remove object from tree
- **INSERT_OBJ**: Insert object in tree
- **TEST_ATTR**: Test object attribute
- **SET_ATTR**: Set object attribute
- **CLEAR_ATTR**: Clear object attribute

#### Control Flow
- **JUMP**: Unconditional jump
- **JZ**: Jump if zero
- **JE**: Jump if equal
- **JL**: Jump if less than
- **JG**: Jump if greater than
- **CALL**: Call routine
- **RET**: Return value
- **RTRUE**: Return true
- **RFALSE**: Return false
- **QUIT**: End program

#### Input/Output
- **READ**: Read player input
- **PRINT**: Print string
- **PRINT_RET**: Print string and return
- **PRINT_CHAR**: Print character
- **PRINT_NUM**: Print number
- **NEW_LINE**: Print newline
- **SPLIT_WINDOW**: Split screen (V3+)
- **SET_WINDOW**: Select window (V3+)

#### Stack Operations
- **PUSH**: Push value onto stack
- **PULL**: Pull value from stack (V6+)
- **CATCH**: Mark stack position (V5+)
- **THROW**: Unwind to marked position (V5+)

## Save Game Format

Save games preserve the dynamic memory region and execution state:

### Quetzal Format (Standard)
Based on IFF (Interchange File Format):

#### IFhd Chunk (Header Information)
```
Offset  Size  Description
0       2     Release number
2       6     Serial number
4       2     Checksum
6       1     Initial PC (high byte)
7       1     Initial PC (middle byte)
8       1     Initial PC (low byte)
```

#### CMem Chunk (Compressed Memory)
Dynamic memory compressed using run-length encoding of XOR differences from original story file.

#### Stks Chunk (Stack State)
Complete call stack and evaluation stack state for exact restoration.

## Version Differences

### Version 3 (Standard Zork Format)
- 128KB maximum story file size
- 255 objects maximum
- Basic screen model with status line
- Dictionary entries are 4 Z-characters

### Version 4 (Enhanced Features)
- Supports sound effects
- Extended object limit (65535 objects)
- Timed input capabilities
- Dictionary entries are 6 Z-characters

### Version 5 (Extended Memory)
- 256KB maximum story file size
- Color support
- Mouse input
- More screen control

### Version 6 (Graphical)
- Graphics and pictures
- Multiple windows (up to 8)
- More sophisticated screen layout
- Sound effects with volume control

### Version 7-8 (Modern Extensions)
- Unicode support (V8)
- Larger memory models
- Additional opcodes

## Implementation Notes

### Endianness
All multi-byte values are stored in big-endian format (most significant byte first).

### Text Compression
The ZSCII compression scheme typically achieves 50-60% compression ratio for English text.

### Memory Protection
The Z-Machine enforces strict memory region access:
- Dynamic memory: Read/write allowed
- Static memory: Read-only access
- High memory: Execute-only access

### Error Handling
Implementations should handle:
- Invalid instruction opcodes
- Out-of-bounds memory access
- Stack underflow/overflow
- Invalid object references
- Malformed save files

This bytecode format provides a complete virtual machine environment specifically optimized for interactive fiction, balancing compact representation with execution efficiency.