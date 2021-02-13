const std = @import("std");
const Allocator = std.mem.Allocator;

const parser = @import("parser.zig");
const ast = @import("ast.zig");
const Expr = ast.Expr;

const ExprList = ast.ExprList;
const Dict = std.AutoHashMap([]const u8, Expr);

////// Evaluation \\\\\\

const EvalError = error {
  CannotEvalValue,
  StackOverflow,
  StackUnderflow,
};

pub const Stack = struct {
  data: ExprList,
  len: usize,

  pub fn init(allocator: *Allocator) Stack {
    return Stack {
      .data = ExprList.init(allocator),
      .len = 0,
    };
  }

  pub fn push(self: *Stack, item: Expr) !void {
    try self.data.append(item);
    self.len += 1;
  }

  pub fn pop(self: *Stack) !Expr {
    if (self.len == 0) {
      return EvalError.StackUnderflow;
    }
    var e = self.data.pop();
    self.len -= 1;
    return e;
  }
  
  pub fn print(self: *Stack) void {
    std.debug.print("=>", .{});
    for(self.data.items) |e| {
      e.print();
    }
    std.debug.print("\n", .{});
  }
};

pub const Env = struct {
  data: Dict,
  outer: ?*Env,

  pub fn init(allocator: *Allocator) Env {
    return Env {
      .data = Dict.init(allocator),
      .outer = null,
    };
  }

  pub fn put(self: *Env, name: []const u8, expr: Expr) !void {
    try self.data.put(name, expr);
  }
};

pub const Runtime = struct {
  stack: Stack,
  global: Env,
  env: *Env,
  allocator: *Allocator,
  //todo: specify stdout and stdin
  pub fn init(allocator: *Allocator) Runtime {
    var r = Runtime {
      .stack = Stack.init(allocator),
      .global = Env.init(allocator),
      .env = undefined,
      .allocator = allocator,
    };
    r.env = &r.global;
    return r;
  }

  pub fn openScope(self: *Runtime) !void {
    var current = self.env;
    self.env = try self.allocator.create(Env);
    self.env.* = Env.init(self.allocator);
    self.env.outer = current;
  }

  pub fn closeScope(self: *Runtime) void {
    var current = self.env;
    self.env = self.env.outer.?;
    self.allocator.destroy(current);
  }

  pub fn evaluate(self: *Runtime, root: Expr) !void {
    try self.eval(root);
  }

  pub fn eval(self: *Runtime, expr: Expr) !void {
    switch (expr) {
      Expr.List => |x| {
        try self.openScope();
        for (x.items) |e| {
          try self.push(e);
        }
        self.closeScope();
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
      Expr.Define => |x| {
        try self.define(x);
      },
      else => {
        try self.stack.push(expr);
      },
    }
  }

  pub fn pop(self: *Runtime) !Expr {
    return try self.stack.pop();
  }

  pub fn define(self: *Runtime, ident: []const u8) !void {
    var e = try self.pop();
    try self.env.put(ident, e);
  }

  pub fn printStack(self: *Runtime) void {
    self.stack.print();
  }
};
