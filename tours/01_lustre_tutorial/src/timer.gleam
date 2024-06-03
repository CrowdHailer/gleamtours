@external(javascript, "./timer_ffi.mjs", "setTimeout")
pub fn set_timeout(delay: Int, callback: fn() -> anything) -> Nil
