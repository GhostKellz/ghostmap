const std = @import("std");
const ghostmap = @import("ghostmap");

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // Demonstrate the library
    const point = try ghostmap.Point.init(40.7128, -74.0060);
    std.debug.print("Created point: lat={d}, lng={d}\n", .{ point.lat, point.lng });

    const mercator = ghostmap.projectToWebMercator(point);
    std.debug.print("Web Mercator: x={d}, y={d}\n", .{ mercator.x, mercator.y });

    const rome = try ghostmap.Point.init(41.8919300, 12.5113300);
    const distance = point.distance(rome);
    std.debug.print("Distance to Rome: {d} km\n", .{distance});
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
