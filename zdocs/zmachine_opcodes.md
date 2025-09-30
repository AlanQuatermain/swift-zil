# Z-Machine Opcodes Reference

This document lists the complete set of Z-Machine opcodes, their **mnemonics**, and their **semantics** (what the VM should do).  
Instructions are grouped by operand count/type (0OP, 1OP, 2OP, VAR, EXT).

---

## 0OP Instructions (no operands)

| Mnemonic | Purpose |
|----------|---------|
| `RTRUE` | Return from routine with value `true` (1). |
| `RFALSE` | Return from routine with value `false` (0). |
| `PRINT` | Print a literal Z-string embedded in the instruction stream. |
| `PRINT_RET` | Print a Z-string, then return `true`. |
| `NOP` | No operation (does nothing). |
| `RESTART` | Restart the game (reinitialize memory). |
| `RET_POPPED` | Return from routine with the top value popped from the evaluation stack. |
| `CATCH` | Push the current stack frame identifier for later use with `THROW`. |
| `QUIT` | Terminate the interpreter/game session. |
| `NEW_LINE` | Print a newline character. |
| `VERIFY` | Perform checksum validation of story file, set branch accordingly. |

---

## 1OP Instructions (one operand)

| Mnemonic | Purpose |
|----------|---------|
| `JZ a` | Branch if operand `a` equals 0. |
| `GET_SIBLING obj -> (result)` | Store sibling of `obj` in result, branch if sibling exists. |
| `GET_CHILD obj -> (result)` | Store first child of `obj` in result, branch if child exists. |
| `GET_PARENT obj -> (result)` | Store parent of `obj`. |
| `GET_PROP_LEN addr -> (result)` | Read property length at given address. |
| `INC var` | Increment variable. |
| `DEC var` | Decrement variable. |
| `PRINT_ADDR addr` | Print the Z-string at memory address `addr`. |
| `CALL_1S routine -> (result)` | Call routine with 1 operand, store result. |
| `REMOVE_OBJ obj` | Unlink object from parent/sibling tree. |
| `PRINT_OBJ obj` | Print the short name of object. |
| `RET value` | Return from routine with value. |
| `JUMP offset` | Branch unconditionally by signed offset. |
| `PRINT_PADDR packedAddr` | Print Z-string at packed address. |
| `LOAD var -> (result)` | Load variable’s value. |
| `NOT value -> (result)` | Bitwise NOT (in V5+). |

---

## 2OP Instructions (two operands)

| Mnemonic | Purpose |
|----------|---------|
| `JE a b [c d]` | Branch if `a` = any of `b`, `c`, or `d`. |
| `JL a b` | Branch if `a` < `b` (signed). |
| `JG a b` | Branch if `a` > `b` (signed). |
| `DEC_CHK var value` | Decrement `var`; branch if new value < `value`. |
| `INC_CHK var value` | Increment `var`; branch if new value > `value`. |
| `JIN obj1 obj2` | Branch if `obj1` is contained in `obj2`. |
| `TEST bitmap flags` | Branch if all bits in `flags` are set in `bitmap`. |
| `OR a b -> (result)` | Bitwise OR. |
| `AND a b -> (result)` | Bitwise AND. |
| `TEST_ATTR obj attr` | Branch if object has attribute. |
| `SET_ATTR obj attr` | Set attribute bit. |
| `CLEAR_ATTR obj attr` | Clear attribute bit. |
| `STORE var value` | Assign value to variable. |
| `INSERT_OBJ obj dest` | Move `obj` under `dest` in object tree. |
| `LOADW array index -> (result)` | Load word from `array[index]`. |
| `LOADB array index -> (result)` | Load byte from `array[index]`. |
| `GET_PROP obj prop -> (result)` | Fetch object property value. |
| `GET_PROP_ADDR obj prop -> (result)` | Get address of object property. |
| `GET_NEXT_PROP obj prop -> (result)` | Get next property ID after `prop`. |
| `ADD a b -> (result)` | Signed addition. |
| `SUB a b -> (result)` | Signed subtraction. |
| `MUL a b -> (result)` | Signed multiplication. |
| `DIV a b -> (result)` | Signed division. |
| `MOD a b -> (result)` | Signed modulus. |
| `CALL_2S routine arg1 -> (result)` | Call routine with 2 arguments, store result. |

---

## VAR Instructions (variable operand count)

| Mnemonic | Purpose |
|----------|---------|
| `CALL routine [args...] -> (result)` | Call routine with 0–3 arguments. |
| `CALL_VS routine [args...] -> (result)` | Call routine with up to 3 args (V4+). |
| `CALL_VN routine [args...]` | Same as above, but discard result. |
| `CALL_VN2 routine [args...]` | Variant for extended ranges. |
| `AREAD text parse time result` | Read input line, tokenize into buffers. |
| `PRINT_CHAR ch` | Print character. |
| `PRINT_NUM value` | Print signed number in decimal. |
| `RANDOM range -> (result)` | Random number (0 = re-seed). |
| `PUSH value` | Push value onto evaluation stack. |
| `POP var` | Pop from stack into variable. |
| `PULL var` | Opposite of `PUSH`: pop into variable. |
| `CHECK_ARG_COUNT count` | Branch if routine was called with ≥ count args. |

---

## EXT Instructions (Extended set, V5+)

| Mnemonic | Purpose |
|----------|---------|
| `SAVE` | Save game state (to file/stream or memory). |
| `RESTORE` | Restore game state. |
| `LOG_SHIFT a b -> (result)` | Logical shift left/right. |
| `ART_SHIFT a b -> (result)` | Arithmetic shift left/right. |
| `SET_FONT font -> (result)` | Set output font (V6). |
| `DRAW_PICTURE pic x y` | Display picture (V6). |
| `ERASE_PICTURE pic` | Erase picture (V6). |
| `SET_MARGINS left right` | Adjust text margins. |
| `SAVE_UNDO -> (result)` | Save undo snapshot. |
| `RESTORE_UNDO -> (result)` | Restore undo snapshot. |
| `CATCH` | Frame capture (same as 0OP). |
| `THROW value frame` | Unwind stack to frame, return value. |
| `SOUND_EFFECT n` | Play sound effect. |
| `INPUT_STREAM n` | Select input stream. |
| `OUTPUT_STREAM n` | Select output stream. |
| `SCROLL_WINDOW lines` | Scroll window (V6). |
| `BUFFER_MODE flag` | Switch input buffer behavior. |
| `READ_CHAR time routine -> (result)` | Read a single keystroke. |
| `SCAN_TABLE x table len form -> (result)` | Search table. |
| `NOT value -> (result)` | Bitwise NOT (moved here in some versions). |
| `COPY_TABLE src dst size` | Copy memory between tables. |
| `PRINT_TABLE addr width height skip` | Print character table. |
| `CHECK_UNICODE ch -> (result)` | Check Unicode support. |
| `PRINT_UNICODE ch` | Print Unicode character. |

---

# 🔍 Notes

- Branching instructions all follow the same convention: the instruction encodes a **branch offset** and whether to branch if true/false.
- The **stack**: local variables are accessed via var numbers; `SP` stack is used for temps.
- **Calls**: A “routine” is just a packed address in memory that contains local variable count + bytecode. Results go to a variable if specified.
- **Object tree**: objects form a linked tree with parent/child/sibling links and property tables.
- **I/O**: text output goes through the VM’s stream system; input is tokenized via the dictionary.
