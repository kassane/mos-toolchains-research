module add;
// -betterC: no druntime; extern(C) gives the platform C ABI.
extern(C) int add(int a, int b) { return a + b; }
