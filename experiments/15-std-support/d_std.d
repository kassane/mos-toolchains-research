module d_std;
import core.stdc.string : memset, strlen;   // works in betterC on MOS
import ldc.intrinsics : llvm_ctlz;          // LDC-exclusive LLVM intrinsic
extern(C) ushort d_std(){
    char[16] b;
    memset(b.ptr, 'Z', 15); b[15] = 0;
    ushort n = cast(ushort) strlen(b.ptr);             // 15
    ushort lz = llvm_ctlz!ushort(1, false);            // ctlz(1)=15 on 16-bit
    return cast(ushort)(n * 100 + lz);                 // 1515
}
