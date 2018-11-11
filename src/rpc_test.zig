const std = @import("std");
const warn = std.debug.warn;
const rpc = @import("rpc.zig");
const t = @import("./util/index.zig");

test "Reader" {
    const src = "Content-Length: 43\r\n\r\n{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"example\"}";
    var stream = rpc.SliceInStream.init(src);
    var rd = rpc.Reader.{
        .stream = &stream.stream,
        .allocator = std.debug.global_allocator,
    };
    const h = try rd.readHeader();
    if (h.content_length != 43) {
        try t.terrorf("expected content_length to be 43 got {} instead\n", h.content_length);
    }
}
