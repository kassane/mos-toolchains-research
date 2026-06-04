# 11 — By-value struct & extended scalar ABI (exp 12, 13)

docs/03 showed scalars/pointers/callbacks share the ABI. Here we stress the
*aggregate* and *wide-scalar* corners that the FFI matrix didn't — the place that
used to be the one genuine call-ABI hole, **now closed**.

## By-value structs ≤4 bytes: all five now agree (exp 12)

Passing a struct **by value** (not by pointer). The MOS C ABI says aggregates
≤4 bytes are **decomposed into scalar registers**; >4 bytes go via a hidden
pointer (sret). This used to be the FFI matrix's one disagreement — and it took
*two separate toolchain rebuilds* to close it. As of the current builds **all five
decompose identically** (C driver calls each language's `small`, verified on
`mos-sim`):

```
small(40,2)->42   big sum->46         small-struct ABI
C    42   46   decompose OK
C++  42   46   decompose OK
Zig  42   46   decompose OK
Rust 42   46   now-matches(!)          <- callconv fix (rust-mos rebuild; was 66, indirect)
D    42   46   now-matches(!)          <- callconv fix (LDC rebuild; was 215, indirect)
```

The IR shows exactly why — same 2-byte `struct Small{u8,u8}`:

| frontend | parameter lowering | effect |
|--|--|--|
| clang | `@c_small(i8, i8)` | decomposed → A,X (official MOS C ABI) |
| Zig | `@zig_small(%Small)` | first-class aggregate → backend decomposes → A,X |
| Rust | decomposed → A,X (callconv fix; was `ptr` indirect) | matches the MOS C ABI |
| LDC | `@d_small(%Small)` (was `ptr byval(%Small)`) | now first-class aggregate → backend decomposes → A,X |

Both holdouts have been fixed in their rebuilds: **Rust**'s callconv first, then
**D (LDC)** — the updated LDC drops the `byval` indirection and passes `Small` as a
first-class aggregate (no `byval` anywhere in the IR), so the backend decomposes it
to A,X exactly like clang. A C caller and a D callee now agree; the historical
"D reads the register bytes as a pointer and dereferences garbage" (→ `215`) is gone.
The **>4-byte path always agreed** (everyone uses an sret/byref pointer —
`define void @c_mkbig(ptr ... sret(...))`), which is why `Big` round-tripped for all
five all along.

**Caveat:** small by-value structs now round-trip across all five, but this corner
was broken until very recently and there is **no ABI-stability promise** (docs/07,
llvm-mos#229) — so passing aggregates **by pointer** remains the version-independent
conservative choice (every frontend has always agreed on that; exp 02/08).

## Wide scalars & callbacks are fully shared (exp 13)

In contrast, the non-aggregate corners all agree across **all five** languages
(verified on `mos-sim`):

```
lang  addq(u64)  neg(i16)  apply(cb)
C/C++/Rust/D/Zig   ok       1234       31      PASS
```

- **64-bit integers** (`u64`/`ulong`): `a+b` round-trips correctly — the 8-byte
  value is passed/returned byte-wise across the register file, identically.
- **Signed / negative**: `neg(-1234)==1234` — sign handling agrees.
- **Function-pointer callbacks**: a C `uint16_t(*)(uint16_t)` passed into each
  language and *called* returns the right value — the 16-bit code-pointer call
  ABI is shared (though the optimizer can't see through it, llvm-mos#249).

## Net

The shared C ABI covers scalars of every width, pointers, and callbacks — and now
**by-value structs ≤4 bytes too** (the last call-level disagreement, closed by the
Rust and LDC callconv rebuilds; it was always a frontend lowering issue, not a
backend one). What remains are the *type-width* footguns (docs/05). So the FFI
rulebook is now just: fixed-width scalars — and, conservatively, aggregates by
pointer (no longer a correctness requirement on current builds, but version-proof).
