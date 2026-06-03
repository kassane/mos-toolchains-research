export fn zig_lcg(n: u16) u16 {
    var s: u16 = 0; var i: u16 = 0;
    while (i < n) : (i +%= 1) { s = s *% 31 +% i; }
    return s;
}
