#ifndef IMC_H
#define IMC_H
struct P { int a; int b; };
int add(int a, int b);
int psum(struct P p);                 /* by-value struct across the ImportC boundary */
unsigned char isz(void);              /* sizeof(int) on MOS — must be 2 (16-bit) */
#endif
