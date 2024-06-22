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

    const allocator = arena.allocator();

    var pOption: zwc.PrintOptions = .Unset;
    var ifile: ?[]const u8 = null;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();

    while (args.next()) |arg| {
        if (mem.eql(u8, arg, "-c")) {
            pOption = .PrintBytes;
        } else if (mem.eql(u8, arg, "-l")) {
            pOption = .PrintLines;
        } else if (mem.eql(u8, arg, "-m")) {
            pOption = .PrintCharacters;
        } else if (mem.eql(u8, arg, "-w")) {
            pOption = .PrintWords;
        } else if (mem.eql(u8, arg, "-h")) {
            std.debug.print("{s}\n", .{usage});
            return;
        } else {
            ifile = arg;
        }
    }
    const out = try zwc.run(allocator, ifile, pOption);
    defer allocator.free(out);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n", .{out});
}
