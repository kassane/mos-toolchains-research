#include <stdio.h>
#include "scope.h"
static char TRACE[8]; static unsigned char TN;
void trace(char c){ if(TN<7) TRACE[TN++]=c; }
void trace_reset(void){ TN=0; TRACE[0]=0; }
const char *trace_get(void){ TRACE[TN]=0; return TRACE; }
int main(void){
    printf("scope-guard / RAII cleanup order (must be LIFO -> \"21\")\n");
    struct { const char *n, *how; void (*run)(void); } t[] = {
        {"C",   "__attribute__((cleanup))", c_run},
        {"C++", "~Guard() (RAII)",          cpp_run},
        {"Rust","Drop",                     rs_run},
        {"D",   "scope(exit)",              d_run},
        {"Zig", "defer",                    zig_run},
    };
    int bad=0;
    for(int i=0;i<5;i++){
        trace_reset(); t[i].run(); const char *tr = trace_get();
        int ok = (tr[0]=='2' && tr[1]=='1' && tr[2]==0);
        printf("  %-5s %-26s trace=\"%s\" %s\n", t[i].n, t[i].how, tr, ok?"LIFO OK":"FAIL");
        if(!ok) bad++;
    }
    /* D struct destructor (~this) RAII -- LIFO, same as C++ */
    trace_reset(); d_run_dtor(); const char *dd = trace_get();
    int dok = (dd[0]=='2' && dd[1]=='1' && dd[2]==0);
    printf("  %-5s %-26s trace=\"%s\" %s\n", "D", "~this() struct RAII", dd, dok?"LIFO OK":"FAIL");
    if(!dok) bad++;
    /* extern(C++,class): init(null) is the ACQUIRE half ('+'), ~this the RELEASE.
       Two acquires then LIFO releases -> "++21". */
    trace_reset(); d_run_cpp(); const char *dc = trace_get();
    int cok = (dc[0]=='+' && dc[1]=='+' && dc[2]=='2' && dc[3]=='1' && dc[4]==0);
    printf("  %-5s %-26s trace=\"%s\" %s\n", "D", "extern(C++,class)+init", dc,
           cok?"acquire+release OK":"FAIL");
    if(!cok) bad++;

    /* Zig errdefer: fires ONLY on the error path. Copy te before the 2nd reset
       (trace_get aliases one static buffer). */
    char te[8]; trace_reset(); zig_err(1); { const char *s=trace_get(); int k=0; while(s[k]&&k<7){te[k]=s[k];k++;} te[k]=0; }
    trace_reset(); zig_err(0); const char *ts = trace_get();
    int eok = (te[0]=='X' && te[1]==0 && ts[0]==0);
    printf("  %-5s %-26s err=\"%s\" ok=\"%s\" %s\n", "Zig", "errdefer", te, ts,
           eok?"fires only on error":"FAIL");
    if(!eok) bad++;

    printf("== %d scope-guard failure(s) (0 = all mechanisms fire as documented) ==\n", bad);
    return bad;
}
