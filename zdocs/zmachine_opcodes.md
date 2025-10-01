# Z‑Machine Opcodes — Corrected Reference

This file lists **all Z‑Machine opcodes** by actual byte value (0x00–0xFF) and by extended tables.  
It integrates the corrected mapping, so that confusing cases (e.g. 0xC1 vs 0xE1) are accurate.

---

## Z-Machine Opcodes — Corrected Overview

This document corrects the earlier summary and aligns with the Z-Machine Standard (v1.1). It explains how to decode the **first opcode byte**, how the **forms** (long/short/variable/extended) and **operand counts** (2OP/1OP/0OP/VAR) interrelate, and why ranges like `0xA0–0xAF` are **1OP**, not 0OP.

---

### 1) First opcode byte: ranges and meaning

> The high bits of the **first opcode byte** pick the form. In **short form**, bits 5–4 pick the **operand type**; if those bits are `11` (omitted), the count is **0OP**; otherwise it’s **1OP**.

```
Byte range   Form     Meaning inside the range
-----------  -------  -----------------------------------------------------------
00–7F        long     2OP form ("long"). Low 5 bits are the opcode number.
80–BF        short    short form. Bits 5–4 = operand type → determines 1OP vs 0OP:
                         80–8F : 1OP with operand type = large constant (00)
                         90–9F : 1OP with operand type = small constant (01)
                         A0–AF : 1OP with operand type = variable      (10)
                         B0–BF : 0OP (operand omitted)                 (11)
C0–DF        variable variable form **re-encoding of 2OP** (bit 5 = 0)
E0–FF        variable variable form **VAR** instructions     (bit 5 = 1)
BE           special  Extended prefix (v5+). Second byte selects EXT opcode.
```

**Key fixes compared to the old doc**

* `A0–AF` are **1OP** (short form, operand type = **variable**), **not** 0OP.
* `B0–BF` are the **0OP** short-form block (operand type = **omitted**).
* `C0–DF` and `E0–FF` are both **variable form**; bit 5 distinguishes **2OP re-encodings** vs **true VAR**.

---

### 2) Bit layouts you’ll actually use

#### 2.1 Short form (covers 0OP and 1OP)

```
7 6 5 4 3 2 1 0
1 0 t t  o o o o
^ ^ ^ ^  ^^^^^^^
| | | |  └─ opcode number (0..15) within the short-form table
| | └┴── operand type t t : 00=large const, 01=small const, 10=variable, 11=omitted
| └───── short form (10)
└─────── short form (10)
```

* If `t t = 11` → **0OP** (no operand bytes follow).
* Otherwise → **1OP** (exactly one operand; its size comes from `t t`).

#### 2.2 Long form (2OP)

```
7 6 5 4 3 2 1 0
0 x y o o o o o    (x=type of operand1, y=type of operand2; 0=small const, 1=variable)
```

* Always **2OP**; if an instruction needs a large constant operand, it will be assembled in **variable** form instead.

#### 2.3 Variable form

```
7 6 5 4 3 2 1 0   → first byte = 1 1 c o o o o o  (c = 0→2OP, 1→VAR)
[types byte(s)]   → four 2‑bit fields of operand types (00/01/10/11)
```

* In **variable** form, you get a separate **types byte** which enumerates operand types.

#### 2.4 Extended form

* The first opcode byte is literally `0xBE` in V5+ and a **second opcode byte** picks the EXT opcode.

---

### 3) “Opcode number” vs literal byte

The Standard’s tables list entries like **`1OP:128`** with a **Hex column 0..F**. That **Hex** column is the opcode number **within the class**, **not** the literal byte value you see in memory. In short form, the **bottom nibble** is the within-class opcode; the **top bits** encode the form and operand type.

---

### 4) Where JZ and friends live (examples)

* **`jz`** is **1OP**, opcode number **hex 0** within the 1OP table.
* Depending on the operand type, the **first opcode byte** will be one of:

  * `0x80` (large-constant 1OP),
  * `0x90` (small-constant 1OP),
  * `0xA0` (variable 1OP).
* The **0OP block** (`0xB0–0xBF`) does **not** contain `jz`.

