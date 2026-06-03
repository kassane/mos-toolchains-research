module bv_d;
extern(C):
struct Small { ubyte a, b; }
struct Big   { ushort a, b, c, d; }
ushort d_small(Small p){ return cast(ushort)(p.a + p.b); }
Big d_mkbig(ushort base){ return Big(base, cast(ushort)(base+1), cast(ushort)(base+2), cast(ushort)(base+3)); }
