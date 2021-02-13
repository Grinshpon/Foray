const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const lexer = @import("lexer.zig");
const Token = lexer.Token;
const ast = @import("ast.zig");
const Expr = ast.Expr;

const ExprList = ast.ExprList;

const ParserError = error {
  NonSymbolDefinition,
  ExtraClosingParens,
  UnknownError,
};

pub fn parseDefine(node: *lexer.TokenNode) ParserError!Expr {
  switch (node.next.?.data) {
    Token.Sym => |x| {
      return Expr {.Define = x};
    },
    else => {
      return ParserError.NonSymbolDefinition;
    },
  }
}

pub fn parseList(allocator: *Allocator, ix: *lexer.TokenNode, skip: *u64) anyerror!Expr {
  var node = ix.next;
  var list = Expr {.List = ExprList.init(allocator)};
  var tokensProcessed: u64 = skip.* + 1;
  while (node != null) {
    switch (node.?.data) {
      Token.RParen => break,
      else => {},
    }
    var toSkip: u64 = 0;
    try list.List.append(try parseExpr(allocator, node.?, &toSkip));
    tokensProcessed += toSkip;
    while (toSkip > 0 and node != null) {
      node = node.?.next;
      toSkip -= 1;
    }
    node = node.?.next;
    tokensProcessed += 1;
  }
  skip.* = tokensProcessed;
  return list;
}

pub fn parseExpr(allocator: *Allocator, node: *lexer.TokenNode, skip: *u64) anyerror!Expr {
  switch (node.data) {
    Token.Int => |x| return Expr {.Int = x},
    Token.Float => |x| return Expr {.Float = x},
    Token.Bool => |x| return Expr {.Bool = x},
    Token.Str => |x| return Expr {.Str = x},
    Token.Sym => |x| {
      for (ast.operators) |op| {
        if (std.mem.eql(u8, op, x)) {
          return Expr {.Op = x};
        }
      }
      return Expr {.Sym = x};
    },
    Token.Semicolon => return Expr.Eval,
    Token.Colon => {
      skip.* += 1;
      return try parseDefine(node);
    },
    Token.LParen => {
      return try parseList(allocator, node, skip);
    },
    Token.RParen => return ParserError.ExtraClosingParens,
  }
}

//the language is, like lisp, homoiconic. The parsed tree is itself a list, which is automatically evaluated
pub fn parse(allocator: *Allocator, tlist: *lexer.TokenList) anyerror!Expr {
  var prog = Expr {.List = ExprList.init(allocator)};

  var current = tlist.head;
  while (current != null) {
    var toSkip: usize = 0;
    try prog.List.append(try parseExpr(allocator, current.?, &toSkip));
    while (toSkip > 0 and current != null) {
      current = current.?.next;
      toSkip -= 1;
    }
    current = current.?.next;
  }

  try tlist.free();
  return prog;
}

pub fn printAST(prog: *Expr) void {
  std.debug.print("AST: ", .{});
  prog.debugPrint();
  std.debug.print("\n",.{});
}
