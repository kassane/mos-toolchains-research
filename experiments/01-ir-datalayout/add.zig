// export => C ABI, external linkage.
export fn add(a: i32, b: i32) i32 {
    return a +% b; // wrapping add: avoid safety-check branches
}
