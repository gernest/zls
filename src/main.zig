const std = @import("std");
const protocol = @import("protocol.zig");
const io = std.io;

pub fn main() error!void {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const allocator = &da.allocator;

    var loop: std.event.Loop = undefined;
    try loop.initSingleThreaded(allocator);
    defer loop.deinit();
    var bus = try protocol.Bus.init(&loop);
    const sync_handle = try async<allocator> sync(&bus);
    defer cancel sync_handle;

    const read_handle = try async<allocator> read(&bus);
    defer cancel read_handle;

    loop.run();
}

async fn sync(bus: *protocol.Bus) error!void {
    var out_file = try std.io.getStdOut();
    defer out_file.close();
    var stream = &out_file.outStream().stream;

    while (true) {
        const msg = await (try async bus.out.get());
        try stream.print("{}\n", msg.header.content_length);
    }
}

async fn read(bus: *protocol.Bus) error!void {
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        const msg = protocol.Message.{
            .header = protocol.Header.{
                .content_length = @intCast(u64, i),
                .content_type = null,
            },
            .content = null,
        };
        await (try async bus.out.put(msg));
    }
}
