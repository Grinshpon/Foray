const std = @import("std");
const fmt = std.fmt;
const Allocator = std.mem.Allocator;

pub const LexError = error {
  LexError,
  LexNumError,
  InternalError,
};

pub const Token = union(enum) {
  Int: i64,
  Float: f64,
  Bool: bool,
  Str: []const u8,
  Char: []const u8, //for now. char parsing comes later
  Sym: []const u8,
  LParen, RParen, Colon, Semicolon,
};

pub fn printToken(self: Token) void {
  switch (self) {
    Token.Int => |x| std.debug.print(":Int({})", .{x}),
    Token.Float => |x| std.debug.print(":Float({})", .{x}),
    Token.Bool => |x| std.debug.print(":Bool({})", .{x}),
    Token.Str => |x| std.debug.print(":Str(\"{}\")", .{x}),
    Token.Sym => |x| std.debug.print(":Sym({})", .{x}),
    Token.LParen => std.debug.print(":LParen", .{}),
    Token.RParen => std.debug.print(":RParen", .{}),
    Token.Colon => std.debug.print(":Define", .{}),
    Token.Semicolon => std.debug.print(":Eval", .{}),
  }
}

pub const TokenNode = struct {
  data: Token,
  row: u64,
  col: u64,
  next: ?*TokenNode,

  pub fn new(allocator: *Allocator, tk: Token, row: u64, col: u64) LexError!*TokenNode {
    var node: *TokenNode = allocator.create(TokenNode) catch return LexError.InternalError;
    node.data = tk;
    node.next = null;
    node.row = row;
    node.col = col;
    return node;
  }

  pub fn print(self: *TokenNode) void {
    std.debug.print(" {}:{}", .{self.row,self.col});
    printToken(self.data);
  }
};

pub const TokenList = struct {
  allocator: *Allocator,
  head: ?*TokenNode,
  last: ?*TokenNode,
  len: u64,

  pub fn new(allocator: *Allocator) TokenList {
    return TokenList {
      .allocator = allocator,
      .head = null,
      .last = null,
      .len = 0,
    };
  }

  pub fn push(self: *TokenList, tk: Token, row: u64, col: u64) LexError!void {
    var node = try TokenNode.new(self.allocator, tk, row, col);
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

  pub fn free(self: *TokenList) void {
    if (self.len > 0) {
      var current = self.head;
      //note: either destroy alloc'd strings from Token.String and Token.Sym
      // or don't and transfer the pointers to the Expr from the parser/eval
      while (current != null) {
        var node = current.?;
        current = current.?.next;
        self.allocator.destroy(node);
      }
    }
  }

  pub fn print(self: *TokenList) void {
    std.debug.print("Token List: ", .{});
    if (self.len > 0) {
      var current = self.head;
      while (current != null) {
        current.?.print();
        current = current.?.next;
      }
    }
    std.debug.print("\n",.{});
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

pub fn lexNum(src: []const u8, index: *u64, len: u64, col: *u64) LexError!Token {
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
  col.* += end-start;
  if (isFloat) {
    return Token {.Float = fmt.parseFloat(f64, slice) catch return LexError.LexNumError};
  }
  else {
    return Token {.Int = fmt.parseInt(i64, slice, 10) catch return LexError.LexNumError}; 
  }
}

pub fn lexStr(allocator: *Allocator, src: []const u8, index: *u64, len: u64, col: *u64) LexError!Token {
  var c: u8 = undefined;
  var ix = index.* + 1;
  var start = ix;
  var end = start;
  while (ix < len) {
    c = src[ix];
    if (c == '"' and src[ix-1] != '\\') {
      break;
    }
    end += 1;
    ix += 1;
  }
  var slice = src[start..end];
  var str = allocator.alloc(u8, end-start) catch return LexError.InternalError;
  std.mem.copy(u8, str, slice);

  index.* = ix;
  col.* += end-start;

  return Token {.Str = str};
}
//TODO: real character parsing (escape codes and shizz)
pub fn lexChar(allocator: *Allocator, src: []const u8, index: *u64, len: u64, col: *u64) LexError!Token {
  var c: u8 = undefined;
  var ix = index.* + 1;
  var start = ix;
  var end = start;
  while (ix < len) {
    c = src[ix];
    if (c == '\'' and src[ix-1] != '\\') {
      break;
    }
    end += 1;
    ix += 1;
  }
  var slice = src[start..end];
  var str = allocator.alloc(u8, end-start) catch return LexError.InternalError;
  std.mem.copy(u8, str, slice);

  index.* = ix;
  col.* += end-start;

  return Token {.Char = str};
}

pub fn lexSymOrBool(allocator: *Allocator, src: []const u8, index: *u64, len: u64, col: *u64) LexError!Token {
  var c: u8 = undefined;
  var ix = index.*;
  var start = ix;
  var end = start;
  while (ix < len) {
    c = src[ix];
    if (isSpace(c) or isReserved(c)) { //or isNumeric()
      break;
    } 
    end += 1;
    ix += 1;
  }
  var slice = src[start..end];
  var ident = allocator.alloc(u8, end-start) catch return LexError.InternalError;
  std.mem.copy(u8, ident, slice);

  index.* = ix-1;
  col.* += end-start;

  if (std.mem.eql(u8,ident, "true")) {
    return Token {.Bool = true};
  }
  else if (std.mem.eql(u8,ident, "false")) {
    return Token {.Bool = false};
  }
  else {
    return Token {.Sym = ident};
  }
}

pub fn lex(allocator: *Allocator, src: []const u8, len: u64) LexError!TokenList {
  var row: u64 = 1;
  var col: u64 = 1;
  var tlist = TokenList.new(allocator);
  var ix: u64 = 0;
  var c = src[ix];
  while (ix < len) {
    c = src[ix];
    switch (c) {
      '(' => {try tlist.push(Token.LParen, row, col); col += 1;},
      ')' => {try tlist.push(Token.RParen, row, col); col += 1;},
      ':' => {try tlist.push(Token.Colon, row, col); col += 1;},
      ';' => {try tlist.push(Token.Semicolon, row, col); col += 1;},
      '\n' => {row += 1; col = 1;},
      '"' => {
        var ocol = col;
        var tk = try lexStr(allocator, src, &ix, len, &col);
        try tlist.push(tk,row,ocol);
      },
      '\'' => {
        var ocol = col;
        var tk = try lexChar(allocator, src, &ix, len, &col);
        try tlist.push(tk,row,ocol);
      },
      else => {
        if (isSpace(c)) {
          col += 1;
        } // ignore whitespace
        else if (isNumeric(c)) { //parse number
          var ocol = col;
          var tk = try lexNum(src, &ix, len, &col);
          try tlist.push(tk,row,ocol);
        }
        // todo: chars and strings
        else { //only remaining option is to parse as a symbol or bool. symbols can be any combination as long as it doesn't contain a reserved character
          var ocol = col;
          var tk = try lexSymOrBool(allocator, src, &ix, len, &col);
          try tlist.push(tk,row,ocol);
        }
      },
    }
    ix += 1;
  }
  return tlist;
}
