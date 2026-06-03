// ASCII uppercase transform (the per-char worker, called from C per byte).
export fn up(c: u8) u8 {
    return if (c >= 'a' and c <= 'z') c - 32 else c;
}
