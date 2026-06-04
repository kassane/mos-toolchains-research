# 14 — Compile-time data: file embedding & reflection (exp 18, 19)

Two compile-time capabilities the languages were *not* compared on before: baking
a file into the binary, and introspecting a type. Both are pure compile-time, so
they cost nothing at runtime and are unconstrained by the freestanding target —
the limits are purely what each language offers.

## File embedding — 6 ways, identical bytes (exp 18)

The same 113-byte `payload.bin` (sum **9231**) embedded six ways; each
exposes a byte-sum, all run in one 6502 binary on `mos-sim` (which has **no
filesystem**, so a correct sum *proves* the bytes were embedded at compile time):

| method | language | flag needed | produced shape |
|--------|----------|-------------|----------------|
| `#embed "f"` | C23 | dialect (clean in `c23`/`gnu23`) | integer-list in `{…}` initializer |
| `#embed "f"` | C++ | `-std=c++2c` (Clang extension; standard in C++26) | same |
| `include_bytes!("f")` | Rust | — (core macro, no_std) | `&'static [u8; N]` |
| `import("f")` | D | **`-J<dir>`** (string-import path) | compile-time `string` → `cast(immutable(ubyte)[])` |
| `@embedFile("f")` | Zig | — (relative to source, in package) | `*const [N:0]u8` (sentinel **not** in `N`) |
| `.incbin "f"` | asm-inline | `-I<dir>` resolves the file | a `.globl` label + `.set size` |

All six return **9231**. Notes:
- **`#embed` dialects:** clang 23 accepts it everywhere; warning-free in the
  C23-era dialects (`c23`/`gnu23`/`c2x`/`gnu2x`), but warns `c23-extensions` in
  `c17`/default. `__has_embed`, `limit()`/`prefix()`/`suffix()`/`if_empty()` and
  the vendor `clang::offset()` are supported. C++ `#embed` is a *Clang extension*
  (P1967, standard only in C++26).
- **The asm-inline `.incbin`** route works in any frontend with inline asm
  (C/C++/D/Zig; Rust used `include_bytes!` instead — its inline asm was unsupported
  then, rust-mos#13, now fixed). It is the
  classic pre-`#embed` technique — and the **SDK itself uses the same idea**: the
  NES mapper headers configure cartridge hardware at compile time with
  `MAPPER_USE_4_SCREEN_NAMETABLE` ≡ `asm(".globl __mirroring\n__mirroring = 1\n…")`,
  injecting linker symbols the platform link-script consumes.
- At `-Os` the byte-sum even **const-folds to 9231** — embedding composes with CTFE.

## Reflection — only D and Zig can introspect (exp 19)

Compile-time reflection of `struct S { u8 a; u32 b; u16 c; }` — enumerate fields,
sum their sizes, and read field *names* — across the five languages:

```
lang  fields  sizesum  namesum  capability
D        3       7      294     enumerate fields + names (__traits/.tupleof)
Zig      3       7      294     enumerate fields + names (@typeInfo/inline for)
C        -       7        -     sizeof only (no reflection)
C++      -       7        -     type_traits only (P2996 = C++26, not in clang 23)
Rust     -       7        -     size_of only (reflection = build-time proc-macro)
```

(`namesum` = `'a'+'b'+'c' = 294`, proving D/Zig read field names; `sizesum` =
1+4+2 = 7 = whole `sizeof` here because MOS is byte-packed, docs/05.) NB: zig-mos's
`@typeInfo` Struct API changed in the 0.17-dev line — fields are now parallel
`field_names`/`field_types` arrays (and `Type` moved to `std.lang`), not the older
`.fields` list; exp 19's Zig source tracks the current shape.

| capability | C | C++ (clang 23) | **D** (-betterC) | Rust (no_std) | **Zig** |
|---|:--:|:--:|:--:|:--:|:--:|
| size/align of a type | ✅ | ✅ | ✅ | ✅ | ✅ |
| enumerate fields / names | ❌ | ❌ | ✅ `__traits`/`.tupleof` | ❌ | ✅ `@typeInfo` |
| access field by computed name | ❌ | ❌ | ✅ `getMember` | ❌ | ✅ `@field` |
| iterate members (unrolled) | ❌ | ❌ | ✅ `static foreach` | ❌ | ✅ `inline for` |
| general static reflection | ❌ | ❌ (P2996 → C++26) | ✅ | ❌ (proc-macro at build) | ✅ |

**D and Zig have real compile-time reflection** ("design by introspection" /
comptime). **C++ has type *predicates* only** — full static reflection (P2996,
the `^^` operator / `std::meta`) is C++26 and **not in mainline clang 23** (only
the Bloomberg `clang-p2996` fork). **Rust** has none in-language (reflection is a
build-time `#[derive]` proc-macro); **C** has only `_Generic` dispatch. All of it
is freestanding-safe because it's compile-time — the gap is the *language*, not
the 6502 target.
