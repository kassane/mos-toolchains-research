#![no_std]
unsafe extern "C" { fn trace(c: u8); }
// Rust RAII: values dropped in reverse declaration order (LIFO).
struct Guard(u8);
impl Drop for Guard { fn drop(&mut self) { unsafe { trace(self.0); } } }
#[unsafe(no_mangle)] pub extern "C" fn rs_run() {
    let _g1 = Guard(b'1');
    let _g2 = Guard(b'2');
}
#[panic_handler] fn p(_:&core::panic::PanicInfo)->!{loop{}}