#### Encodings you will see

```
@jz 0              → 0x80 0x00 0x00  [then branch bytes]
@jz 44             → 0x90 0x2C       [then branch bytes]
@jz [var] (e.g., sp) → 0xA0 0x00       [then branch bytes]   ; var#0 = stack
```

*(Branch bytes follow the operand; short/long branch is chosen by the assembler.)*

---

### 5) Quick index by first byte

* **00–7F**: 2OP long-form encodings (two operands; small-const/variable combo embedded in the opcode bits)
* **80–8F**: 1OP, large-constant operand (e.g., `0x80` = 1OP hex 0 → `jz` large-const)
* **90–9F**: 1OP, small-constant operand
* **A0–AF**: 1OP, variable operand (var# byte follows)
* **B0–BF**: 0OP (no operands). Note `0xBE` is the **extended prefix** in V5+.
* **C0–DF**: variable form, **2OP re-encodings** (bit 5 = 0)
* **E0–FF**: variable form, **VAR instructions** (bit 5 = 1)

---

### 6) Common pitfalls (and fixes)

* Confusing the **Hex column** in the spec’s tables (0..F within the class) with the literal **first opcode byte** in memory. Use the **form** and **operand-type bits** to map from the byte to the table.
* Assuming `A0–AF` are 0OP. They are **1OP with variable operands**; **0OP** is `B0–BF`.
* Forgetting that `0xBE` is a short-form **0OP entry** repurposed as the **extended-opcode prefix** in V5+.

---

### 7) Branch bytes refresher (for JZ/JNZ/JE/…)

* Branch opcodes carry **branch info** after the operand(s).
* First branch byte: bit 7 = branch-on-true/false; bit 6 = short/long form. Short branch packs a 6‑bit offset; long branch uses 14 bits across two bytes.
* Offsets 0 and 1 mean **return false/true**, respectively.

---

Key corrections:

- `0xC1` = VAR form of 2OP:1 (`je`), not `storew`.  
- `0xE1` = `storew`.  
- `not` is `0x8F` in V1–4, then moves to `0xF8` in V5/6.  
- `call_1n` (1OP:0x8F) appears in V5+.  
- `call_2n` (2OP:0x1A) appears in V5+.  
- Early V1–2 had `pop` at 0xB9, replaced by `new_line` in V2+.  

---

## 2OP (0x00–0x7F)

| Byte | Mnemonic     | Versions |
|------|--------------|----------|
| 0x01 | je           | 1–8      |
| 0x02 | jl           | 1–8      |
| 0x03 | jg           | 1–8      |
| 0x04 | dec_chk      | 1–8      |
| 0x05 | inc_chk      | 1–8      |
| 0x06 | jin          | 1–8      |
| 0x07 | test         | 1–8      |
| 0x08 | or           | 1–8      |
| 0x09 | and          | 1–8      |
| 0x0A | test_attr    | 1–8      |
| 0x0B | set_attr     | 1–8      |
| 0x0C | clear_attr   | 1–8      |
| 0x0D | store        | 1–8      |
| 0x0E | insert_obj   | 1–8      |
| 0x0F | loadw        | 1–8      |
| 0x10 | loadb        | 1–8      |
| 0x11 | get_prop     | 1–8      |
| 0x12 | get_prop_addr| 1–8      |
| 0x13 | get_next_prop| 1–8      |
| 0x14 | add          | 1–8      |
| 0x15 | sub          | 1–8      |
| 0x16 | mul          | 1–8      |
| 0x17 | div          | 1–8      |
| 0x18 | mod          | 1–8      |
| 0x19 | call_2s      | 4–8      |
| 0x1A | call_2n      | 5–8      |
| 0x1B | set_colour   | 5–6      |
| 0x1C | throw        | 5–6      |

---

## 1OP (0x80–0x9F)

| Byte | Mnemonic     | Versions |
|------|--------------|----------|
| 0x80 | jz           | 1–8      |
| 0x81 | get_sibling  | 1–8      |
| 0x82 | get_child    | 1–8      |
| 0x83 | get_parent   | 1–8      |
| 0x84 | get_prop_len | 1–8      |
| 0x85 | inc          | 1–8      |
| 0x86 | dec          | 1–8      |
| 0x87 | print_addr   | 1–8      |
| 0x88 | call_1s      | 1–8      |
| 0x89 | remove_obj   | 1–8      |
| 0x8A | print_obj    | 1–8      |
| 0x8B | ret          | 1–8      |
| 0x8C | jump         | 1–8      |
| 0x8D | print_paddr  | 1–8      |
| 0x8E | load         | 1–8      |
| 0x8F | not (V1–4) / call_1n (V5+) | — |

---

## 0OP (0xB0–0xBF)

| Byte | Mnemonic        | Versions |
|------|-----------------|----------|
| 0xB0 | rtrue           | 1–8      |
| 0xB1 | rfalse          | 1–8      |
| 0xB2 | print           | 1–8      |
| 0xB3 | print_ret       | 1–8      |
| 0xB4 | nop             | 3–8      |
| 0xB5 | restart         | 1–8      |
| 0xB6 | ret_popped      | 1–8      |
| 0xB7 | catch           | 5–6      |
| 0xB8 | quit            | 1–8      |
| 0xB9 | pop (V1) / new_line (V2+) | — |
| 0xBA | show_status (V1) / verify (V3+) | — |
| 0xBF | piracy          | 5        |

---

## VAR (0xE0–0xFF)

| Byte | Mnemonic       | Versions |
|------|----------------|----------|
| 0xE0 | call           | 1–8      |
| 0xE1 | storew         | 4–8      |
| 0xE2 | storeb         | 4–8      |
| 0xE3 | put_prop       | 1–8      |
| 0xE4 | sread (V1–3) / aread (V5+) | — |
| 0xE5 | print_char     | 1–8      |
| 0xE6 | print_num      | 1–8      |
| 0xE7 | random         | 1–8      |
| 0xE8 | push           | 1–8      |
| 0xE9 | pull           | 1–8      |
| 0xEA | split_window   | 3–8      |
| 0xEB | set_window     | 3–8      |
| 0xEC | call_vs        | 4–8      |
| 0xED | erase_window   | 4–8      |
| 0xEE | erase_line     | 4–8      |
| 0xEF | set_cursor     | 4–8      |
| 0xF0 | get_cursor     | 4,6      |
| 0xF1 | call_vn        | 5–8      |
| 0xF2 | call_vn2       | 5–8      |
| 0xF3 | tokenise       | 5–8      |
| 0xF4 | encode_text    | 5–8      |
| 0xF5 | copy_table     | 5–8      |
| 0xF6 | print_table    | 5–8      |
| 0xF7 | check_arg_count| 5–8      |
| 0xF8 | not (moved)    | 5–6      |

---

## EXT (0xBE prefix)

| Index | Mnemonic       | Versions |
|-------|----------------|----------|
| 0x00  | save           | 5–8      |
| 0x01  | restore        | 5–8      |
| 0x02  | log_shift      | 5–8      |
| 0x03  | art_shift      | 5–8      |
| 0x04  | set_font       | 5–6      |
| 0x05  | draw_picture   | 6        |
| 0x06  | picture_data   | 6        |
| 0x07  | erase_picture  | 6        |
| 0x08  | set_margins    | 6        |
| 0x09  | save_undo      | 5–8      |
| 0x0A  | restore_undo   | 5–8      |
| 0x0B  | print_unicode  | 5+       |
| 0x0C  | check_unicode  | 5+       |
| 0x0D  | set_true_colour| 5/6      |
| 0x10  | move_window    | 6        |
| 0x11  | window_size    | 6        |
| 0x12  | window_style   | 6        |
| 0x13  | get_wind_prop  | 6        |
| 0x14  | scroll_window  | 6        |
| 0x15  | pop_stack      | 6        |
| 0x16  | read_mouse     | 6        |
| 0x17  | mouse_window   | 6        |
| 0x18  | push_stack     | 6        |
| 0x19  | put_wind_prop  | 6        |
| 0x1A  | print_form     | 6        |
| 0x1B  | make_menu      | 6        |
| 0x1C  | picture_table  | 6        |
| 0x1D  | buffer_screen  | 6        |
