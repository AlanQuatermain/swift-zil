# Z‑Machine Opcodes — Corrected Reference

This file lists **all Z‑Machine opcodes** by actual byte value (0x00–0xFF) and by extended tables.  
It integrates the corrected mapping, so that confusing cases (e.g. 0xC1 vs 0xE1) are accurate.

---

## Decoding Summary

- **00–7F** → 2OP form (long)  
- **80–9F** → 1OP form (short)  
- **A0–AF** → 0OP form (short)  
- **B0–BF** → 0OP/1OP continuation (see table)  
- **C0–DF** → VAR form re‑encoding of 2OP:0–31 (with type byte)  
- **E0–FF** → VAR instructions (main VAR table)  
- **BE** → EXT prefix (followed by an extra byte indexing the EXT table)

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
