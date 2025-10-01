# Z‑Machine Opcode Matrix (Corrected, V1–V8)

`✔` present / `✖` absent. Where semantics changed, brief notes are included.


## 0OP

| Byte | Mnemonic       | V1 | V2 | V3 | V4 | V5 | V6 | V7 | V8 | Notes |
|------|----------------|----|----|----|----|----|----|----|----|-------|
| B0   | `rtrue`          | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| B1   | `rfalse`         | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| B2   | `print`          | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| B3   | `print_ret`      | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| B4   | `nop`            | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| B5   | `restart`        | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| B6   | `ret_popped`     | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| B7   | `catch`          | ✖  | ✖  | ✖  | ✖  | ✔  | ✔  | ✖  | ✖  | V5/6 only |
| B8   | `quit`           | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| B9   | `new_line` / `pop` | **pop** | new_line | new_line | new_line | new_line | new_line | new_line | new_line | V1=pop |
| BA   | `show_status`/`verify` | show_status | show_status | verify | verify | verify | verify | verify | verify | — |
| BF   | `piracy`         | ✖  | ✖  | ✖  | ✖  | ✔  | ✖  | ✖  | ✖  | optional |


## 1OP

| Byte | Mnemonic      | V1 | V2 | V3 | V4 | V5 | V6 | V7 | V8 | Notes |
|------|---------------|----|----|----|----|----|----|----|----|-------|
| 80   | `jz`            | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 81   | `get_sibling`   | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 82   | `get_child`     | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 83   | `get_parent`    | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 84   | `get_prop_len`  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 85   | `inc`           | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 86   | `dec`           | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 87   | `print_addr`    | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 88   | `call_1s`       | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 89   | `remove_obj`    | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 8A   | `print_obj`     | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 8B   | `ret`           | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 8C   | `jump`          | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | 16‑bit signed |
| 8D   | `print_paddr`   | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 8E   | `load`          | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 8F   | `not` / `call_1n` | not | not | not | not | call_1n | call_1n | call_1n | call_1n | moved in V5+ |


## 2OP (primary)

| Byte | Mnemonic   | V1 | V2 | V3 | V4 | V5 | V6 | V7 | V8 | Notes |
|------|------------|----|----|----|----|----|----|----|----|-------|
| 01   | `je`         | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 02   | `jl`         | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 03   | `jg`         | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 04   | `dec_chk`    | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 05   | `inc_chk`    | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 06   | `jin`        | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 07   | `test`       | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 08   | `or`         | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 09   | `and`        | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 0A   | `test_attr`  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | branch |
| 0B   | `set_attr`   | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 0C   | `clear_attr` | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 0D   | `store`      | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 0E   | `insert_obj` | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | — |
| 0F   | `loadw`      | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 10   | `loadb`      | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 11   | `get_prop`   | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 12   | `get_prop_addr` | ✔ | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 13   | `get_next_prop` | ✔ | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 14   | `add`        | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 15   | `sub`        | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 16   | `mul`        | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 17   | `div`        | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 18   | `mod`        | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 19   | `call_2s`    | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  | ✔  | store |
| 1A   | `call_2n`    | ✖  | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  | no store |
| 1B   | `set_colour` | ✖  | ✖  | ✖  | ✖  | ✔  | ✔  | ✖  | ✖  | V6 adds window |
| 1C   | `throw`      | ✖  | ✖  | ✖  | ✖  | ✔  | ✔  | ✖  | ✖  | — |


## VAR (0xE0–0xFF)

