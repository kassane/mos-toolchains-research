module sg_d;
extern(C) void trace(char c);
// D scope(exit): runs on any scope exit, multiple guards LIFO. betterC-safe.
// NOTE: scope(success)/scope(failure) are REJECTED in betterC (need exceptions);
// only scope(exit) survives on MOS.
extern(C) void d_run(){
    scope(exit) trace('1');
    scope(exit) trace('2');
}
// D struct RAII: a struct dtor `~this()` runs at scope exit (no ctor needed --
// explicit init). The C++-compatible form is `extern(C++, class) struct`.
// Two guards destroyed LIFO, same as C++ RAII.
struct Guard { char c; ~this(){ trace(c); } }
extern(C) void d_run_dtor(){
    Guard g1 = { '1' };
    Guard g2 = { '2' };
}
// C++-compatible RAII: extern(C++, class) gives the struct a C++ class identity
// (Itanium mangling _ZN..). It has no D this() ctor, so init explicitly; a
// `void init(typeof(null)){}` member is allowed, and ~this() still runs (LIFO).
extern(C++, class) struct CxxGuard {
    char c;
    void init(typeof(null)){ trace('+'); }   // useful: the ACQUIRE half of RAII
    ~this(){ trace(c); }                       // the RELEASE half
}
extern(C) void d_run_cpp(){
    CxxGuard g1 = { '1' }; g1.init(null);      // acquire -> '+'
    CxxGuard g2 = { '2' }; g2.init(null);      // acquire -> '+'
    // scope exit: g2 then g1 released (LIFO) -> trace "++21"
}
