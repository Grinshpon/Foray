const std = @import("std");

pub const ExprList = std.ArrayList(Expr);

pub const Expr = union(enum) {
  Int: i64,
  Float: f64,
  Bool: bool,
  Str: []const u8,
  Char: []const u8,
  //differentiate symbols, assignment, and operators (builtins)
  Sym: []const u8,
  Op: []const u8,
  Define: []const u8,
  List: std.ArrayList(Expr),
  Eval,

  pub fn debugPrint(self: Expr) void {
    switch (self) {
      Expr.Int => |x| std.debug.print(" Int({})", .{x}),
      Expr.Float => |x| std.debug.print(" Float({})", .{x}),
      Expr.Bool => |x| std.debug.print(" Bool({})", .{x}),
      Expr.Str => |x| std.debug.print(" Str(\"{}\")", .{x}),
      Expr.Char => |x| std.debug.print(" Char(\'{}\')", .{x}),
      Expr.Sym => |x| std.debug.print(" Sym({})", .{x}),
      Expr.Op => |x| std.debug.print(" Op({})", .{x}),
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

  pub fn print(self: Expr) void {
    switch (self) {
      Expr.Int => |x| std.debug.print(" {}", .{x}),
      Expr.Float => |x| std.debug.print(" {}", .{x}),
      Expr.Bool => |x| std.debug.print(" {}", .{x}),
      Expr.Str => |x| std.debug.print(" \"{}\"", .{x}),
      Expr.Char => |x| std.debug.print(" \'{}\'", .{x}),
      Expr.Sym => |x| std.debug.print(" {}", .{x}),
      Expr.Op => |x| std.debug.print(" {}", .{x}),
      Expr.Define => |x| std.debug.print(" :{}", .{x}),
      Expr.Eval => std.debug.print(";", .{}),
      Expr.List => |x| {
        std.debug.print(" (", .{});
        for(x.items) |expr| {
          expr.print();
        }
        std.debug.print(")", .{});
      },
    }
  }
};

pub const operators = [_][]const u8 {
  "*", "/", "+", "-",
  "=", "!=", "<", ">", "<=", ">=",
  "!", "&&", "||",
  "drop", "swap", "rot", "dup",
  "if", "map"
};
