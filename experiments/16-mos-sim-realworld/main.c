#include <stdio.h>
#include <stdint.h>
extern uint8_t up(uint8_t);                      /* Zig transform (FFI)      */
static volatile uint32_t *const CYC = (volatile uint32_t *)0xFFF0;
int main(void){
    /* real I/O: read stdin char-by-char, uppercase via Zig, write stdout,
       until EOF -- exactly the mos-sim MMIO model ($FFF5 in, $FFF9 out). */
    uint16_t nchars = 0;
    *CYC = 0;                                    /* reset cycle counter      */
    for (;;) {
        int ch = getchar();
        if (ch == EOF) break;
        putchar(up((uint8_t)ch));
        nchars++;
    }
    uint32_t cycles = *CYC;
    printf("\n[processed %u chars in %lu cycles]\n", nchars, (unsigned long)cycles);
    return 0;
}
