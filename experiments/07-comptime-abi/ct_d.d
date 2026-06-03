module ct_d;
// Same keyword 'int' as C, but D mandates 32-bit -> proves the FFI footgun
// at COMPILE time (this file and ct_c.c assert DIFFERENT sizes, both true).
static assert(int.sizeof    == 4, "D int is 32-bit (NOT C's 16-bit)");
static assert(long.sizeof   == 8, "D long is 64-bit (NOT C's 32-bit)");
static assert((void*).sizeof == 2, "mos pointer is 16-bit");
static assert(size_t.sizeof == 2, "LDC 1.42: size_t fixed to pointer width");
static assert(int.alignof   == 1, "mos: byte-aligned");
extern(C) int ct_d_ok(){ return 0; }
