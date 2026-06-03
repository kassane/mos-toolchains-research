#include <stdio.h>
#include "refl.h"
int main(void){
    printf("compile-time reflection of struct S { u8 a; u32 b; u16 c; }\n");
    printf("lang  fields  sizesum  namesum  capability\n");
    int bad=0;
    /* D & Zig: real field reflection -> fields=3, sizesum=7, namesum='a'+'b'+'c'=294 */
    uint16_t df=d_fields(), ds=d_sizesum(), dn=d_namesum();
    uint16_t zf=zig_fields(), zs=zig_sizesum(), zn=zig_namesum();
    printf("D     %4u   %5u    %5u    enumerate fields + names (__traits/.tupleof)\n", df, ds, dn);
    printf("Zig   %4u   %5u    %5u    enumerate fields + names (@typeInfo/inline for)\n", zf, zs, zn);
    if(!(df==3 && ds==7 && dn==294)) { printf("  D reflection WRONG\n"); bad++; }
    if(!(zf==3 && zs==7 && zn==294)) { printf("  Zig reflection WRONG\n"); bad++; }
    if(df!=zf || ds!=zs || dn!=zn)   { printf("  D and Zig DISAGREE\n"); bad++; }
    /* C/C++/Rust: only whole-struct sizeof (7 on byte-packed MOS); no field enum */
    uint16_t cs=c_sizeof(), ps=cpp_sizeof(), rs=rs_sizeof();
    printf("C     %4s   %5u    %5s    sizeof only (no reflection)\n", "-", cs, "-");
    printf("C++   %4s   %5u    %5s    type_traits only (P2996 = C++26, not clang23)\n", "-", ps, "-");
    printf("Rust  %4s   %5u    %5s    size_of only (reflection = build-time proc-macro)\n", "-", rs, "-");
    if(!(cs==7 && ps==7 && rs==7)) { printf("  sizeof disagreement\n"); bad++; }
    printf("== %d issue(s) (0 = D/Zig reflect correctly, C/C++/Rust sizeof agrees) ==\n", bad);
    return bad;
}
