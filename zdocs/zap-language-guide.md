# Infocom ZAP (Z-language Assembly Program) — Language Guide

> **Scope.** This guide describes the *ZAP* assembler language used by Infocom to assemble Z‑machine programs. It covers source structure, symbols, statement syntax, operand prefixes, pseudo‑ops, required labels, and program layout. The Z‑machine **operators** (instruction mnemonics) are the same as those defined for ZIP (the Z‑machine interpreter) and are referenced here rather than duplicated in full.

---

## 1) What ZAP is
ZAP is an absolute assembler for Z‑code which runs in **two passes** (with an optional *pre‑pass* for the frequently‑used‑word table, FWORDS).

- **Pass 1:** checks syntax, computes locations, resolves as many symbols as possible.
- **Pass 2:** emits code/data, lists messages, and fixes remaining references.
- **Optional pre‑pass:** if you omit the `FWORDS` table, ZAP searches all strings, picks up to 32 frequent substrings, and defines them with `.FSTR` entries in the auto‑generated table. See the ZIP string format for details.

> Source: “ZAP: Z‑language Assembly Program” (Scribe file `spec-zap.fwf`).

---

## 2) Character set and tokens
Outside of strings/comments, source uses an uppercase alphabet and a restricted punctuation set:

- Letters: `A`–`Z`
- Digits and minus: `0`–`9`, `-` (used in numbers / symbols)
- Additional symbol constituents: `? # .`
- **Operand‑prefix characters:** see §4
- String delimiter: `"`
- Comment prefix: `;`
- End of line terminates a statement

> Labels use colons: `label:` (local) or `Label::` (global).

> Source: ZAP manual, “Character Set” and “Symbols”.

---

## 3) Symbols, scope, and kinds
ZAP associates each symbol with a **type** and a **value** at definition time; you normally do **not** annotate types at use sites.

- **Global labels** (range is the whole program) name global data locations or functions. Define with `::`, with pseudo‑ops, or by assignment.
- **Local labels** are branch targets within a function; define with `:` and reuse per function.
- **Constants** are global and may be **redefined**; assign with `.EQUAL`/`=` or `.SEQ` (sequential).
- **Global variables** live in the `GLOBAL` table and are created with `.GVAR` (see §6.4).
- **Local variables** live on the stack and are declared on `.FUNCT` (see §6.5).

> Source: ZAP manual, “Symbols”.

---

## 4) Statement layout and operand prefixes

A source **statement** has up to four fields, all optional:

```
[label[:|::]]  operator  [operands]  [; comment]
```

- If present, the **operands** field begins after a space/tab. Each operand **after the first** begins with an **operand‑prefix** character (you can also write the first with a prefix for clarity).
- **Operand prefixes** (as characters appearing *before* an operand):
  - `,` — **general operand prefix** (separates operands)
  - `>` — **store**: destination for an instruction’s returned value
  - `/` — **branch on success** (target label after predicates)
  - `\` — **branch on failure** (target label after predicates)
  - `=` — **value/assignment** (e.g., default value in `.GVAR` or `.FUNCT` initializers)
  - `+` — **addend** (add a constant; used in places which take sums)
- **Comments** start with `;` and run to end of line.

> Sources: ZAP manual, “Statement Syntax” and “Character Set”.

### 4.1 Examples (operands, store, and predicate branches)

```
; Return value stored in global COUNTER
ADD ,COUNTER ,=1  >COUNTER

; Branch if ZERO? succeeds; otherwise fall through
ZERO? ,COUNTER /DONE
  PRINTI "NOT ZERO"
DONE:

