module tmp_d;
uint fact(uint n){ return n<2 ? 1u : n*fact(n-1); }
enum uint F10 = fact(10);                 // enum forces CTFE
static assert(F10 == 3628800u);
extern(C) uint d_fact10(){ return F10; }  // returns the CTFE constant
