# 08 — Zero-cost abstractions (exp 09)

Stroustrup's test — "what you don't use you don't pay for; what you do use you
couldn't hand-code better" — applied to the 6502. Same two abstractions in
C++/D/Rust vs a hand-written C baseline, compiled `-Os`/`-Oz`, compared by
**per-symbol 6502 instruction count** and run on `mos-sim`.

## Scenarios

- `*_sum16` — accumulate a `u16` array via a **monomorphized generic**
  (C++ `template`, D `template`, Rust generic `fn` with trait bounds) vs C's loop.
- `*_apply` — a **higher-order function** applying a non-capturing doubling
  callable twice (C++ lambda, D lambda, Rust closure) vs C's static call.

All are freestanding: D `-betterC` (templated `struct`/free functions, no
classes/GC), Rust `no_std` (`core` generics + `Fn` bound, no `alloc`), C++
`-fno-exceptions -fno-rtti` (no libstdc++).

## Result

```
              sum16   apply
C (baseline)   39      7
C++            39      7      <- template sum byte-identical to C; lambda inlined
D              34      5
Rust           55      7
```

(All return the correct values on `mos-sim`: `sum=36`, `apply(5)=20`, exit 0.)

- **C++ `sum<u16>` is byte-identical to the hand-written C loop** (39 = 39): the
  template monomorphizes to exactly the C code. Textbook zero-cost.
- **The higher-order call collapses to nothing**: `apply` is 5–7 instructions
  everywhere — the lambda/closure is fully inlined; there is **no indirect call,
  no closure object** in the output. Static dispatch on the 6502 is free.
- **D is leanest here** (34/5) — `-betterC` templates + `=>` lambda inline tightly.
- **Rust's generic slice-sum is heavier** (55): the `&[T]` slice + iterator-style
  bounds produce more setup than the raw-pointer C loop, but still **monomorphized,
  no dynamic dispatch**. The overhead is slice plumbing, not the abstraction.

## What to avoid (would NOT be zero-cost)

- **Dynamic dispatch**: C++ `virtual`, Rust `dyn Trait`, D classes (the last are
  *unavailable* in `-betterC` anyway). A vtable indirect call on the 6502 is a
  real cost and the optimizer often can't devirtualize through it (llvm-mos#249).
  Prefer generics / `Fn` bounds / templates for static dispatch.
- **Heap-backed abstractions** (`Box`, `std::function`, D `class` on an allocator):
  not zero-cost and mostly unavailable freestanding.

## Takeaway

For the statically-monomorphizing forms — templates/generics and non-capturing
callables — the abstraction is genuinely free on the 6502: C++ ties the C
baseline exactly, and the higher-order call inlines away in every language. The
only "cost" seen is Rust's slice/iterator scaffolding, not dispatch overhead.
(Compare exp 05, where the *same explicit loop* still differs across frontends —
so "zero-cost vs C" is a per-abstraction property, not a blanket guarantee.)

## RAII & scope guards — zero-cost deterministic cleanup (exp 22)

Another zero-cost abstraction: scope-bound cleanup. Each language registers two
cleanups (`trace('1')` then `trace('2')`); LIFO ⇒ the trace reads `"21"`, run on
`mos-sim`:

| C | C++ | Rust | D | Zig |
|---|-----|------|---|-----|
| `__attribute__((cleanup))` | `~Guard()` | `Drop` | `scope(exit)` / `~this()` | `defer` |

All five fire in reverse order at scope exit. **Zero-cost:** the cleanups lower
to direct calls at scope end (inlinable), with **no `.eh_frame`/unwind sections**
— and MOS has no CFI/unwinding (docs/10), so the exceptional path doesn't exist;
only normal-path RAII, which is free.

Error-path cleanup diverges: **Zig `errdefer`** runs only on an error return
(`errdefer comptime unreachable;` asserts no fallible op follows); **Rust** has no
`defer`/`errdefer` (it uses `?`+`Result`+`Drop`); and **D `scope(success)`/
`scope(failure)` are rejected in `-betterC`** (`cannot be used with
-fno-exceptions`), leaving only `scope(exit)`. D extras (all betterC on MOS):
`extern(C++, class)` struct RAII (C++ Itanium mangling; `init(typeof(null))` as
the *acquire* half + `~this()` *release* → `"++21"`), `alias this` subtyping
(structs have no inheritance), and move-semantics `@disable this(this)`
(non-copyable) / `@disable this()` (no default ctor) — ownership-safe guards.
