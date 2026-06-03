// Vendored from kassane/zig-mos-examples sdk/panic.zig (Apache-2.0).
// Namespace-style panic handler for MOS: every safety panic halts (the default
// std.debug.no_panic @trap() lowers to an undefined `abort` on bare-metal MOS).
// Here outOfBounds also writes $FFF8=77 so the sim reports the trap as exit 77.
fn halt() noreturn { while (true) {} }
pub fn call(_: []const u8, _: ?usize) noreturn { halt(); }
pub fn outOfBounds(_: usize, _: usize) noreturn { @as(*volatile u8, @ptrFromInt(0xFFF8)).* = 77; halt(); }
pub fn sentinelMismatch(_: anytype, _: anytype) noreturn { halt(); }
pub fn unwrapError(_: anyerror) noreturn { halt(); }
pub fn startGreaterThanEnd(_: usize, _: usize) noreturn { halt(); }
pub fn inactiveUnionField(_: anytype, _: anytype) noreturn { halt(); }
pub fn sliceCastLenRemainder(_: usize) noreturn { halt(); }
pub fn reachedUnreachable() noreturn { halt(); }
pub fn unwrapNull() noreturn { halt(); }
pub fn castToNull() noreturn { halt(); }
pub fn incorrectAlignment() noreturn { halt(); }
pub fn invalidErrorCode() noreturn { halt(); }
pub fn integerOutOfBounds() noreturn { halt(); }
pub fn integerOverflow() noreturn { halt(); }
pub fn shlOverflow() noreturn { halt(); }
pub fn shrOverflow() noreturn { halt(); }
pub fn divideByZero() noreturn { halt(); }
pub fn exactDivisionRemainder() noreturn { halt(); }
pub fn integerPartOutOfBounds() noreturn { halt(); }
pub fn corruptSwitch() noreturn { halt(); }
pub fn shiftRhsTooBig() noreturn { halt(); }
pub fn invalidEnumValue() noreturn { halt(); }
pub fn forLenMismatch() noreturn { halt(); }
pub fn copyLenMismatch() noreturn { halt(); }
pub fn memcpyAlias() noreturn { halt(); }
pub fn noreturnReturned() noreturn { halt(); }
