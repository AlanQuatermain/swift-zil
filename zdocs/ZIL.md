# ZIL (Zork Implementation Language) - Comprehensive Language Reference

## Overview

ZIL (Zork Implementation Language) is a domain-specific programming language created by Infocom for developing interactive fiction games. It compiles to Z-Machine bytecode, which provides platform independence for text-based adventure games. ZIL is a Lisp-like language with specialized constructs for interactive fiction development.

## Language Fundamentals

### Syntax Structure

ZIL uses S-expression syntax similar to Lisp, with extensive use of angle brackets `< >` for function calls and parentheses for lists and property definitions:

```zil
<ROUTINE EXAMPLE-ROUTINE (ARG1 "AUX" LOCAL-VAR)
    <TELL "Hello, world!" CR>
    <RETURN T>>

<OBJECT EXAMPLE-OBJECT
    (IN ROOM1)
    (SYNONYM ITEM THING)
    (DESC "example object")
    (FLAGS TAKEBIT)>
```

### Comments

Comments are prefixed with semicolons or quotes:

```zil
; This is a line comment
"This is also a comment"
```

### Data Types

#### Primitive Types
- **Integers**: 16-bit signed integers (-32768 to 32767)
- **Strings**: Text literals enclosed in quotes
- **Atoms**: Symbolic names/identifiers
- **Boolean**: `T` (true) and `<>` (false)

#### Complex Types
- **Objects**: Game entities (rooms, items, characters)
- **Routines**: Functions/procedures
- **Tables**: Arrays of data
- **Properties**: Key-value pairs associated with objects

### Variables

#### Global Variables
Defined with `<GLOBAL>` and referenced with commas:

```zil
<GLOBAL SCORE 0>
<GLOBAL PLAYER-NAME "Adventurer">
<SETG SCORE <+ ,SCORE 10>>  ; Increment score
```

#### Local Variables
Defined in routine parameter lists:

```zil
<ROUTINE EXAMPLE (PARAM1 "OPT" PARAM2 "AUX" LOCAL1 LOCAL2)
    <SET LOCAL1 .PARAM1>     ; Access with periods
    <TELL .LOCAL1 CR>>
```

Parameter types:
- **Required parameters**: Listed first
- **"OPT"**: Optional parameters
- **"AUX"**: Local auxiliary variables

### Constants

Defined with `<CONSTANT>`:

```zil
<CONSTANT MAX-INVENTORY 10>
<CONSTANT GAME-VERSION 1>
```

## Core Language Constructs

### Routines (Functions)

Routines are the primary code organization unit:

```zil
<ROUTINE ROUTINE-NAME (parameters)
    ; Body of routine
    <RETURN value>>
```

#### Calling Routines
```zil
<ROUTINE-NAME arg1 arg2>           ; Call with arguments
<SET RESULT <ROUTINE-NAME .VAR>>   ; Store return value
```

### Conditionals

#### COND (Primary Conditional)
```zil
<COND (<predicate1>
       <action1>
       <action2>)
      (<predicate2>
       <action3>)
      (T  ; else clause
       <default-action>)>
```

#### Common Predicates
```zil
<EQUAL? .VAR1 .VAR2 .VAR3>     ; Equality (multiple args)
<G? .A .B>                     ; Greater than
<L? .A .B>                     ; Less than
<FSET? ,OBJECT ,FLAG>          ; Test object flag
<IN? ,OBJECT1 ,OBJECT2>        ; Location test
<VERB? TAKE PICK-UP GET>       ; Multiple verb test
```

### Loops

#### REPEAT (Primary Loop Construct)
```zil
<REPEAT ((VAR INITIAL-VALUE))
    <COND (<condition>
           <RETURN>)>        ; Exit loop
    <statements>>
```

### Arithmetic and Logic

#### Arithmetic Operations
```zil
<+ .A .B>                      ; Addition
<- .A .B>                      ; Subtraction
<* .A .B>                      ; Multiplication
</ .A .B>                      ; Division
<MOD .A .B>                    ; Modulo
```

