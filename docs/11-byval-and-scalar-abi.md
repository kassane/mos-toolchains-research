# 11 — By-value struct & extended scalar ABI (exp 12, 13)

docs/03 showed scalars/pointers/callbacks share the ABI. Here we stress the
*aggregate* and *wide-scalar* corners that the FFI matrix didn't, and find the
one genuine call-ABI hole.

## By-value structs split into two camps (exp 12)

Passing a struct **by value** (not by pointer). The MOS C ABI says aggregates
≤4 bytes are **decomposed into scalar registers**; >4 bytes go via a hidden
pointer (sret). The frontends do **not** agree on the ≤4-byte rule:

```
small(40,2)->42   big sum->46         small-struct ABI
C    42   46   decompose OK
C++  42   46   decompose OK
Zig  42   46   decompose OK
Rust 42   46   now-matches(!)          <- callconv fix (was 66, indirect)
D   215   46   DIVERGES (indirect)     <- reads garbage (LDC still indirect)
```

The IR shows exactly why — same 2-byte `struct Small{u8,u8}`:

| frontend | parameter lowering | effect |
|--|--|--|
| clang | `@c_small(i8, i8)` | decomposed → A,X (official MOS C ABI) |
| Zig | `@zig_small(%Small)` | first-class aggregate → backend decomposes → A,X |
| LDC | `@d_small(ptr byval(%Small))` | **indirect** — expects a pointer |
| Rust | now **decomposed → A,X** (callconv fix 2026-06; was `ptr` indirect) | matches the MOS C ABI |

A C caller decomposes into registers; **D (LDC)** still reads those register bytes as
a *pointer* and dereferences garbage (Rust used to as well — its callconv was fixed
in the 2026-06-04 rust-mos rebuild). So **by-value structs ≤4 bytes are not FFI-safe
between {C,C++,Zig,Rust} and {D}** on MOS. The **>4-byte path agrees** (everyone
uses an sret/byref pointer — `define void @c_mkbig(ptr ... sret(...))`), which is
why `Big` round-trips for all five.

**Fix:** never pass small structs by value across the boundary — pass by pointer
(every frontend agrees; exp 02/08) or keep aggregates >4 bytes. This is the MOS
instance of the classic "by-value struct argument" FFI hole.

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

The shared C ABI covers scalars of every width, pointers, and callbacks. The
**only** call-level hole is **by-value structs ≤4 bytes** (a frontend lowering
disagreement, not a backend issue). Combined with the *type-width* footguns
(docs/05), the FFI rulebook is: fixed-width scalars, and aggregates only by
pointer.
