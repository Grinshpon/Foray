const std = @import("std");

pub const Expr = union(enum) {
  Int: i64,
  Float: f64,
  Bool: bool,
  Str: []const u8,
  Sym: []const u8,
  Define: []const u8, //differentiate assignment from just symbol
  List: std.ArrayList(Expr),
  Eval,

  pub fn print(self: Expr) void {
    switch (self) {
      Expr.Int => |x| std.debug.print(" Int({})", .{x}),
      Expr.Float => |x| std.debug.print(" Float({})", .{x}),
      Expr.Bool => |x| std.debug.print(" Bool({})", .{x}),
      Expr.Str => |x| std.debug.print(" Str(\"{}\")", .{x}),
      Expr.Sym => |x| std.debug.print(" Sym({})", .{x}),
      Expr.Define => |x| std.debug.print(" Define({})", .{x}),
      Expr.Eval => std.debug.print(" Eval", .{}),
      Expr.List => |x| {
        std.debug.print("List(", .{});
        for(x.items) |expr| {
          expr.print();
        }
        std.debug.print(")", .{});
      },
    }
  }
};

pub const STACK_SIZE: usize = 2048;
pub const Stack = struct {
  data: [STACK_SIZE]Val,
  index: usize,
};