| Byte | Mnemonic        | V1 | V2 | V3 | V4 | V5 | V6 | V7 | V8 |
|------|-----------------|----|----|----|----|----|----|----|----|
| E0   | `call`            | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  |
| E1   | `storew`          | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  | ✔  |
| E2   | `storeb`          | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  | ✔  |
| E3   | `put_prop`        | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  |
| E4   | `sread`/`aread`     | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  |
| E5   | `print_char`      | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  |
| E6   | `print_num`       | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  |
| E7   | `random`          | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  |
| E8   | `push`            | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  |
| E9   | `pull`            | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  |
| EA   | `split_window`    | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  |
| EB   | `set_window`      | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  | ✔  | ✔  |
| EC   | `call_vs`         | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  | ✔  |
| ED   | `erase_window`    | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  | ✔  |
| EE   | `erase_line`      | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  | ✔  |
| EF   | `set_cursor`      | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  | ✔  |
| F0   | `get_cursor`      | ✖  | ✖  | ✖  | ✔  | ✖  | ✔  | ✖  | ✖  |
| F1   | `call_vn`         | ✖  | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  |
| F2   | `call_vn2`        | ✖  | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  |
| F3   | `tokenise`        | ✖  | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  |
| F4   | `encode_text`     | ✖  | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  |
| F5   | `copy_table`      | ✖  | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  |
| F6   | `print_table`     | ✖  | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  |
| F7   | `check_arg_count` | ✖  | ✖  | ✖  | ✖  | ✔  | ✔  | ✔  | ✔  |
| F8   | `not`             | ✖  | ✖  | ✖  | ✖  | ✔  | ✔  | ✖  | ✖  |


## EXT (0xBE prefix)

| Id | Mnemonic         | V5 | V6 | V7 | V8 | Notes |
|----|------------------|----|----|----|----|-------|
| 00 | `save`             | ✔  | ✔  | ✔  | ✔  | — |
| 01 | `restore`          | ✔  | ✔  | ✔  | ✔  | — |
| 02 | `log_shift`        | ✔  | ✔  | ✔  | ✔  | — |
| 03 | `art_shift`        | ✔  | ✔  | ✔  | ✔  | — |
| 04 | `set_font`         | ✔  | ✔  | ✖  | ✖  | window form in V6 |
| 05 | `draw_picture`     | ✖  | ✔  | ✖  | ✖  | V6 graphics |
| 06 | `picture_data`     | ✖  | ✔  | ✖  | ✖  | V6 graphics |
| 07 | `erase_picture`    | ✖  | ✔  | ✖  | ✖  | V6 graphics |
| 08 | `set_margins`      | ✖  | ✔  | ✖  | ✖  | V6 graphics |
| 09 | `save_undo`        | ✔  | ✔  | ✔  | ✔  | — |
| 0A | `restore_undo`     | ✔  | ✔  | ✔  | ✔  | — |
| 0B | `print_unicode`    | ✔  | ✔  | ✔  | ✔  | — |
| 0C | `check_unicode`    | ✔  | ✔  | ✔  | ✔  | — |
| 0D | `set_true_colour`  | ✔  | ✔  | ✖  | ✖  | — |
| 10 | `move_window`      | ✖  | ✔  | ✖  | ✖  | — |
| 11 | `window_size`      | ✖  | ✔  | ✖  | ✖  | — |
| 12 | `window_style`     | ✖  | ✔  | ✖  | ✖  | — |
| 13 | `get_wind_prop`    | ✖  | ✔  | ✖  | ✖  | — |
| 14 | `scroll_window`    | ✖  | ✔  | ✖  | ✖  | — |
| 15 | `pop_stack`        | ✖  | ✔  | ✖  | ✖  | — |
| 16 | `read_mouse`       | ✖  | ✔  | ✖  | ✖  | — |
| 17 | `mouse_window`     | ✖  | ✔  | ✖  | ✖  | — |
| 18 | `push_stack`       | ✖  | ✔  | ✖  | ✖  | — |
| 19 | `put_wind_prop`    | ✖  | ✔  | ✖  | ✖  | — |
| 1A | `print_form`       | ✖  | ✔  | ✖  | ✖  | — |
| 1B | `make_menu`        | ✖  | ✔  | ✖  | ✖  | — |
| 1C | `picture_table`    | ✖  | ✔  | ✖  | ✖  | — |
| 1D | `buffer_screen`    | ✖  | ✔  | ✖  | ✖  | — |
