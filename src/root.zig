const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const unicode = std.unicode;
const ascii = std.ascii;

pub fn run(allocator: *Allocator, filename: ?[]const u8, pbytes: bool, plines: bool, pcharacter: bool, pwords: bool) !void {
    var bytes: []u8 = undefined;

    if (filename) |f| {
        bytes = try readFile(allocator, f);
    } else {
        bytes = try readStdin(allocator);
    }

    const stdout = std.io.getStdOut().writer();
    var stat: usize = undefined;

    if (pbytes) {
        stat = bytes.len;
    } else if (plines) {
        stat = countLines(bytes);
    } else if (pcharacter) {
        stat = try unicode.utf8CountCodepoints(bytes);
    } else if (pwords) {
        stat = countWords(bytes);
    } else {
        if (filename) |f| {
            try stdout.print("{d} {d} {d} {s}\n", .{ countLines(bytes), countWords(bytes), bytes.len, f });
        } else {
            try stdout.print("{d} {d} {d}\n", .{ countLines(bytes), countWords(bytes), bytes.len });
        }
        return;
    }

    if (filename) |f| {
        try stdout.print("{d} {?s}\n", .{ stat, f });
    } else {
        try stdout.print("{d}\n", .{stat});
    }
}

fn readStdin(allocator: *Allocator) ![]u8 {
    var arr = std.ArrayList(u8).init(allocator.*);

    var buffer: [1024]u8 = undefined;
    const stdin = std.io.getStdIn();
    var reader = stdin.reader();

    while (true) {
        const bytes_read = try reader.read(buffer[0..]);

        if (bytes_read == 0) {
            break;
        }

        try arr.appendSlice(buffer[0..bytes_read]);
    }

    return arr.toOwnedSlice();
}

fn readFile(allocator: *Allocator, filename: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();

    const stat = try file.stat();
    const b = try file.readToEndAlloc(allocator.*, stat.size);
    return b;
}

fn countLines(contents: []const u8) usize {
    var lines = std.mem.split(u8, contents, "\n");
    var linec: usize = 0;

    while (lines.next()) |line| {
        if (line.len > 0) {
            linec += 1;
        }
    }

    return linec;
}

fn countWords(contents: []const u8) usize {
    // A word is considered to be a character or characters delimited by white
    // space.
    var characterSpotted = false;
    var words: u64 = 0;

    for (contents) |c| {
        if (c == '\n' or ascii.isWhitespace(c)) {
            if (characterSpotted) {
                characterSpotted = false;
                words += 1;
            }
        } else if (unicode.utf8ValidCodepoint(c) and !characterSpotted) {
            characterSpotted = true;
        }
    }

    return words;
}
