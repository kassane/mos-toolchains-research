module refl_d;
extern(C):
struct S { ubyte a; uint b; ushort c; }
// .tupleof / __traits = D's "design by introspection", all compile-time, betterC-safe
ushort d_fields(){ return cast(ushort) S.tupleof.length; }                         // 3
ushort d_sizesum(){ size_t t=0; static foreach(F; typeof(S.tupleof)) t+=F.sizeof; return cast(ushort)t; } // 7
ushort d_namesum(){ ushort s=0; static foreach(m; __traits(allMembers,S)) s+=m[0]; return s; }           // 'a'+'b'+'c'
