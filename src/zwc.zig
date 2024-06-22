const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const unicode = std.unicode;
const ascii = std.ascii;

pub const PrintOptions = enum {
    PrintBytes,
    PrintLines,
    PrintCharacters,
    PrintWords,
    Unset,
};

/// Return value must be deallocated
pub fn run(allocator: Allocator, filename: ?[]const u8, opt: PrintOptions) ![]const u8 {
    var bytes: []u8 = undefined;

    if (filename) |f| {
        bytes = try readFile(allocator, f);
    } else {
        bytes = try readStdin(allocator);
    }
    defer allocator.free(bytes);

    var stat: ?usize = null;

    switch (opt) {
        .PrintBytes => {
            stat = bytes.len;
        },
        .PrintCharacters => {
            stat = try unicode.utf8CountCodepoints(bytes);
        },
        .PrintLines => {
            stat = mem.count(u8, bytes, "\n");
        },
        .PrintWords => {
            stat = countWords(bytes);
        },
        .Unset => {},
    }

    if (filename) |f| {
        if (stat) |s| {
            return std.fmt.allocPrint(allocator, "{d} {s}", .{ s, f });
        } else {
            return try std.fmt.allocPrint(allocator, "{d} {d} {d} {s}", .{ countLines(bytes), countWords(bytes), bytes.len, f });
        }
    } else {
        if (stat) |s| {
            return try std.fmt.allocPrint(allocator, "{d}", .{s});
        } else {
            return try std.fmt.allocPrint(allocator, "{d} {d} {d}", .{ countLines(bytes), countWords(bytes), bytes.len });
        }
    }
}

/// Return value must be deallocated
fn readStdin(allocator: Allocator) ![]u8 {
    var arr = std.ArrayList(u8).init(allocator);

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

/// Return value must be deallocated
fn readFile(allocator: Allocator, filename: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();

    const stat = try file.stat();
    const b = try file.readToEndAlloc(allocator, stat.size);
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
        if (ascii.isWhitespace(c)) {
            if (characterSpotted) {
                characterSpotted = false;
                words += 1;
            }
        } else if (unicode.utf8ValidCodepoint(c) and !characterSpotted) {
            characterSpotted = true;
        }
    }

    if (characterSpotted) {
        words += 1;
    }

    return words;
}

test "expect run to work a as expected" {
    const testContent =
        \\ Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
        \\ incididunt ut labore et dolore magna aliqua. Nisi porta lorem mollis aliquam
        \\ ut porttitor leo. Odio pellentesque diam volutpat commodo sed egestas. Quam
        \\ nulla porttitor massa id neque. Hac habitasse platea dictumst vestibulum
        \\ rhoncus est pellentesque. Quis risus sed vulputate odio ut enim blandit.
        \\ Volutpat blandit aliquam etiam erat. Orci phasellus egestas tellus rutrum
        \\ tellus pellentesque eu. Adipiscing commodo elit at imperdiet dui accumsan
        \\ sit amet nulla. In cursus turpis massa tincidunt dui ut ornare lectus.
        \\ Facilisis mauris sit amet massa vitae tortor condimentum lacinia quis. Nisi
        \\ scelerisque eu ultrices vitae auctor eu augue ut lectus.
    ;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const fixture = try tmp.dir.createFile("readfile_test.txt", .{});
    try fixture.writeAll(testContent);
    fixture.close();

    const fixture_path = try tmp.dir.realpathAlloc(std.testing.allocator, "readfile_test.txt");
    defer std.testing.allocator.free(fixture_path);

    const actual = try run(std.testing.allocator, fixture_path, .Unset);
    defer std.testing.allocator.free(actual);

    var split = std.mem.split(u8, actual, " ");
    try std.testing.expectEqualStrings("10", split.next().?);
    try std.testing.expectEqualStrings("108", split.next().?);
    try std.testing.expectEqualStrings("739", split.next().?);
}

test "expect readFile to read file contents" {
    const testContent =
        \\ Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
        \\ incididunt ut labore et dolore magna aliqua. Nisi porta lorem mollis aliquam
        \\ ut porttitor leo. Odio pellentesque diam volutpat commodo sed egestas. Quam
        \\ nulla porttitor massa id neque. Hac habitasse platea dictumst vestibulum
        \\ rhoncus est pellentesque. Quis risus sed vulputate odio ut enim blandit.
        \\ Volutpat blandit aliquam etiam erat. Orci phasellus egestas tellus rutrum
        \\ tellus pellentesque eu. Adipiscing commodo elit at imperdiet dui accumsan
        \\ sit amet nulla. In cursus turpis massa tincidunt dui ut ornare lectus.
        \\ Facilisis mauris sit amet massa vitae tortor condimentum lacinia quis. Nisi
        \\ scelerisque eu ultrices vitae auctor eu augue ut lectus.
    ;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const fixture = try tmp.dir.createFile("readfile_test.txt", .{});
    try fixture.writeAll(testContent);
    fixture.close();

    const fixture_path = try tmp.dir.realpathAlloc(std.testing.allocator, "readfile_test.txt");
    defer std.testing.allocator.free(fixture_path);

    const actual = try readFile(std.testing.allocator, fixture_path);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings(testContent, actual);
}

test "expect countLines counts lines" {
    const content: []const u8 =
        \\ Hello there.
        \\ This is a multi-line string....
        \\ Yea that's pretty much it...
        \\ Bye!
    ;

    try std.testing.expectEqual(4, countLines(content));
}

test "expect countWords counts words" {
    const content: []const u8 =
        \\ Abracadabra ? No, that's a bit off... Maybe it's Open Sesame ?
        \\ Darn, I forgot the spell...
    ;

    try std.testing.expectEqual(17, countWords(content));
}
