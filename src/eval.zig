const std = @import("std");
const Allocator = std.mem.Allocator;

const parser = @import("parser.zig");
const ast = @import("ast.zig");
const Expr = ast.Expr;

const ExprList = ast.ExprList;
const Dict = std.AutoArrayHashMap([]const u8, Expr);

////// Evaluation \\\\\\

const EvalError = error {
  CannotEvalValue,
  StackOverflow,
  StackUnderflow,
};

pub const Stack = struct {
  data: ExprList,
  index: usize,

  pub fn init(allocator: *Allocator) Stack {
    return Stack {
      .data = ExprList.init(allocator),
      .index = 0,
    };
  }

  pub fn push(self: *Stack, item: Expr) !void {
    try self.data.append(item);
    self.index += 1;
  }
};

pub const Scope = struct {
  data: Dict,
  outer: ?*Scope,

  pub fn init(allocator: *Allocator) Scope {
    return Scope {
      .data = Dict.init(allocator),
      .outer = null,
    };
  }
};

pub const Runtime = struct {
  stack: Stack,
  global: Scope,
  allocator: *Allocator,
  //todo: specify stdout and stdin
  pub fn init(allocator: *Allocator) Runtime {
    return Runtime {
      .stack = Stack.init(allocator),
      .global = Scope.init(allocator),
      .allocator = allocator,
    };
  }

  pub fn evaluate(self: *Runtime, root: Expr) !void {
    try self.eval(root);
  }

  pub fn eval(self: *Runtime, expr: Expr) !void {
    switch (expr) {
      Expr.List => |x| {
        for (x.items) |e| {
          try self.push(e);
        }
      },
      else => return EvalError.CannotEvalValue,
    }
  }

  pub fn push(self: *Runtime, expr: Expr) !void {
    switch (expr) {
      Expr.Op => |x| {
        //perform defined operation
      },
      Expr.Eval => {
        //pop and eval
      },
      else => {
        try self.stack.push(expr);
      },
    }
  }

  pub fn pop(self: *Runtime, expr: Expr) void {
    
  }

};
