extern float sqrtf(float);   /* SDK <math.h> declares no sqrtf; provided by the Rust libm crate */
int c_sqrt_x100(unsigned short n){ return (int)(sqrtf((float)n) * 100.0f); }
