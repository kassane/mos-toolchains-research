module zc_d;
private T sum(T)(const(T)* a, ushort n){ T s=0; for(ushort i=0;i<n;i++) s+=a[i]; return s; }
private ushort apply2(F)(scope F f, ushort x){ return f(f(x)); }  // template HOF
extern(C) ushort d_sum16(const(ushort)* a, ushort n){ return sum!ushort(a, n); }
extern(C) ushort d_apply(ushort x){ return apply2((ushort v)=>cast(ushort)(v*2), x); }
