module sqrt_d; import core.math;
extern(C) int d_sqrt_x100(ushort n){ return cast(int)(sqrt(cast(float)n) * 100.0f); }
