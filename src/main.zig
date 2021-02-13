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
  const args = try std.process.argsAlloc(allocator);
  defer std.process.argsFree(allocator, args);

  for(args) |arg,i| {
    std.debug.print("{}: {}\n", .{i, arg});
  }

  if (args.len > 1) {
    //interpreter mode
    var f = try fs.cwd().openFile(args[1], fs.File.OpenFlags{ .read = true });
    defer f.close();

    var fSize: usize = try f.getEndPos();
    var src = try allocator.alloc(u8, fSize);
    var bytes_read = try f.readAll(src);

    //std.debug.print("Bytes read: {d}\nSource: {s}\n", .{bytes_read, src});

    var tlist = try lexer.lex(allocator, src, bytes_read);
    //tlist.print();

    var prog = try parser.parse(allocator, &tlist);
    //parser.printAST(&prog);

    var runtime = try eval.Runtime.init(allocator);
    try runtime.evaluate(prog);
    //runtime.env.print();
    runtime.printStack();
  }
  else {
    //repl mode
    var runtime = try eval.Runtime.init(allocator);
    const stdin = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    std.debug.print("> ", .{});
    while (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |input| {
      //std.debug.print("{}\n", .{input});
      var bytes_read = input.len;
      var tlist = try lexer.lex(allocator, input, bytes_read);
      var prog = try parser.parse(allocator, &tlist);
      try runtime.evaluate(prog);
      //runtime.env.print();
      runtime.printStack();

      std.debug.print("> ", .{});
    }
  }
}
