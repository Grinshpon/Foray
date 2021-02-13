const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const eval = @import("eval.zig");

pub fn main() anyerror!void {
  var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
  defer arena.deinit();
  const allocator = &arena.allocator;

  var f = try fs.cwd().openFile("foray.fr", fs.File.OpenFlags{ .read = true });
  defer f.close();

  var fSize: usize = try f.getEndPos();
  var src = try allocator.alloc(u8, fSize);
  var bytes_read = try f.readAll(src);

  std.debug.print("Bytes read: {d}\nSource: {s}\n", .{bytes_read, src});

  var tlist = try lexer.lex(allocator, src, bytes_read);
  var prog = try parser.parse(allocator, &tlist);
  var runtime = eval.Runtime.init(allocator);
  try runtime.evaluate(prog);
  runtime.printStack();
}
