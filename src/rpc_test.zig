const std = @import("std");
const io = std.io;
const warn = std.debug.warn;
const rpc = @import("rpc.zig");
const t = @import("./util/index.zig");

test "Reader" {
    const src = "Content-Length: 43\r\n\r\n{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"example\"}";
    var stream = io.SliceInStream.init(src);
    var rd = rpc.Reader.{ .allocator = std.debug.global_allocator };
    const m = try rd.readStream(&stream.stream);
    if (m.header.content_length != 43) {
        try t.terrorf("expected content_length to be 43 got {} instead\n", m.header.content_length);
    }
}
