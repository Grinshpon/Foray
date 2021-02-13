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
          try self.mul();
        }
        else if (mem.eql(u8, x, "+")) {
          try self.add();
        }
        else if (mem.eql(u8, x, "/")) {
          try self.div();
        }
        else if (mem.eql(u8, x, "-")) {
          try self.sub();
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

  pub fn mul(self: *Runtime) !void {
    var rhs = try self.pop();
    var lhs = try self.pop();
    switch (lhs) {
      Expr.Int => |x| {
        switch (rhs) {
          Expr.Int => |y| {
            try self.push(Expr {.Int = x*y});
          },
          else => {
            return EvalError.TypeMismatch;
          },
        }
      },
      Expr.Float => |x| {
        switch (rhs) {
          Expr.Float => |y| {
            try self.push(Expr {.Float = x*y});
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
  pub fn div(self: *Runtime) !void {
    var rhs = try self.pop();
    var lhs = try self.pop();
    switch (lhs) {
      Expr.Int => |x| {
        switch (rhs) {
          Expr.Int => |y| {
            try self.push(Expr {.Int = @divTrunc(x,y)});
          },
          else => {
            return EvalError.TypeMismatch;
          },
        }
      },
      Expr.Float => |x| {
        switch (rhs) {
          Expr.Float => |y| {
            try self.push(Expr {.Float = x/y});
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
  pub fn add(self: *Runtime) !void {
    var rhs = try self.pop();
    var lhs = try self.pop();
    switch (lhs) {
      Expr.Int => |x| {
        switch (rhs) {
          Expr.Int => |y| {
            try self.push(Expr {.Int = x+y});
          },
          else => {
            return EvalError.TypeMismatch;
          },
        }
      },
      Expr.Float => |x| {
        switch (rhs) {
          Expr.Float => |y| {
            try self.push(Expr {.Float = x+y});
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
  pub fn sub(self: *Runtime) !void {
    var rhs = try self.pop();
    var lhs = try self.pop();
    switch (lhs) {
      Expr.Int => |x| {
        switch (rhs) {
          Expr.Int => |y| {
            try self.push(Expr {.Int = x-y});
          },
          else => {
            return EvalError.TypeMismatch;
          },
        }
      },
      Expr.Float => |x| {
        switch (rhs) {
          Expr.Float => |y| {
            try self.push(Expr {.Float = x-y});
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