#### Logical Operations
```zil
<AND <predicate1> <predicate2>>
<OR <predicate1> <predicate2>>
<NOT <predicate>>
```

### Memory and Data Manipulation

#### SET and SETG
```zil
<SET LOCAL-VAR .VALUE>         ; Set local variable
<SETG GLOBAL-VAR .VALUE>       ; Set global variable
```

#### Table Operations
```zil
<CONSTANT MY-TABLE <TABLE 1 2 3 4 5>>
<GET ,MY-TABLE 0>              ; Get element 0
<PUT ,MY-TABLE 2 .NEW-VALUE>   ; Set element 2
```

## Interactive Fiction Specific Constructs

### Objects

Objects represent all game entities - rooms, items, characters:

```zil
<OBJECT OBJECT-NAME
    (IN CONTAINER)             ; Location
    (SYNONYM WORD1 WORD2)      ; Parser recognition words
    (ADJECTIVE ADJ1 ADJ2)      ; Descriptive adjectives
    (DESC "description")       ; Default description
    (LDESC "long description") ; Room/detailed description
    (FDESC "first description") ; First-time description
    (FLAGS FLAG1 FLAG2)        ; Object attributes
    (SIZE 10)                  ; Size/weight value
    (CAPACITY 20)              ; Container capacity
    (VALUE 5)                  ; Point value
    (ACTION ROUTINE-NAME)      ; Action handler routine
    (PROPERTIES...)>           ; Additional properties
```

### Rooms

Rooms are special objects representing locations:

```zil
<ROOM LIVING-ROOM
    (IN ROOMS)                 ; All rooms go in ROOMS container
    (DESC "Living Room")
    (LDESC "A cozy living room with a fireplace.")
    (NORTH TO KITCHEN)         ; Simple exit
    (SOUTH PER EXIT-ROUTINE)   ; Conditional exit via routine
    (EAST TO HALL IF DOOR-OPEN ; Conditional exit
          ELSE "The door is locked.")
    (FLAGS RLANDBIT ONBIT)     ; Room is on land and lit
    (ACTION LIVING-ROOM-F)>
```

### Object Flags

Common object flags:

```zil
TAKEBIT      ; Object can be picked up
OPENBIT      ; Object is open (containers/doors)
CONTBIT      ; Object is a container
DOORBIT      ; Object is a door
LIGHTBIT     ; Object can provide light
ONBIT        ; Object is currently on/lit
WEARBIT      ; Object can be worn
READBIT      ; Object can be read
NDESCBIT     ; Don't describe in room descriptions
INVISIBLE    ; Object is not visible to parser
TOUCHBIT     ; Object has been disturbed
PERSONBIT    ; Object is a character/NPC
```

### Action Routines

Handle player interactions with objects:

```zil
<ROUTINE OBJECT-NAME-F ()
    <COND (<VERB? TAKE>
           <TELL "You take the object." CR>
           <MOVE ,OBJECT-NAME ,PLAYER>)
          (<VERB? EXAMINE>
           <TELL "It looks ordinary." CR>)
          (T  ; Default case
           <RFALSE>)>>          ; Let other handlers try
```

### Room Action Routines

Handle room-specific events:

```zil
<ROUTINE ROOM-NAME-F (RARG)
    <COND (<EQUAL? .RARG ,M-LOOK>
           <TELL "Room description goes here." CR>)
          (<EQUAL? .RARG ,M-ENTER>
           <TELL "You enter the room." CR>)
          (<EQUAL? .RARG ,M-END>
           ; End-of-turn processing
           )>>
```

### Parser Integration

#### Syntax Definitions
```zil
<SYNTAX VERB OBJECT = V-VERB>          ; Simple verb-object
<SYNTAX VERB OBJECT TO OBJECT = V-VERB> ; Verb with direct/indirect objects
<SYNTAX VERB = V-VERB>                  ; Verb only
<SYNTAX VERB OBJECT WITH OBJECT = V-VERB> ; Verb with preposition
```

