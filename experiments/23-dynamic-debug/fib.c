// Dynamic-debug demo source: a recursive fib so the profiler has a clear hot
// spot. Built with -g; the linked ELF keeps DWARF line tables (exp 11 proved
// they're emitted). This experiment proves they're also USABLE: mos-sim's
// per-PC --profile / --trace output round-trips back to these source lines via
// llvm-symbolizer. fib(12) = 144, so the sim exit code is 144 & 0xFF = 144.
#include <stdint.h>

static uint16_t fib(uint16_t n) {
    return n < 2 ? n : (uint16_t)(fib(n - 1) + fib(n - 2));
}

int main(void) {
    volatile uint16_t r = fib(12);
    return (int)(r & 0xFF);
}