; Branch if predicate fails
EQUAL? ,OBJ ,OTHER \NOTEQUAL  ; if !=, branch to NOTEQUAL
```

---

## 5) Bare operands shortcut
For convenience:

- A **bare expression** on a line is interpreted as `.WORD expr`
- A **bare string** is interpreted as `.STR "..."`

> Source: ZAP manual, “Simple Data‑generation Pseudo‑ops” and “String Handling Pseudo‑ops”.

---

## 6) Pseudo‑ops (assembler directives)

Below is the canonical set, with ZAP’s meta‑syntax in angle brackets and `{…}` meaning “repeat zero or more”. The phrasing follows the Infocom docs.

### 6.1 Simple data generation
- `.WORD {<expr>, ...}`  
  Emit each expression as a two‑byte word.
  - *Shortcut:* writing a lone expression is the same as `.WORD expr`.
- `.BYTE {<expr>, ...}`  
  Emit each expression as a single byte.
- `.TRUE` → `.WORD 1`  
- `.FALSE` → `.WORD 0`  

### 6.2 Strings
- `.ZWORD <string>`  
  Pack up to two Z‑words (4 bytes) from a short string, left‑justified and space‑padded as needed.
- `.STR <string>`  
  Emit a compressed Z‑string in two‑byte words; last word has end‑of‑string bit set; padding uses shift‑5 chars as needed. Regular strings are searched for FWORD substrings (unless using `.FSTR`).
- `.FSTR <string>`  
  Emit a string *without* FWORD search and **add it** to the 32‑entry FWORDS table (to be defined after `FWORDS::`).
- `.LEN <string>`  
  Emit a single **byte** giving the number of words the corresponding `.STR` would occupy.
- `.STRL <string>`  
  Exactly equivalent to:
  ```
  .LEN <string>
  .STR <string>
  ```

### 6.3 Assignment and constants
- `.EQUAL <symbol>, <symbol-or-constant>`  
  Assign the **same value and type** as the right‑hand side. If any operand is a **constant**, the result type becomes **constant**.  
  *Short form:* `=<symbol-or-constant>` is accepted.
- `.SEQ {<symbol>, ...}`  
  Assign each listed symbol a **constant** value in sequence, starting from **0**.

### 6.4 Tables, objects, globals
- `.TABLE [<max-bytes>]`  
  Declare that a **table** is being emitted; optionally supply a maximum size to enforce.
- `.PROP <size>, <id>`  
  Emit a one‑byte property header with **size** (1–8) and **id** (1–31).
- `.ENDT`  
  End the current table; if a maximum was given in `.TABLE`, ensure the limit is not exceeded.
- `.OBJECT <name>, <flags1>, <flags2>, <loc>, <first>, <next>, <prop-table>`  
  Emit an object entry. `<name>` becomes the object **symbol** (assigned the next object number). The three object‑pointer fields (`loc`, `first`, `next`) point to other **object symbols**. All objects must appear **together** inside the `OBJECT` table.
- `.GVAR <name> [= <default>]`  
  Define a new **global variable** in the `GLOBAL` table with an optional default (default is 0). All globals must appear **together** in the `GLOBAL` table.

### 6.5 Functions and locals
- `.FUNCT <name> {, <local> [= <default>] ...}`  
  Begin a **function** definition, start a new local‑symbol scope, and allocate locals/args on the stack. Locals may have defaults (default is 0).

### 6.6 Flow / file control
- `.INSERT <file>` — logically insert the file’s contents at this point.  
- `.ENDI` — end the current `.INSERT` and return to the parent file.  
- `.END` — end of program; anything after is ignored.

> All definitions in §6 mirror the wording in the original ZAP manual.

---

## 7) Required global labels and program order

ZAP collects **pointers** to specific locations into a header table at the start of the program. You must define the following **global labels** at the appropriate points:

- `VOCAB::` — Vocabulary table
- `OBJECT::` — Object table
- `GLOBAL::` — Global symbol table (must have the correct length for the target ZIP version)
- `FWORDS::` — Frequently‑used word table (optional; ZAP can auto‑generate if omitted)
- `PURBOT::` — Start of **pure** (read‑only) code/data
- `ENDLOD::` — End of **preloaded** code/data
- `START::` — **First instruction** executed on game start (must point to an **instruction**, not a function)

**Suggested program layout:**

```
GLOBAL::           ; modifiable tables and impure data
   ...

PURBOT::
VOCAB::            ; pure, preloaded tables
OBJECT::
FWORDS::
   ...             ; pure code, strings, functions

ENDLOD::
   ...             ; non-preloaded tables/strings/functions

.END
```

> Source: ZAP manual, “Program Structure”.

---

## 8) Operators (instructions) — where to find them

ZAP’s **operators** are the Z‑machine opcodes, using the **same mnemonics** as listed in the **ZIP** documentation. They are organized by opcode form (`2OP`, `1OP`, `0OP`, `EXT`), addressing modes, return‑value storage, and predicate branching:

- Arithmetic: `ADD`, `SUB`, `MUL`, `DIV`, `MOD`, `RANDOM`, etc.
- Logical and comparisons: `BAND`, `BOR`, `BCOM`, `BTST`, `EQUAL?`, `ZERO?`, `LESS?`, `GRTR?` …
- Objects/props: `MOVE`, `REMOVE`, `FSET`, `FCLEAR`, `GETP`, `LOC`, `FIRST?`, `NEXT?`, `IN?` …
- Variables/stack, calls, printing, input, memory ops, control flow, etc.

**Crucial ZIP conventions that ZAP uses in source form:**

- A result is **stored** to a destination variable using the extra **store byte** — in ZAP source you write `>dest` (see §4).
- Predicates implicitly carry a conditional **branch**: `/label` (if true) or `\\label` (if false). If no branch is taken, control continues; special small offsets 0/1 mean `RFALSE`/`RTRUE`.
- Variable operands distinguish **stack** (`0`), **local 1–15**, and **global 16–255** by encoded numbers.

> See the **ZIP spec** for the full instruction set, formats, and semantics for ZIP v3–v6.

---

## 9) Worked examples

### 9.1 Globals and a simple counter

```
GLOBAL::
  .GVAR COUNTER = 0

