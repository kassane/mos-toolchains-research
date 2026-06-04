#include <cstdint>
// C++ kernels — extern "C", identical algorithm/types to bench_c.c.
extern "C" uint16_t cpp_sieve(uint8_t *flags) {
    uint16_t i, k, count = 0;
    for (i = 0; i <= 8190; i++) flags[i] = 1;
    for (i = 0; i <= 8190; i++) if (flags[i]) {
        uint16_t p = (uint16_t)(i + i + 3);
        for (k = (uint16_t)(i + p); k <= 8190; k = (uint16_t)(k + p)) flags[k] = 0;
        count++;
    }
    return count;
}
extern "C" uint16_t cpp_fib(uint16_t n) {
    return n < 2 ? n : (uint16_t)(cpp_fib((uint16_t)(n - 1)) + cpp_fib((uint16_t)(n - 2)));
}
extern "C" uint16_t cpp_crc16(uint8_t *buf, uint16_t len) {
    uint16_t crc = 0, i, j;
    for (i = 0; i < len; i++) {
        crc = (uint16_t)(crc ^ (uint16_t)((uint16_t)buf[i] << 8));
        for (j = 0; j < 8; j++)
            crc = (crc & 0x8000) ? (uint16_t)((uint16_t)(crc << 1) ^ 0x1021)
                                 : (uint16_t)(crc << 1);
    }
    return crc;
}
