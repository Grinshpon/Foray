const std = @import("std");

pub const Expr = union(enum) {
  Int: i64,
  Float: f64,
  Bool: bool,
  Str: []u8,
  Sym: []u8,
  List: std.ArrayList(Expr),
};

pub const STACK_SIZE: usize = 2048;
pub const Stack = struct {
  data: [STACK_SIZE]Val,
  index: usize,
};

