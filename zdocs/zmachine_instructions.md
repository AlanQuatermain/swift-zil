# Z‑Machine Instruction Set — Corrected & Integrated

This document supersedes the earlier drafts. It integrates the **byte/form decoding rules** and the **per‑version opcode availability** from the corrected mapping, aligning with the Z‑Machine 1.1 specification.

- **Form decoding:**  
  - 0x00–0x7F → **2OP** (long)  
  - 0x80–0x8F, 0x90–0x9F, 0xA0–0xAF, 0xB0–0xBF → **1OP/0OP** (short), see tables below  
  - 0xC0–0xDF → **VAR (re‑encoding of 2OP:0..31 with type byte)**  
  - 0xE0–0xFF → **VAR (main VAR table)**  
  - 0xBE followed by a byte → **EXT** (extended table)
- **Store byte:** present for store ops (incl. all `call` variants that return values). Saved in the call frame with the return PC.
- **Branch offsets:** relative to the end of the instruction; special cases 0/1 return false/true.
- **Important corrections:**  
  - `0xC1` is **VAR form of 2OP:1 (`je`)**, **not** `storew`.  
  - `storew` is **0xE1** (VAR:225).  
  - `not` is **1OP:0x0F** in V1–V4, then **VAR:248** in V5/6 (not EXT).  
  - `save`/`restore` exist as **0OP** in early versions and **EXT** in V5+.


## 0OP (short) — by *byte* (0xB0–0xBF)

| Byte | Mnemonic      | Versions | Store/Branch | Notes |
|------|---------------|----------|--------------|-------|
| 0xB0 | rtrue         | 1–8      | return 1     | — |
| 0xB1 | rfalse        | 1–8      | return 0     | — |
| 0xB2 | print         | 1–8      | —            | inline literal Z‑string |
| 0xB3 | print_ret     | 1–8      | return 1     | prints then returns |
| 0xB4 | nop           | 3–8      | —            | — |
| 0xB5 | restart       | 1–8      | —            | reset game |
| 0xB6 | ret_popped    | 1–8      | return TOS   | — |
| 0xB7 | catch         | 5–6      | store        | returns frame ID (V5/6) |
| 0xB8 | quit          | 1–8      | —            | — |
| 0xB9 | new_line / pop| 1–8      | —            | **V1** = `pop`; **V2+** = `new_line` |
| 0xBA | show_status / verify | 1–8 | branch      | **V3** = `verify`; **V1** = `show_status` |
| 0xBB | —             | —        | —            | first byte of EXT (0xBE) appears as 0xBE, not here |
| 0xBC | —             | —        | —            | — |
| 0xBD | —             | —        | —            | — |
| 0xBE | **extended**  | 5–8      | —            | EXT prefix byte |
| 0xBF | piracy        | 5        | branch       | optional check |


## 1OP (short) — by *byte* (0x80–0x9F)

| Byte | Mnemonic     | Versions | Store/Branch | Notes |
|------|--------------|----------|--------------|-------|
| 0x80 | jz           | 1–8      | branch       | — |
| 0x81 | get_sibling  | 1–8      | store+branch | branch if non‑zero |
| 0x82 | get_child    | 1–8      | store+branch | branch if non‑zero |
| 0x83 | get_parent   | 1–8      | store        | — |
| 0x84 | get_prop_len | 1–8      | store        | — |
| 0x85 | inc          | 1–8      | —            | — |
| 0x86 | dec          | 1–8      | —            | — |
| 0x87 | print_addr   | 1–8      | —            | — |
| 0x88 | call_1s      | 1–8      | store        | call with 1 arg |
| 0x89 | remove_obj   | 1–8      | —            | — |
| 0x8A | print_obj    | 1–8      | —            | — |
| 0x8B | ret          | 1–8      | return       | — |
| 0x8C | jump         | 1–8      | PC += offset | 16‑bit signed offset |
| 0x8D | print_paddr  | 1–8      | —            | — |
| 0x8E | load         | 1–8      | store        | — |
| 0x8F | not / call_1n| 1–8      | store/—      | **V1–4** = `not` (store); **V5+** = `call_1n` (no store) |


## 2OP (long) — by *byte* (0x00–0x7F)

The 0x00–0x1F block below lists the “primary” 2OPs; 0x20–0x7F are alternate encodings (same mnemonics with different operand type codes).