#### Parser Variables
- `PRSA`: Current action (verb)
- `PRSO`: Direct object
- `PRSI`: Indirect object
- `WINNER`: Current command recipient (usually PLAYER)
- `HERE`: Current room

#### Verb Defaults
```zil
<ROUTINE V-TAKE ()
    <COND (<FSET? ,PRSO ,TAKEBIT>
           <MOVE ,PRSO ,PLAYER>
           <TELL "Taken." CR>)
          (T
           <TELL "You can't take that." CR>)>>
```

### Text Output

#### TELL Macro (Primary Output)
```zil
<TELL "Simple text" CR>                    ; Basic text + newline
<TELL "The " D ,OBJECT " is here." CR>     ; Object description
<TELL "Score: " N ,SCORE CR>               ; Numeric value
<TELL A ,OBJECT " falls." CR>              ; Indefinite article
<TELL T ,OBJECT " glows." CR>              ; Definite article ("the")
```

TELL Tokens:
- `CR` or `CRLF`: Newline
- `D object`: Object's DESC property
- `A object`: "a/an object"
- `T object`: "the object"
- `N value`: Numeric value

### Movement and Location

#### Object Movement
```zil
<MOVE ,OBJECT ,NEW-LOCATION>      ; Move object to location
<REMOVE ,OBJECT>                  ; Remove from game (LOC = false)
<LOC ,OBJECT>                     ; Get object's location
```

#### Location Tests
```zil
<IN? ,OBJECT ,CONTAINER>          ; Is object in container?
<EQUAL? <LOC ,OBJECT> ,ROOM>      ; Location equality
```

#### Player Movement
```zil
<GOTO ,NEW-ROOM>                  ; Move player to room
<DO-WALK ,DIRECTION>              ; Attempt movement in direction
```

### Property Manipulation

```zil
<GETP ,OBJECT ,P?PROPERTY>        ; Get property value
<PUTP ,OBJECT ,P?PROPERTY .VALUE> ; Set property value
```

### Event System

#### Interrupt Routines (Timed Events)
```zil
<QUEUE I-EVENT-NAME 5>            ; Queue event for 5 turns
<QUEUE I-EVENT-NAME -1>           ; Queue recurring event
<DEQUEUE I-EVENT-NAME>            ; Cancel queued event

<ROUTINE I-EVENT-NAME ()
    <TELL "Something happens!" CR>
    <RTRUE>>                      ; Return true if output produced
```

#### Room Events
```zil
<ROUTINE ROOM-F (RARG)
    <COND (<EQUAL? .RARG ,M-END>
           ; Called every turn at room end
           <COND (<condition>
                  <TELL "End-of-turn event" CR>)>)>>
```

## Standard Library Functions

### Utility Routines

```zil
<JIGS-UP "death message">         ; Kill player
<GOTO ,ROOM>                      ; Move player to room
<PICK-ONE ,TABLE>                 ; Random table element
<WEIGHT ,CONTAINER>               ; Total weight of container contents
<HELD? ,OBJECT ,CONTAINER>        ; Is object ultimately in container?
<VISIBLE? ,OBJECT>                ; Is object visible to player?
<ACCESSIBLE? ,OBJECT>             ; Can object be reached?
<ROB ,CONTAINER ,DESTINATION>     ; Empty container to destination
```

### Flag Operations

```zil
<FSET ,OBJECT ,FLAG>              ; Set flag
<FCLEAR ,OBJECT ,FLAG>            ; Clear flag
<FSET? ,OBJECT ,FLAG>             ; Test flag (predicate)
```

### Game Control

```zil
<SAVE>                            ; Save game
<RESTORE>                         ; Restore game
<RESTART>                         ; Restart game
<QUIT>                            ; End game
<VERIFY>                          ; Verify game file integrity
```

## File Organization and Modularization

### File Inclusion
```zil
<INSERT-FILE "FILENAME" T>        ; Include file
```

