#![no_std]
pub union U{ p:*const i32, n:usize }
pub fn f(x:*const i32)->usize{ let u=U{p:x}; u.n }
