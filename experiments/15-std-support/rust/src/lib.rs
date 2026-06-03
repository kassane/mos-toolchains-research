#![no_std]
extern crate alloc;
use alloc::vec::Vec;
use core::alloc::{GlobalAlloc, Layout};
unsafe extern "C" { fn malloc(n: usize) -> *mut u8; fn free(p: *mut u8); } // edition 2024
struct A;
unsafe impl GlobalAlloc for A {
    unsafe fn alloc(&self,l:Layout)->*mut u8{ malloc(l.size()) }
    unsafe fn dealloc(&self,p:*mut u8,_:Layout){ free(p) }
}
#[global_allocator] static GA: A = A;
#[unsafe(no_mangle)] pub extern "C" fn rs_std() -> u16 {
    let mut v: Vec<u16> = Vec::new();
    let mut i=0u16; while i<5 { v.push(i+1); i+=1; }   // 1..5
    v.iter().sum()                                     // 15
}
#[panic_handler] fn p(_:&core::panic::PanicInfo)->!{loop{}}
