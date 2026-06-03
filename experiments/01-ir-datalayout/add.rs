#![no_std]
// no_std lib crate; wrapping_add keeps IR free of overflow-panic calls,
// so no #[panic_handler]/eh_personality is needed for --emit=llvm-ir.
#[unsafe(no_mangle)]
pub extern "C" fn add(a: i32, b: i32) -> i32 {
    a.wrapping_add(b)
}
