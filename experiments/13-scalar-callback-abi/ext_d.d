module ext_d;
extern(C):
alias cb_t = ushort function(ushort);
ulong  d_addq(ulong a, ulong b){ return a + b; }
short  d_neg(short x){ return cast(short)-x; }
ushort d_apply(cb_t f, ushort x){ return cast(ushort)(f(x) + 1); }