PURBOT::
START::
  ZERO? ,COUNTER /ISZERO
  ADD ,COUNTER ,=1 >COUNTER
ISZERO:
  RTRUE

.END
```

### 9.2 Strings and FWORDS

```
FWORDS::              ; omit this table to let ZAP pre-pass build one
  .FSTR "MAGIC"
  .FSTR "SCROLL"
  .ENDT

PURBOT::
  .STR "THE MAGIC SCROLL CRACKLES."
  .STRL "HELLO"     ; emits length byte then Z-string
```

### 9.3 A tiny table and object

```
VOCAB::
  .TABLE
    .ZWORD "TAKE"
    .ZWORD "DROP"
  .ENDT

OBJECT::
  .TABLE
    .OBJECT LAMP ,=0 ,=0 ,=0 ,=0 ,=0 ,LAMP-PROPS
  .ENDT
```

*(Object flag words, property ids/sizes, and vocabulary formats must match the ZIP version in use.)*

---

## 10) Relationship to Inform assembly
Some modern tools (e.g., Inform 6) accept assembly‑like opcodes but their “assembly” syntax is **not** ZAP. Do not assume Inform’s assembly snippets are valid ZAP source; use the ZAP manual and Infocom sources as your authority.

---

## 11) Where to read the originals (recommended primary sources)

- **ZAP manual (Scribe):** `spec-zap.fwf` — *ZAP: Z‑language Assembly Program* by Joel M. Berez.  
  https://eblong.com/infocom/other/spec-zap.fwf
- **ZIP v3 manual (Runoff):** `spec-zip.rno` — *ZIP: Z‑language Interpreter Program*.  
  https://eblong.com/infocom/other/spec-zip.rno
- **EZIP v4 manual (Scribe):** `spec-ezip.fwf`.  
  https://eblong.com/infocom/other/spec-ezip.fwf
- **XZIP v5 manual (Scribe):** `spec-xzip.fwf`.  
  https://eblong.com/infocom/other/spec-xzip.fwf
- **YZIP v6 manual (text):** `spec-yzip.txt`.  
  https://eblong.com/infocom/other/spec-yzip.txt
- **Standalone ZAP sources:**  
  - `zap.mid` (MIDAS, 1982) — https://eblong.com/infocom/other/zap.mid  
  - `zap-sun.zip` (C, 1988) — https://eblong.com/infocom/other/zap-sun.zip
- **Infocom game repos with `.zap` files (real code):**  
  - *Sorcerer* — https://github.com/historicalsource/sorcerer  
  - *Checkpoint* — https://github.com/historicalsource/checkpoint
- **Context on Inform vs ZAP assembly:**  
  - Zarf (Andrew Plotkin), *What is ZIL anyway?* — https://blog.zarfhome.com/2019/04/what-is-zil-anyway

---

© This document summarizes information from the above primary sources for archival and educational use.

## Where to read the originals (verified links)

*Verified on September 27, 2025.*

- **ZAP manual:** ZAP — Z-language Assembly Program (`spec-zap.fwf`) — <https://eblong.com/infocom/other/spec-zap.fwf>
- **ZAP source (MIDAS, 1982):** `zap.mid` — <https://eblong.com/infocom/other/zap.mid>
- **ZAP source (C, 1988, “sun” directory):** `zap-sun.zip` — <https://eblong.com/infocom/sources/zap-sun.zip>  
  *Note:* This file is listed on the EBLONG catalog page; some automated fetchers may fail, but it is linked there.
- **ZIP v3 spec:** `spec-zip.rno` — <https://eblong.com/infocom/other/spec-zip.rno>
- **EZIP v4 spec:** `spec-ezip.fwf` — <https://eblong.com/infocom/other/spec-ezip.fwf>
- **XZIP v5 spec:** `spec-xzip.fwf` — <https://eblong.com/infocom/other/spec-xzip.fwf>
- **YZIP v6 spec:** `spec-yzip.txt` — <https://eblong.com/infocom/other/spec-yzip.txt>
- **ZIL course (Marc Blank, 1982):** `zil-course.fwf` — <https://eblong.com/infocom/other/zil-course.fwf>
- **The Zork Implementation Language overview:** `zil.doc` — <https://eblong.com/infocom/other/zil.doc>
- **PDP-10 ZIL/ZAP/ZIP mid-1980 sources:** <https://github.com/PDP-10/zil>
- **ZILCH resurrection notes and pointers:** <https://github.com/ZoBoRf/ZILCH-How-to>
- **Canonical Infocom ZIL game sources:**
  - *Sorcerer* — <https://github.com/historicalsource/sorcerer>
  - *Checkpoint* — <https://github.com/historicalsource/checkpoint>