### Common File Types
- **Main game file**: Entry point, includes other files
- **GLOBALS**: Global variables and universal objects
- **SYNTAX**: Parser syntax definitions
- **VERBS**: Verb default routines
- **PARSER**: Parser implementation
- **MACROS**: Macro definitions
- **Game-specific files**: Rooms, objects, puzzles

### Typical File Structure
```zil
; Main game file
<INSERT-FILE "SYNTAX" T>
<INSERT-FILE "MACROS" T>
<INSERT-FILE "GLOBALS" T>
<INSERT-FILE "PARSER" T>
<INSERT-FILE "VERBS" T>
<INSERT-FILE "ROOMS" T>
<INSERT-FILE "OBJECTS" T>
```

## Macros and Advanced Features

### Macro Definition
```zil
<DEFMAC MACRO-NAME ("ARGS" PARAMS)
    ; Macro expansion code
    >
```

### Property Definition
```zil
<PROPDEF PROPERTY-NAME DEFAULT-VALUE>
```

### Special Variables and Constants

#### Parser Constants
```zil
M-LOOK       ; Room description context
M-ENTER      ; Room entry context
M-END        ; End-of-turn context
M-BEG        ; Beginning-of-turn context
```

#### Special Objects
```zil
GLOBAL-OBJECTS    ; Container for global objects
LOCAL-GLOBALS     ; Container for local-global objects
ROOMS            ; Container for all rooms
PLAYER           ; The player character object
```

## Z-Machine Integration

### Z-Machine Instructions
ZIL compiles to Z-Machine opcodes. Common patterns:

```zil
; These ZIL constructs become Z-Machine opcodes:
<RANDOM 6>                        ; RANDOM opcode
<PRINTI "text">                   ; PRINTI opcode
<PRINTD ,OBJECT>                  ; PRINTD opcode
<PRINTN .NUMBER>                  ; PRINTN opcode
<CRLF>                           ; NEW_LINE opcode
```

### Memory Management
- **Dynamic Memory**: Variables, objects, global state
- **Static Memory**: Read-only data, strings
- **High Memory**: Code (routines)

### Header Information
```zil
<SNAME "GAME-NAME">              ; Story file name
<CONSTANT SERIAL 123456>         ; Serial number
```

## Best Practices and Conventions

### Naming Conventions
- **Constants**: ALL-CAPS with hyphens
- **Globals**: ALL-CAPS with hyphens
- **Routines**: KEBAB-CASE ending in -F for action routines
- **Objects**: KEBAB-CASE descriptive names
- **Local variables**: lowercase or mixed case

### Code Organization
- Keep action routines focused and specific
- Use consistent indentation (typically 2 or 4 spaces)
- Group related functionality in separate files
- Document complex logic with comments

### Interactive Fiction Patterns
- Always handle the most specific cases first in COND statements
- Provide appropriate default responses for unhandled verbs
- Use RTRUE/RFALSE appropriately to control parser flow
- Test object properties and flags before taking actions
- Provide meaningful feedback for all player actions

### Error Handling
```zil
<COND (<NOT <FSET? ,PRSO ,TAKEBIT>>
       <TELL "You can't take that." CR>
       <RTRUE>)>    ; Handled, don't try other handlers
```

## Compilation and Development

### Compiler Directives
```zil
<SETG REDEFINE T>                ; Allow redefinition
<PRINC "Compile-time message">    ; Print during compilation
<OR <condition> <action>>         ; Conditional compilation
```

### Version Control
```zil
<COND (<==? ,ZORK-NUMBER 1>      ; Version-specific code
       <code-for-zork1>)
      (<==? ,ZORK-NUMBER 2>
       <code-for-zork2>)>
```

This comprehensive reference covers the essential aspects of ZIL for implementing a compiler/interpreter and virtual machine. The language is specifically designed for interactive fiction development, with specialized constructs for handling text parsing, object manipulation, and game state management within the Z-Machine architecture.