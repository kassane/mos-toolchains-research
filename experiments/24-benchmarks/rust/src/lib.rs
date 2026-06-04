#![no_std]
// Rust kernels (no_std). Raw pointers (no slice bounds checks -> no panic
// Location codegen) and wrapping arithmetic. Identical algorithm/types (u16).
#[unsafe(no_mangle)]
pub extern "C" fn rs_sieve(flags: *mut u8) -> u16 {
    let mut count: u16 = 0;
    unsafe {
        let mut i: u16 = 0;
        while i <= 8190 { *flags.add(i as usize) = 1; i = i.wrapping_add(1); }
        i = 0;
        while i <= 8190 {
            if *flags.add(i as usize) != 0 {
                let p: u16 = i.wrapping_add(i).wrapping_add(3);
                let mut k: u16 = i.wrapping_add(p);
                while k <= 8190 { *flags.add(k as usize) = 0; k = k.wrapping_add(p); }
                count = count.wrapping_add(1);
            }
            i = i.wrapping_add(1);
        }
    }
    count
}
#[unsafe(no_mangle)]
pub extern "C" fn rs_fib(n: u16) -> u16 {
    if n < 2 { n } else { rs_fib(n - 1).wrapping_add(rs_fib(n - 2)) }
}
#[unsafe(no_mangle)]
pub extern "C" fn rs_crc16(buf: *const u8, len: u16) -> u16 {
    let mut crc: u16 = 0;
    unsafe {
        let mut i: u16 = 0;
        while i < len {
            crc ^= (*buf.add(i as usize) as u16) << 8;
            let mut j: u8 = 0;
            while j < 8 {
                crc = if crc & 0x8000 != 0 { (crc << 1) ^ 0x1021 } else { crc << 1 };
                j += 1;
            }
            i = i.wrapping_add(1);
        }
    }
    crc
}
#[panic_handler] fn ph(_: &core::panic::PanicInfo) -> ! { loop {} }
