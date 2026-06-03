module lib_d;
// -betterC: C ABI via extern(C). ushort == uint16_t (fixed width, safe across FFI).
extern(C) ushort rs_sub16(ushort a, ushort b);     // implemented in Rust

extern(C) ushort d_xor16(ushort a, ushort b) {
    // D -> Rust cross-call. rs_sub16(a,b) == a-b, but LDC sees it as opaque,
    // so the call can't be folded away; (r - (a-b)) == 0 keeps result == a^b.
    ushort r = rs_sub16(a, b);
    ushort x = cast(ushort)(a ^ b);
    return cast(ushort)(x + r - cast(ushort)(a - b));
}
