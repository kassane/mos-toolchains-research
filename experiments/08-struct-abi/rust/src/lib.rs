#![no_std]
#[repr(C)]
pub struct Pkt { pub tag: u8, pub val: u32, pub flag: u8 }   // repr(C) => C ABI
#[unsafe(no_mangle)] pub extern "C" fn rs_read(p: *const Pkt) -> u32 { unsafe { (*p).val } }
#[unsafe(no_mangle)] pub extern "C" fn rs_size() -> u8 { core::mem::size_of::<Pkt>() as u8 }
#[panic_handler] fn p(_:&core::panic::PanicInfo)->!{loop{}}
