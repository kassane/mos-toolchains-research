#![no_std]
#[panic_handler] fn ph(_: &core::panic::PanicInfo) -> ! { loop {} }
// (1) Export libm's pure-Rust software math as the C symbols the SDK libm lacks. This
//     single crate becomes the shared `sqrtf`/`sqrt` provider that lets C/D/Zig sqrt LINK.
#[unsafe(no_mangle)] pub extern "C" fn sqrtf(x: f32) -> f32 { libm::sqrtf(x) }
#[unsafe(no_mangle)] pub extern "C" fn sqrt(x: f64) -> f64 { libm::sqrt(x) }
// (2) Rust's own sqrt path uses libm directly (no external symbol). n=2 -> 141.
#[unsafe(no_mangle)]
pub extern "C" fn rs_sqrt_x100(n: u16) -> i32 {
    unsafe { (libm::sqrtf(n as f32) * 100.0).to_int_unchecked() }
}
