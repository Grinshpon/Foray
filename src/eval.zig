const std = @import("std");
const Allocator = std.mem.Allocator;

////// Evaluation \\\\\\

pub const STACK_SIZE: usize = 2048;
pub const Stack = struct {
  data: [STACK_SIZE]Val,
  index: usize,
};

pub const Dict = struct {
  //a hashmap of symbols (strings) to Expr's
};
