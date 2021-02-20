const std = @import("std");

//const lexer = @import("lexer.zig");
//const parser = @import("parser.zig");
//const eval = @import("eval.zig");
//const eh = @import("error.zig")

pub fn print(comptime T: type, err: T) void {
  std.debug.print("{}\n", .{err});
}
