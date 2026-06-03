module embed_d;
extern(C) ushort d_sum(){
    static immutable ubyte[] D = cast(immutable(ubyte)[]) import("payload.bin");
    ushort s=0; foreach(b; D) s+=b; return s;
}
