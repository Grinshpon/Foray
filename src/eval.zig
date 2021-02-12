const std = @import("std");
const Allocator = std.mem.Allocator;

const lexer = @import("lexer.zig");

////// Evaluation \\\\\\

pub const Expr = union(enum) {
  Int: i64,
  Float: f64,
  Bool: bool,
  Str: []u8,
  List: []*Val,
  Sym: []u8,
};

pub const STACK_SIZE: usize = 2048;
pub const Stack = struct {
  data: [STACK_SIZE]Val,
  index: usize,
};

pub const Dict = struct {
  //a hashmap of symbols (strings) to Expr's
};
