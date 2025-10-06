# Z-Machine Debugger

Interactive debugger for inspecting and modifying Z-Machine game state during execution.

## Activation

Enable debug mode when running a story file:

```bash
zil run --debug story.z3
```

All debug commands use the `@` prefix to distinguish them from game input.

## Command Reference

### Variable Inspection

**Global Variables**
- `@global [index]` - Display global variable (or all non-zero if no index)
- `@globals` - List all 240 global variables in 8-column format
- `@setglobal <index> <value>` - Set global variable value

**Local Variables**
- `@local <index>` - Display local variable value
- `@setlocal <index> <value>` - Set local variable value

**Stack**
- `@stack` - Display evaluation stack (top to bottom)

**Value Formats:**
- Decimal: `42`
- Hexadecimal: `0x2A`
- Signed: `-10` (converted to unsigned internally)

### Memory Inspection

- `@peek <address>` - Read byte at memory address
- `@peekw <address>` - Read word at memory address
- `@dump <address> <length>` - Hex dump with ASCII display

Addresses accept hex (`0x1234`) or decimal format.

### Object System

**Object Inspection**
- `@object <number>` - Display object details (parent, sibling, child, attributes, properties)
- `@objects` - List all objects with their locations
- `@tree <object>` - Display object tree hierarchy
- `@find <text>` - Search for objects by name (case-insensitive substring)
- `@where <object>` - Show object's location chain

**Object Manipulation**
- `@move <object> <parent>` - Move object to new parent
- `@attr <object> [attribute]` - Display all attributes or toggle specific attribute
- `@prop <object> <property> [value]` - Display or set property value

### Execution Control

- `@break [address]` - Set/remove/list breakpoints at PC address
- `@step` - Execute single instruction (command only, not integrated)
- `@continue` - Resume execution (command only, not integrated)
- `@pc` - Show current program counter
- `@backtrace` - Display call stack with frame details

**Aliases:** `@b` (break), `@s` (step), `@c` (continue), `@bt` (backtrace)

### Game State Inspection

- `@dictionary [word]` - Show dictionary info or look up specific word
- `@version` - Display Z-Machine version and story file information
- `@itable <address> [count]` - Display ITABLE contents

**Aliases:** `@dict` (dictionary), `@ver` (version), `@table` (itable), `@obj` (object)

### Help

- `@help` - Show complete command reference

## Common Workflows

### Teleportation

Objects and room location must be synchronized manually:

```
1. @find adventurer      # Find player object number (varies by game)
2. @move <player> <room> # Move player to destination
3. @setglobal 0 <room>   # Update HERE global (typically at index 0)
```

**Note:** Global 0 is usually HERE because globals are sorted alphabetically during compilation.

### Timer/Interrupt Inspection

The timer system is implemented in game code (not VM):

```
1. @globals              # Find C-TABLE global (alphabetically sorted near 'C')
2. @global <index>       # Get C-TABLE address
3. @itable <address>     # Display interrupt table
```

**C-TABLE Structure:**
- Each entry is a vector with:
  - Offset 0: `C-ENABLED?` (0 = disabled, non-zero = enabled)
  - Offset 1: `C-TICK` (countdown until firing)
  - Additional routine/data varies by interrupt type

### Object Debugging

```
@find lamp              # Search for object by name
@object 59              # Inspect object details
@attr 59                # Show all attributes
@attr 59 5              # Toggle attribute 5
@prop 59 15             # Show property 15
@prop 59 15 100         # Set property 15 to 100
@where 59               # Show location chain
@tree 137               # Show tree for room 137
```

## Technical Details

### Object Tree Debug Mode

- Debug mode builds a name lookup table for fast object searching
- Enabled automatically when debugger is activated
- `searchObjects()` provides case-insensitive substring matching
- Lookup table maps lowercase names to object numbers

### Timer/Interrupt System

**Discovery:** Timers are implemented as ZIL library routines, not Z-Machine instructions.

**Key Components:**
- `C-TABLE` - Global variable containing interrupt entries (ITABLE)
- `QUEUE(routine, tick)` - Create interrupt entry
- `ENABLE(interrupt)` - Activate interrupt
- `DISABLE(interrupt)` - Deactivate interrupt

**Implementation:**
- Library routines in `gclock.zil` manipulate C-TABLE structure
- Game checks and fires interrupts each turn
- No VM-level support needed

### Global Variable Ordering

Global variables are sorted **alphabetically** by the ZIL compiler before compilation.

**Example (Zork I/II/III):**
- Global 0: `HERE` (current room) - 'H' comes first alphabetically
- Other indices vary by game

Use `@globals` to inspect all globals and identify specific variables.

### Memory Regions

- **Dynamic Memory** (0 to Static Base): Read/write, contains globals and object changes
- **Static Memory** (Static Base to High Base): Read-only, contains dictionary and tables
- **High Memory** (High Base to end): Execute-only, contains code and strings

## Limitations

### Execution Control

- **Step/Continue not integrated:** Commands exist but don't pause execution
- **Breakpoints not enforced:** Can be set/listed but execution doesn't stop
- **Requires async architecture:** Terminal is synchronous, making interactive stepping challenging

### Parser State

- **Parser buffers not accessible:** Would need to locate game-specific globals
- **No @parse command:** P-LEXV, P-ITBL inspection not implemented
- **No @verbs command:** Current verb/object state not available

### Frame Navigation

- `@frame <n>` - Switch to specific call stack frame (not implemented)
- `@routine` - Display current routine info (not implemented)

### Watchpoints

- `@watch <address>` - Memory watchpoints (not implemented)
- `@memwatch <address>` - Track memory changes (not implemented)

## Examples

### Debugging the Zork II Princess Timer

```bash
# Find the princess object
@find princess
# Output: Objects matching 'princess':
#   [38] beautiful princess (in Royal Chamber)

# Find C-TABLE global (look for globals near 'C')
@globals
# Identify C-TABLE index from output

# Get C-TABLE address
@global 5  # Example: assuming C-TABLE is at index 5
# Output: Global[5] = 1234 (0x4D2)

# Inspect interrupt table
@itable 0x4D2
# Shows all interrupt entries with ENABLED? and TICK values
```

### Examining Object Relationships

```bash
# Find all lamps
@find lamp

# Inspect brass lantern
@object 56
# Shows parent, sibling, child, attributes, properties

# Check if lantern is lit (attribute check)
@attr 56

# Light the lantern (toggle ONBIT attribute)
@attr 56 15  # Assuming 15 is ONBIT

# Move lantern to player
@move 56 40  # Assuming player is object 40
```

### Memory Investigation

```bash
# Show program counter
@pc

# Dump memory at PC
@dump 0x5432 64

# Read word at address
@peekw 0x1000

# Check dictionary for word
@dictionary take
```

## Best Practices

1. **Use @find before @move** - Verify object numbers are correct
2. **Always sync HERE** - After moving player, update HERE global
3. **Check @globals first** - Identify variable indices before modification
4. **Use @tree for context** - Understand object relationships before manipulation
5. **Start with @help** - Reference available commands and syntax
