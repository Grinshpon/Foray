const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;

const parser = @import("parser.zig");
const ast = @import("ast.zig");
const Expr = ast.Expr;

const ExprList = ast.ExprList;
const Dict = std.StringHashMap(Expr);

const EvalError = error {
  CannotEvalValue,
  SymbolNotFound,
  StackOverflow,
  StackUnderflow,
  TypeMismatch,
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

  pub fn peek(self: *Stack) !Expr {
    if (self.len == 0) {
      return EvalError.StackUnderflow;
    }
    else {
      return self.data.items[self.len-1];
    }
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

  pub fn put(self: *Env, ident: []const u8, expr: Expr) !void {
    try self.data.put(ident, expr);
  }

  pub fn get(self: *Env, ident: []const u8) !Expr {
    var current: ?*Env = self;
    while (current != null) {
      if (current.?.data.contains(ident)) {
        if (current.?.data.get(ident)) |e| {
          return e;
        }
      }
      current = current.?.outer;
    }
    return EvalError.SymbolNotFound;
  }

  pub fn print(self: *Env) void {
    var current: ?*Env = self;
    std.debug.print("Env:\n", .{});
    while (current != null) {
      var iter = current.?.data.iterator();
      while (iter.next()) |entry| {
        std.debug.print("\t{}\n", .{entry});
      }
      current = current.?.outer;
    }
  }
};

pub const NumOpTy = enum {
  Add, Sub, Mul, Div,
};

pub const BoolOpTy = enum {
  Eq, Neq,
  Lt, Gt, Leq, Geq,
  And, Or,
};

fn numOp (comptime T: type, op: NumOpTy, x: T, y: T) T {
  switch (op) {
    NumOpTy.Add => return x+y,
    NumOpTy.Sub => return x-y,
    NumOpTy.Mul => return x*y,
    NumOpTy.Div => {
      if (T == f64) {
        return x/y;
      }
      else {
        return @divTrunc(x,y);
      }
    },
  }
}

fn numBoolOp(comptime T: type, op: BoolOpTy, x: T, y: T) !bool {
  switch(op) {
    BoolOpTy.Eq => return x == y,
    BoolOpTy.Neq => return x != y,
    BoolOpTy.Lt => return x < y,
    BoolOpTy.Gt => return x > y,
    BoolOpTy.Leq => return x <= y,
    BoolOpTy.Geq => return x >= y,
    else => return EvalError.TypeMismatch,
  }
}
fn boolOp(op: BoolOpTy, x: bool, y: bool) !bool {
  switch(op) {
    BoolOpTy.Eq => return x == y,
    BoolOpTy.Neq => return x != y,
    BoolOpTy.And => return x and y,
    BoolOpTy.Or => return x or y,
    else => return EvalError.TypeMismatch,
  }
}

pub const Runtime = struct {
  stack: Stack,
  global: *Env,
  env: *Env,
  allocator: *Allocator,
  //todo: specify stdout and stdin
  pub fn init(allocator: *Allocator) !Runtime {
    var newEnv = try allocator.create(Env);
    newEnv.* = Env.init(allocator);
    // alternative, do not store global env, just the current one, and remove ptr allocation
    return Runtime {
      .stack = Stack.init(allocator),
      .global = newEnv,
      .env = newEnv,
      .allocator = allocator,
    };
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
    //like the normal eval function, but doesn't open/close a new scope, instead variables are in the global scope
    switch (root) {
      Expr.List => |x| {
        for (x.items) |e| {
          try self.push(e);
        }
      },
      else => return EvalError.CannotEvalValue,
    }
  }

  pub fn push(self: *Runtime, expr: Expr) anyerror!void {
    switch (expr) {
      Expr.Sym => |x| {
        // substitute from env
        var e = try self.env.get(x);
        try self.stack.push(e);
      },
      Expr.Op => |x| {
        //perform defined operation
        if (mem.eql(u8, x, "*")) {
          try self.doNumOp(NumOpTy.Mul);
        }
        else if (mem.eql(u8, x, "+")) {
          try self.doNumOp(NumOpTy.Add);
        }
        else if (mem.eql(u8, x, "/")) {
          try self.doNumOp(NumOpTy.Div);
        }
        else if (mem.eql(u8, x, "-")) {
          try self.doNumOp(NumOpTy.Sub);
        }
        else if (mem.eql(u8, x, "drop")) {
          try self.drop();
        }
        else if (mem.eql(u8, x, "swap")) {
          try self.swap();
        }
        else if (mem.eql(u8, x, "rot")) {
          try self.rot();
        }
        else if (mem.eql(u8, x, "dup")) {
          try self.dup();
        }
        else if (mem.eql(u8, x, "=")) {
          try self.doBoolOp(BoolOpTy.Eq);
        }
        else if (mem.eql(u8, x, "!=")) {
          try self.doBoolOp(BoolOpTy.Neq);
        }
        else if (mem.eql(u8, x, "<")) {
          try self.doBoolOp(BoolOpTy.Lt);
        }
        else if (mem.eql(u8, x, ">")) {
          try self.doBoolOp(BoolOpTy.Gt);
        }
        else if (mem.eql(u8, x, "<=")) {
          try self.doBoolOp(BoolOpTy.Leq);
        }
        else if (mem.eql(u8, x, ">=")) {
          try self.doBoolOp(BoolOpTy.Geq);
        }
        else if (mem.eql(u8, x, "&&")) {
          try self.doBoolOp(BoolOpTy.And);
        }
        else if (mem.eql(u8, x, "||")) {
          try self.doBoolOp(BoolOpTy.Or);
        }
      },
      Expr.Eval => {
        //pop and eval
        var e = try self.stack.pop();
        try self.eval(e);
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

  // Builtins

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

  pub fn define(self: *Runtime, ident: []const u8) !void {
    var e = try self.pop();
    try self.env.put(ident, e);
  }

  pub fn drop(self: *Runtime) !void {
    _ = try self.pop();
  }

  pub fn swap(self: *Runtime) !void {
    var e1 = try self.pop();
    var e2 = try self.pop();
    try self.push(e1);
    try self.push(e2);
  }

  pub fn rot(self: *Runtime) !void {
    var e1 = try self.pop();
    var e2 = try self.pop();
    var e3 = try self.pop();
    try self.push(e1);
    try self.push(e3);
    try self.push(e2);
  }

  pub fn dup(self: *Runtime) !void {
    var e = try self.stack.peek();
    try self.push(e);
  }

  pub fn doNumOp(self: *Runtime, op: NumOpTy) !void {
    var rhs = try self.pop();
    var lhs = try self.pop();
    switch (lhs) {
      Expr.Int => |x| {
        switch (rhs) {
          Expr.Int => |y| {
            try self.push(Expr {.Int = numOp(i64, op, x, y)});
          },
          else => {
            return EvalError.TypeMismatch;
          },
        }
      },
      Expr.Float => |x| {
        switch (rhs) {
          Expr.Float => |y| {
            try self.push(Expr {.Float = numOp(f64, op, x, y)});
          },
          else => {
            return EvalError.TypeMismatch;
          },
        }
      },
      else => {
        return EvalError.TypeMismatch;
      },
    }
  }

  pub fn doBoolOp(self: *Runtime, op: BoolOpTy) !void {
    var rhs = try self.pop();
    var lhs = try self.pop();
    switch (lhs) {
      Expr.Int => |x| {
        switch (rhs) {
          Expr.Int => |y| {
            try self.push(Expr {.Bool = try numBoolOp(i64, op, x, y)});
          },
          else => {
            return EvalError.TypeMismatch;
          },
        }
      },
      Expr.Float => |x| {
        switch (rhs) {
          Expr.Float => |y| {
            try self.push(Expr {.Bool = try numBoolOp(f64, op, x, y)});
          },
          else => {
            return EvalError.TypeMismatch;
          },
        }
      },
      Expr.Bool => |x| {
        switch (rhs) {
          Expr.Bool => |y| {
            try self.push(Expr {.Bool = try boolOp(op, x, y)});
          },
          else => {
            return EvalError.TypeMismatch;
          },
        }
      },
      else => {
        return EvalError.TypeMismatch;
      },
    }
  }

  // Print Stack
  pub fn printStack(self: *Runtime) void {
    self.stack.print();
  }
};
