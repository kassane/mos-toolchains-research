module step_d;
extern(C) ushort d_step(ushort x) { return cast(ushort)(x ^ 0x00FF); }
