# Quetzal Save Format — `Stks` Chunk and Program Counter (PC)

## Overview

The `Stks` chunk stores the **complete Z-Machine call stack** — every active routine frame, its locals, and the evaluation stack.  
The **Program Counter (PC)** to resume execution from is stored within the *topmost stack frame* in this chunk.

When restoring a Quetzal file:

1. Load and verify the `IFhd` chunk (release, serial, checksum only).  
2. Restore memory from `CMem` or `UMem`.  
3. Rebuild the stack from `Stks`.  
4. Set the interpreter’s **PC to the return address stored in the topmost frame**.  
5. Resume execution from that PC.

---

## Chunk Header

| Offset | Size | Field | Description |
|:-------:|:-----:|:------|-------------|
| 0x00 | 4 bytes | `"Stks"` | Chunk identifier |
| 0x04 | 4 bytes | `length` | Length of data (not including this header) |
| 0x08… | variable | Frame records | One per active call frame, oldest first |

---

## Frame Record Layout

Each frame represents one active routine call.

| Field | Size | Description |
|--------|------|-------------|
| **Return PC** | **3 bytes** | Address of next instruction to execute when this frame returns. For the top frame, this is the *current PC* at save time. |
| **Return variable** | 1 byte | Variable number (0–255) to store the result in, or 0xFF if discarded. |
| **Arguments mask** | 1 byte | Bitmask showing which arguments were supplied. |
| **Eval stack size** | 2 bytes | Number of 16-bit values currently pushed on the eval stack for this frame. |
| **Local count** | (implicit) | Determined by routine header; locals follow immediately. |
| **Local variables** | n × 2 bytes | Current values of the routine’s locals. |
| **Eval stack contents** | m × 2 bytes | Values pushed since routine entry. |

Frames are written oldest-to-newest; the **last frame** in the chunk is the one active at the time of the save.

---

## Program Counter Restoration

During restore:

1. Read the final (topmost) frame in the `Stks` chunk.  
2. Extract its **3-byte Return PC** field.  
3. Set the interpreter’s **Program Counter (PC)** to that address.

> ⚠️ The PC in the `IFhd` chunk is *not* used for execution.  
> It merely mirrors the header field from the story file for identification and should be ignored after validation.

---

## Example (Hex Dump)

Example excerpt from a Quetzal `Stks` chunk (hexadecimal):

    0000: 53 74 6B 73 00 00 00 22   -- "Stks", length = 0x22 (34 bytes)
    0008: 00 12 34 FF 1F 00 02      -- Frame start
           ^^^^^^^
           Return PC = 0x001234
                 ^^
                 Return var = 0xFF (discard result)
                    ^^
                    Args mask = 0x1F (five args)
                       ^^^^
                       Eval stack size = 0x0002
    000F: 00 10 00 20                -- Two local variables (0x10, 0x20)
    0013: 00 05 00 07                -- Eval stack values (0x0005, 0x0007)

When restoring:
- PC = `0x001234`  
- Return variable = discard result  
- Two locals (0x10, 0x20)  
- Eval stack values = [5, 7]

Execution resumes **at address 0x001234**, the instruction immediately following the original `SAVE`.

---

## Summary

| Source | Field | Purpose | Used to restore PC? |
|---------|--------|----------|--------------------|
| `IFhd` | Header bytes (0x00–0x3F) | Identifies story file | ❌ No |
| `Stks` | Return PC (topmost frame) | Resume point | ✅ Yes |

**Rule:**  
> “The Program Counter after restoring a Quetzal file must be set to the Return PC stored in the final frame record of the `Stks` chunk.”

---

## References

- *Quetzal Interchange Format for Z-Machine Save Files (IFZS 1.4)* — Graham Nelson, et al.  
- [Z-Machine Standards Document 1.1, §7 and §14](https://inform-fiction.org/zmachine/standards/)
