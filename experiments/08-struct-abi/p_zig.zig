// BUG: Zig's extern struct uses NATURAL alignment (@alignOf(u32)==4 on mos),
// so val lands at offset 4, sizeof 12 -- NOT the MOS byte-packed C ABI (off 1,
// sizeof 6). Reading a C-built Pkt through this misreads val.
const Pkt = extern struct { tag: u8, val: u32, flag: u8 };
export fn zig_read(p: *const Pkt) u32 { return p.val; }
export fn zig_size() u8 { return @sizeOf(Pkt); }

// FIX A: force C byte-packing with explicit field alignment align(1).
const PktFixed = extern struct { tag: u8, val: u32 align(1), flag: u8 align(1) };
export fn zig_read_fixed(p: *const PktFixed) u32 { return p.val; }
export fn zig_size_fixed() u8 { return @sizeOf(PktFixed); }

// FIX B (idiomatic): packed struct -> bit-packed into a u48 backing int, which
// is byte-packed in memory (tag@bit0, val@bit8, flag@bit40) == C's layout.
const PktPacked = packed struct { tag: u8, val: u32, flag: u8 };
export fn zig_read_packed(p: *const PktPacked) u32 { return p.val; }
export fn zig_size_packed() u8 { return @sizeOf(PktPacked); }
