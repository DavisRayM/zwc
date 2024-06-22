const std = @import("std");
const zwc = @import("./root.zig").zwc;
const mem = std.mem;
const ArrayList = std.ArrayList;
const usage =
    \\ zwc - `wc` implementation in zig. Print newline, word and byte count for files.
    \\
    \\ USAGE:
    \\ zwc [OPTIONS] [FILE]
    \\
    \\ OPTIONS:
    \\ -c
    \\      print the byte count
    \\ -l
    \\      print the newline count
    \\ -m
    \\      print the character count
    \\ -w
    \\      print the word count
;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var allocator = arena.allocator();

    var pbytes: bool = false;
    var plines: bool = false;
    var pcharacter: bool = false;
    var pwords: bool = false;

    var ifile: ?[]const u8 = null;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();

    while (args.next()) |arg| {
        if (mem.eql(u8, arg, "-c")) {
            pbytes = true;
        } else if (mem.eql(u8, arg, "-l")) {
            plines = true;
        } else if (mem.eql(u8, arg, "-m")) {
            pcharacter = true;
        } else if (mem.eql(u8, arg, "-w")) {
            pwords = true;
        } else if (mem.eql(u8, arg, "-h")) {
            std.debug.print("{s}\n", .{usage});
            return;
        } else {
            ifile = arg;
        }
    }

    try zwc.run(&allocator, ifile, pbytes, plines, pcharacter, pwords);
}
