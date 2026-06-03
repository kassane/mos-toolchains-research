module sizes_d;
// D's native type widths. D mandates int==32-bit, long==64-bit ALWAYS,
// regardless of target -- so they do NOT match C's mos `int`(16)/`long`(32).
extern(C) ubyte d_int_bytes()   { return int.sizeof; }     // == 4
extern(C) ubyte d_long_bytes()  { return long.sizeof; }    // == 8
extern(C) ubyte d_sizet_bytes() { return size_t.sizeof; }  // LDC: 4 (pointer is 2!)
extern(C) ubyte d_ptr_bytes()   { return (void*).sizeof; } // == 2
