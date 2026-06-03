#![no_std]
pub fn f(x:usize)->i32{ *(x as *const i32) }
