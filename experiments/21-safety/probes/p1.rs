#![no_std]
pub fn f(p:*const i32, i:usize)->i32{ p.add(i).read() }
