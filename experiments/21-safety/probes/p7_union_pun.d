module m; union U { int* p; size_t n; } @safe size_t f(int* x){ U u; u.p = x; return u.n; }
