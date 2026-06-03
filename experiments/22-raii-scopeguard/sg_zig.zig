extern fn trace(c: u8) void;
// Zig defer: runs at scope exit, LIFO.
export fn zig_run() void {
    defer trace('1');
    defer trace('2');
}
// errdefer: fires ONLY on the error-return path. zig_err(1) -> error -> 'X' fires;
// zig_err(0) -> success -> 'X' does NOT fire. (Rust has no errdefer; uses Result+Drop.)
fn mayFail(fail: bool) !void {
    errdefer trace('X');
    if (fail) return error.Bad;
}
export fn zig_err(fail: u8) u8 { mayFail(fail != 0) catch return 1; return 0; }
// 'errdefer comptime unreachable' asserts a block can never take an error path
// (compiles only because noErr() has none).
fn noErr() void { errdefer comptime unreachable; }
export fn zig_noerr() void { noErr(); }
