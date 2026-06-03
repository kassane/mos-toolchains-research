#![no_std]
use core::ops::Add;
// monomorphized generic accumulate (core only, no std/alloc)
fn sum<T: Copy + Add<Output = T> + Default>(a: &[T]) -> T {
    let mut s = T::default();
    for &x in a { s = s + x; }
    s
}
// higher-order with a generic Fn bound (static dispatch, inlined)
fn apply2<F: Fn(u16) -> u16>(f: F, x: u16) -> u16 { f(f(x)) }

#[unsafe(no_mangle)]
pub extern "C" fn rs_sum16(a: *const u16, n: u16) -> u16 {
    sum(unsafe { core::slice::from_raw_parts(a, n as usize) })
}
#[unsafe(no_mangle)]
pub extern "C" fn rs_apply(x: u16) -> u16 { apply2(|v| v.wrapping_mul(2), x) }
#[panic_handler] fn p(_: &core::panic::PanicInfo) -> ! { loop {} }