| Byte | Mnemonic     | Versions | Store/Branch | Notes |
|------|--------------|----------|--------------|-------|
| 0x01 | je           | 1–8      | branch       | — |
| 0x02 | jl           | 1–8      | branch       | signed compare |
| 0x03 | jg           | 1–8      | branch       | signed compare |
| 0x04 | dec_chk      | 1–8      | branch       | dec then compare |
| 0x05 | inc_chk      | 1–8      | branch       | inc then compare |
| 0x06 | jin          | 1–8      | branch       | containment |
| 0x07 | test         | 1–8      | branch       | bit‑test |
| 0x08 | or           | 1–8      | store        | — |
| 0x09 | and          | 1–8      | store        | — |
| 0x0A | test_attr    | 1–8      | branch       | — |
| 0x0B | set_attr     | 1–8      | —            | — |
| 0x0C | clear_attr   | 1–8      | —            | — |
| 0x0D | store        | 1–8      | —            | var = value |
| 0x0E | insert_obj   | 1–8      | —            | — |
| 0x0F | loadw        | 1–8      | store        | — |
| 0x10 | loadb        | 1–8      | store        | — |
| 0x11 | get_prop     | 1–8      | store        | — |
| 0x12 | get_prop_addr| 1–8      | store        | — |
| 0x13 | get_next_prop| 1–8      | store        | — |
| 0x14 | add          | 1–8      | store        | signed |
| 0x15 | sub          | 1–8      | store        | signed |
| 0x16 | mul          | 1–8      | store        | signed |
| 0x17 | div          | 1–8      | store        | signed |
| 0x18 | mod          | 1–8      | store        | signed |
| 0x19 | call_2s      | 4–8      | store        | call with 2 args |
| 0x1A | call_2n      | 5–8      | —            | discard result |
| 0x1B | set_colour   | 5–6      | —            | adds window param in V6 |
| 0x1C | throw        | 5–6      | —            | stack unwind to frame |


## VAR — by *byte* (0xE0–0xFF)  **(main VAR table)**

| Byte | Mnemonic       | Versions | Store/Branch | Notes |
|------|----------------|----------|--------------|-------|
| 0xE0 | call           | 1–8      | store        | 0 addr → store 0 |
| 0xE1 | storew         | 4–8      | —            | — |
| 0xE2 | storeb         | 4–8      | —            | — |
| 0xE3 | put_prop       | 1–8      | —            | — |
| 0xE4 | sread/aread    | 1–8      | store (V5+)  | V1–3 `sread`; V5 `aread` with result |
| 0xE5 | print_char     | 1–8      | —            | — |
| 0xE6 | print_num      | 1–8      | —            | — |
| 0xE7 | random         | 1–8      | store        | 0 = reseed |
| 0xE8 | push           | 1–8      | —            | — |
| 0xE9 | pull           | 1–8      | —/store      | V6 variant stores from stack to array |
| 0xEA | split_window   | 3–8      | —            | — |
| 0xEB | set_window     | 3–8      | —            | — |
| 0xEC | call_vs        | 4–8      | store        | up to 3 args |
| 0xED | erase_window   | 4–8      | —            | — |
| 0xEE | erase_line     | 4–8      | —            | pixels in V6 |
| 0xEF | set_cursor     | 4–8      | —            | adds window in V6 |
| 0xF0 | get_cursor     | 4,6      | store        | — |
| 0xF1 | call_vn        | 5–8      | —            | discard result |
| 0xF2 | call_vn2       | 5–8      | —            | up to 7 args |
| 0xF3 | tokenise       | 5–8      | —            | — |
| 0xF4 | encode_text    | 5–8      | —            | — |
| 0xF5 | copy_table     | 5–8      | —            | — |
| 0xF6 | print_table    | 5–8      | —            | — |
| 0xF7 | check_arg_count| 5–8      | branch       | — |
| 0xF8 | not            | 5–6      | store        | moved from 1OP |


## EXT — Extended opcodes (prefix 0xBE, then byte)

These bytes index the **EXT table** (V5+).

| Index | Mnemonic         | Versions | Store/Branch | Notes |
|-------|------------------|----------|--------------|-------|
| 0x00  | save             | 5–8      | store        | (file/stream or memory snapshot) |
| 0x01  | restore          | 5–8      | store        | — |
| 0x02  | log_shift        | 5–8      | store        | — |
| 0x03  | art_shift        | 5–8      | store        | — |
| 0x04  | set_font         | 5–6      | store        | window param in V6 form |
| 0x05  | draw_picture     | 6        | —            | graphics |
| 0x06  | picture_data     | 6        | branch       | image present? |
| 0x07  | erase_picture    | 6        | —            | — |
| 0x08  | set_margins      | 6        | —            | — |
| 0x09  | save_undo        | 5–8      | store        | — |
| 0x0A  | restore_undo     | 5–8      | store        | — |
| 0x0B  | print_unicode    | 5+       | —            | — |
| 0x0C  | check_unicode    | 5+       | store        | — |
| 0x0D  | set_true_colour  | 5/6      | —            | window form in V6 |
| 0x10  | move_window      | 6        | —            | — |
| 0x11  | window_size      | 6        | —            | — |
| 0x12  | window_style     | 6        | —            | — |
| 0x13  | get_wind_prop    | 6        | store        | — |
| 0x14  | scroll_window    | 6        | —            | — |
| 0x15  | pop_stack        | 6        | —            | — |
| 0x16  | read_mouse       | 6        | —            | — |
| 0x17  | mouse_window     | 6        | —            | — |
| 0x18  | push_stack       | 6        | branch       | — |
| 0x19  | put_wind_prop    | 6        | —            | — |
| 0x1A  | print_form       | 6        | —            | — |
| 0x1B  | make_menu        | 6        | branch       | — |
| 0x1C  | picture_table    | 6        | —            | — |
| 0x1D  | buffer_screen    | 6        | store        | — |
