const std = @import("std");
const fmt = std.fmt;
const Allocator = std.mem.Allocator;

////// Lexer \\\\\\

pub const Token = union(enum) {
  Int: i64,
  Float: f64,
  Bool: bool,
  Str: []const u8,
  Sym: []const u8,
  LParen, RParen, Colon, Semicolon,
};

pub fn printToken(self: Token) void {
  switch (self) {
    Token.Int => |x| std.debug.print(" Int({})", .{x}),
    Token.Float => |x| std.debug.print(" Float({})", .{x}),
    Token.Bool => |x| std.debug.print(" Bool({})", .{x}),
    Token.Str => |x| std.debug.print(" Str(\"{}\")", .{x}),
    Token.Sym => |x| std.debug.print(" Sym({})", .{x}),
    Token.LParen => std.debug.print(" LParen", .{}),
    Token.RParen => std.debug.print(" RParen", .{}),
    Token.Colon => std.debug.print(" Assign", .{}),
    Token.Semicolon => std.debug.print(" Unpack", .{}),
  }
}

pub const TokenNode = struct {
  data: Token,
  next: ?*TokenNode,

  pub fn new(allocator: *Allocator, tk: Token) !*TokenNode {
    var node: *TokenNode = try allocator.create(TokenNode);
    node.data = tk;
    node.next = null;
    return node;
  }
};

pub const TokenList = struct {
  allocator: *Allocator,
  head: ?*TokenNode,
  last: ?*TokenNode,
  len: usize,

  pub fn new(allocator: *Allocator) TokenList {
    return TokenList {
      .allocator = allocator,
      .head = null,
      .last = null,
      .len = 0,
    };
  }

  pub fn push(self: *TokenList, tk: Token) !void {
    var node = try TokenNode.new(self.allocator, tk);
    if (self.head == null) {
      self.head = node;
      self.last = node;
    }
    else {
      self.last.?.next = node;
      self.last = node;
    }
    self.len += 1;
  }

  pub fn free(self: *TokenList) !void {
    if (self.len > 0) {
      var current = self.head;
      //note: either destroy alloc'd strings from Token.String and Token.Sym
      // or don't and transfer the pointers to the Expr from the parser/eval
      while (current != null) {
        var node = current;
        current = current.?.next;
        self.allocator.destroy(node);
      }
    }
  }

  pub fn print(self: *TokenList) void {
    if (self.len > 0) {
      var current = self.head;
      while (current != null) {
        printToken(current.?.data);
        current = current.?.next;
      }
    }
  }
};

fn isReserved(c: u8) bool {
  return switch(c) {
    '(', ')', ':', ';', '\'', '\"' => true,
    else => false,
  };
}

fn isSpace(c: u8) bool {
  return (c == ' ') or (c == '\n') or (c == '\t') or (c == '\r');
}

fn isAlpha(c: u8) bool {
  return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

fn isNumeric(c: u8) bool {
  return (c >= '0' and c <= '9');
}

pub fn lexNum(src: []const u8, index: *u64, len: u64) !Token {
  var c: u8 = undefined;
  var ix = index.*;
  var start = ix;
  var end: u64 = start;
  var isFloat: bool = false;
  while (ix < len) {
    c = src[ix];
    if (c == '.') {
      isFloat = true;
    }
    else if (!isNumeric(c)) {
      break;
    }
    end += 1;
    ix += 1;
  }

  index.* = ix-1;
  var slice = src[start..end];
  if (isFloat) {
    return Token {.Float = try fmt.parseFloat(f64, slice)};
  }
  else {
    return Token {.Int = try fmt.parseInt(i64, slice, 10)}; 
  }
}

pub fn lexSym(allocator: *Allocator, src: []const u8, index: *u64, len: u64) !Token {
  var c: u8 = undefined;
  var ix = index.*;
  var start = ix;
  var end = start;
  while (ix < len) {
    c = src[ix];
    if (isSpace(c) or isNumeric(c) or isReserved(c)) {
      break;
    } 
    end += 1;
    ix += 1;
  }
  var slice = src[start..end];
  var ident = try allocator.alloc(u8, end-start);
  std.mem.copy(u8, ident, slice);

  index.* = ix-1;
  return Token {.Sym = ident};
}

pub fn lex(allocator: *Allocator, src: []const u8, len: u64) !TokenList {
  var tlist = TokenList.new(allocator);
  var ix: u64 = 0;
  var c = src[ix];
  while (ix < len) {
    c = src[ix];
    switch (c) {
      '(' => {try tlist.push(Token.LParen);},
      ')' => {try tlist.push(Token.RParen);},
      ':' => {try tlist.push(Token.Colon);},
      ';' => {try tlist.push(Token.Semicolon);},
      else => {
        if (isSpace(c)) {} // ignore whitespace
        else if (isNumeric(c)) { //parse number
          try tlist.push(try lexNum(src, &ix, len));
        }
        // todo: chars and strings
        else { //only remaining option is to parse as a symbol. symbols can be any combination as long as it doesn't contain a reserved character
          try tlist.push(try lexSym(allocator, src, &ix, len));
        }
      },
    }
    ix += 1;
  }
  std.debug.print("Token List: ", .{});
  tlist.print();
  return tlist;
}
