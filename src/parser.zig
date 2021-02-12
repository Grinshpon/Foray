const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const lexer = @import("lexer.zig");
const ast = @import("ast.zig");

const ExprList = std.ArrayList(ast.Expr);

//the language is, like lisp, homoiconic. The parsed tree is itself a list, which is automatically evaluated
pub fn parse(allocator: *Allocator, tlist: *lexer.TokenList) !ast.Expr {
  var prog = ast.Expr {.List = ExprList.init(allocator)};


  try tlist.free();
  return prog;
}
