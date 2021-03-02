const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;

const parser = @import("parser.zig");
const ast = @import("ast.zig");
const Expr = ast.Expr;

const ExprList = ast.ExprList;
const Dict = std.StringHashMap(Expr);

pub const EvalError = error {
  CannotEvalValue,
  SymbolNotFound,
  StackOverflow,
  StackUnderflow,
  TypeMismatch,
  InternalError,
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

  pub fn push(self: *Stack, item: Expr) EvalError!void {
    self.data.append(item) catch |err| return EvalError.InternalError;
    self.len += 1;
  }

  pub fn pop(self: *Stack) EvalError!Expr {
    if (self.len == 0) {
      return EvalError.StackUnderflow;
    }
    var e = self.data.pop();
    self.len -= 1;
    return e;
  }

  pub fn peek(self: *Stack) EvalError!Expr {
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

  pub fn put(self: *Env, ident: []const u8, expr: Expr) EvalError!void {
    self.data.put(ident, expr) catch return EvalError.InternalError;
  }

  pub fn get(self: *Env, ident: []const u8) EvalError!Expr {
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

fn numBoolOp(comptime T: type, op: BoolOpTy, x: T, y: T) EvalError!bool {
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
fn boolOp(op: BoolOpTy, x: bool, y: bool) EvalError!bool {
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

  pub fn openScope(self: *Runtime) EvalError!void {
    var current = self.env;
    self.env = self.allocator.create(Env) catch return EvalError.InternalError;
    self.env.* = Env.init(self.allocator);
    self.env.outer = current;
  }

  pub fn closeScope(self: *Runtime) void {
    var current = self.env;
    self.env = self.env.outer.?;
    self.allocator.destroy(current);
  }

  pub fn evaluate(self: *Runtime, root: Expr) EvalError!void {
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

  pub fn push(self: *Runtime, expr: Expr) EvalError!void {
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
        else if (mem.eql(u8, x, "if")) {
          try self.ifn();
        }
        else if (mem.eql(u8, x, "!")) {
          try self.not();
        }
        else if (mem.eql(u8, x, "map")) {
          try self.map();
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

  pub fn pop(self: *Runtime) EvalError!Expr {
    return try self.stack.pop();
  }

  // Builtins

  pub fn eval(self: *Runtime, expr: Expr) EvalError!void {
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

  pub fn define(self: *Runtime, ident: []const u8) EvalError!void {
    var e = try self.pop();
    try self.env.put(ident, e);
  }

  pub fn drop(self: *Runtime) EvalError!void {
    _ = try self.pop();
  }

  pub fn swap(self: *Runtime) EvalError!void {
    var e1 = try self.pop();
    var e2 = try self.pop();
    try self.push(e1);
    try self.push(e2);
  }

  pub fn rot(self: *Runtime) EvalError!void {
    var e1 = try self.pop();
    var e2 = try self.pop();
    var e3 = try self.pop();
    try self.push(e1);
    try self.push(e3);
    try self.push(e2);
  }

  pub fn dup(self: *Runtime) EvalError!void {
    var e = try self.stack.peek();
    try self.push(e);
  }

  pub fn doNumOp(self: *Runtime, op: NumOpTy) EvalError!void {
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

  pub fn doBoolOp(self: *Runtime, op: BoolOpTy) EvalError!void {
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

  pub fn ifn(self: *Runtime) EvalError!void {
    var ifFalse = try self.pop();
    var ifTrue = try self.pop();
    var cond = try self.pop();
    switch (cond) {
      Expr.Bool => |x| {
        if (x) {
          try self.eval(ifTrue);
        }
        else {
          try self.eval(ifFalse);
        }
      },
      else => return EvalError.TypeMismatch,
    }
  }

  pub fn not(self: *Runtime) EvalError!void {
    var x = try self.pop();
    switch (x) {
      Expr.Bool => |xp| {
        try self.push(Expr {.Bool = !xp});
      },
      else => return EvalError.TypeMismatch,
    }
  }
 
  pub fn map(self: *Runtime) EvalError!void {
    var fl = try self.pop();
    var ls = try self.pop();
    switch (fl) {
      Expr.List => |f| {
        switch (ls) {
          Expr.List => |l| {
            for (l.items) |*item| {
              try self.push(item.*);
              try self.eval(fl);
              item.* = try self.pop();
            }
            try self.push(ls);
          },
          else => return EvalError.TypeMismatch,
        }
      },
      else => return EvalError.TypeMismatch,
    }
  }

  // Print Stack
  pub fn printStack(self: *Runtime) void {
    self.stack.print();
  }
};
