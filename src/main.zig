const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;

const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const eval = @import("eval.zig");
const eh = @import("error.zig");

pub fn main() anyerror!void {
  var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
  defer arena.deinit();
  const allocator = &arena.allocator;
  const args = try std.process.argsAlloc(allocator);
  defer std.process.argsFree(allocator, args);

  //for(args) |arg,i| {
  //  std.debug.print("{}: {}\n", .{i, arg});
  //}

  if (args.len > 1) {
    //interpreter mode
    var f = try fs.cwd().openFile(args[1], fs.File.OpenFlags{ .read = true });
    defer f.close();

    var fSize: usize = try f.getEndPos();
    var src = try allocator.alloc(u8, fSize);
    var bytes_read = try f.readAll(src);

    //std.debug.print("Bytes read: {d}\nSource: {s}\n", .{bytes_read, src});

    var tlist = lexer.lex(allocator, src, bytes_read) catch |err| {
      eh.print(lexer.LexError, err);
      return err;
    };
    //tlist.print();

    var prog = parser.parse(allocator, &tlist) catch |err| {
      eh.print(parser.ParserError, err);
      return err;
    };
    //parser.printAST(&prog);

    var runtime = try eval.Runtime.init(allocator);
    runtime.evaluate(prog) catch |err| {
      eh.print(eval.EvalError, err);
      return err;
    };
    //runtime.env.print();
    runtime.printStack();
  }
  else {
    //repl mode
    var runtime = try eval.Runtime.init(allocator);
    const stdin = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    var cont = true;
    while (cont) {
      std.debug.print("> ", .{});
      if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |input| {
        //std.debug.print("{}\n", .{input});
        var bytes_read = input.len;
        var tlist = lexer.lex(allocator, input, bytes_read) catch |err| {
          eh.print(lexer.LexError, err);
          if (err == lexer.LexError.InternalError) return err;
          continue;
        };
        //tlist.print();
        var prog = parser.parse(allocator, &tlist) catch |err| {
          eh.print(parser.ParserError, err);
          if (err == parser.ParserError.InternalError) return err;
          continue;
        };
        //parser.printAST(&prog);
        runtime.evaluate(prog) catch |err| {
          eh.print(eval.EvalError, err);
          if (err == eval.EvalError.InternalError) return err;
          //continue;
        };
        //runtime.env.print();
        runtime.printStack();
      }
      else {
        cont = false;
      }
    }
  }
}
