#![no_std]
use core::ffi::c_int;
use core::mem::size_of;
#[unsafe(no_mangle)] pub extern "C" fn rs_cint_bytes()  -> u8 { size_of::<c_int>() as u8 }  // 2
#[unsafe(no_mangle)] pub extern "C" fn rs_usize_bytes() -> u8 { size_of::<usize>() as u8 }  // 2
#[unsafe(no_mangle)] pub extern "C" fn rs_i32_bytes()   -> u8 { size_of::<i32>() as u8 }    // 4
#[panic_handler] fn p(_: &core::panic::PanicInfo) -> ! { loop {} }
