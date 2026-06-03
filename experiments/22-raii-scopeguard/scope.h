#ifndef SCOPE_H
#define SCOPE_H
#ifdef __cplusplus
extern "C" {
#endif
/* shared trace: each language's two scope-guards call trace('1') and trace('2');
 * LIFO cleanup => the trace must read "21" for every language. */
void trace(char c);
void trace_reset(void);
const char *trace_get(void);
/* each runs a scope registering cleanup('1') then cleanup('2') */
void c_run(void);   void cpp_run(void);  void rs_run(void);
void d_run(void);   void zig_run(void);
unsigned char zig_err(unsigned char fail); /* Zig errdefer: 'X' only on error path */
void d_run_dtor(void);                      /* D struct ~this() RAII (LIFO) */
void d_run_cpp(void);                        /* D extern(C++,class) struct RAII */
#ifdef __cplusplus
}
#endif
#endif
