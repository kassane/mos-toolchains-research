#![no_std]
use core::ffi::c_int;
use core::mem::{size_of, align_of};
// const assertions: compile fails if any fact is wrong.
const _: () = assert!(size_of::<c_int>() == 2);   // Rust c_int=16-bit, matches C
const _: () = assert!(size_of::<usize>() == 2);   // usize matches pointer
const _: () = assert!(size_of::<i32>() == 4);
const _: () = assert!(align_of::<i32>() == 1);    // mos: byte-aligned
const _: () = assert!(size_of::<*const u8>() == 2);
#[unsafe(no_mangle)] pub extern "C" fn ct_rs_ok() -> i32 { 0 }
#[panic_handler] fn p(_: &core::panic::PanicInfo)->!{loop{}}
