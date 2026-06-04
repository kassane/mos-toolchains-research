# 09 — Template metaprogramming / compile-time parity (exp 10)

Can each language do its compile-time work *on the 6502 toolchain*, and is it a
language **guarantee** or merely an optimizer fold? Experiment: `factorial(10)`
(= 3628800 = 0x375F00, needs `u32`) via C++ `constexpr`/`consteval`, D CTFE,
Rust `const fn`, with a plain C runtime loop as the control.

## CTFE is a language guarantee, not an optimization

```
              -Os                     -O0
c_fact10      CONST-FOLDED            runtime  (255 instrs, 11 branches)  <- C: optimizer only
cpp_fact10    CONST-FOLDED            CONST-FOLDED  (constexpr)
cpp_fact10_ce CONST-FOLDED            CONST-FOLDED  (consteval, immediate fn)
d_fact10      CONST-FOLDED            CONST-FOLDED  (CTFE via enum)
rs_fact10     CONST-FOLDED            CONST-FOLDED  (const fn)
```

At `-Os` everyone folds (LLVM evaluates the known-bound C loop too). The
distinction shows at **`-O0`**: C's loop stays a 255-instruction runtime loop,
while C++/D/Rust still fold to a ~6-instruction constant load — because their
compile-time eval is enforced by the *language* (`static_assert` / `enum` /
`const`), independent of the optimizer. All four return 3628800 on `mos-sim`.

The folded form is just the constant in immediates (no loop, no `jsr`):

```asm
lda #$0 ; ldx #$5f ; ldy #$37 ; …    ; 0x00375F00 little-endian, then rts
```

## The idioms (freestanding-safe)

| | force compile-time eval | loop form | notes |
|--|--|--|--|
| C++ | `constexpr` in const ctx; **`consteval`** always (immediate fn, ~ Zig `comptime`) | normal `for`/`while` | `-std=c++20`, freestanding `<cstdint>` |
| D | `enum X = f(…)` / `immutable` / template arg | normal loops, `static foreach` | CTFE = compiler interpreter; works in `-betterC` |
| Rust | `const X = f(…)` / array length / generic arg | `while`/`loop` **(not `for`-range — Iterator isn't const)** | `const fn`, `no_std`/`core` |

`consteval` is the strict analogue of Zig's `comptime`: it *cannot* be evaluated
at runtime. `constexpr`/D-CTFE/`const fn` *may* run at runtime in a non-const
context but are forced compile-time in a const context. (C++20 `constinit` is
related but distinct — it *guarantees constant-initialization* of a static/global
rather than computing a value; it too compiles for MOS — `__cpp_consteval` and
`__cpp_constinit` are both defined under the SDK clang, `-std=c++20`/`c++2c`.)

## Feature-surface parity (where they diverge)

| capability | C++ (clang 23) | D (LDC, -betterC) | Rust (no_std) |
|---|:--:|:--:|:--:|
| compile-time fn eval | ✅ constexpr/consteval | ✅ CTFE | ✅ const fn |
| compile-time loops | ✅ | ✅ (+`static foreach`) | ✅ `while`/`loop` |
| value/type generics | ✅ NTTP + templates + partial spec | ✅ value params + `static if` | ⚠️ const generics only |
| **introspection/reflection** | ⚠️ `type_traits`/`if constexpr`/concepts (full reflection only C++26) | ✅ **`__traits`/`is()`/`static if/foreach`** | ❌ none at compile time |
| float at compile time | ✅ | ✅ | ✅ (const fn, since Rust 1.82) |
| heap at compile time | ❌ | ❌ (escaping) | ❌ |

They **converge on computation** (all fold the factorial identically) but
**diverge on introspection**: D is strongest (design-by-introspection via
`__traits`/`static foreach`), C++ is middle (`if constexpr`/concepts; reflection
deferred to C++26), Rust is weakest (const generics give value-genericity but no
compile-time reflection). All of it is freestanding-safe — CTFE needs no runtime,
so `-betterC`/`no_std`/freestanding don't restrict the *computation*, only the
data types it may use (no heap at compile time).
