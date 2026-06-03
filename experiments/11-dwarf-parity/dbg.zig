// wrapping add: avoids the Debug-mode overflow safety check whose panic handler
// pulls in @llvm.returnaddress, which the MOS backend cannot legalize.
export fn dbg_add(a: i32, b: i32) i32 { const s = a +% b; return s; }
