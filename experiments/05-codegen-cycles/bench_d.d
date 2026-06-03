module bench_d;
extern(C) ushort d_lcg(ushort n){ ushort s=0; for(ushort i=0;i<n;i++) s=cast(ushort)(s*31+i); return s; }
