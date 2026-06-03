module tmp_d;
uint fact(uint n){ return n<2 ? 1u : n*fact(n-1); }
static assert(fact(10) == 3628800u);              // compile-time proof (CTFE)
// local `enum` forces CTFE and folds to a constant, without a module-level
// @system global (which -preview=safer, part of -preview=all, would reject).
extern(C) uint d_fact10(){ enum uint v = fact(10); return v; }
