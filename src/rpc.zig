const std = @import("std");
const os = std.os;
const io = std.io;
const mem = std.mem;
const proto = @import("protocol.zig");

pub const ReadError = os.File.ReadError;

pub const InStream = io.InStream(ReadError);

pub const Reader = struct.{
    stream: *InStream,
    allocator: *mem.Allocator,
    pub fn readMessage(self: *Reader) !proto.Message {}
};

// SliceInStream  implements io.InStream but reads from a slice.
pub const SliceInStream = struct.{
    const Self = @This();
    pub stream: Stream,
    pos: usize,
    slice: []const u8,

    pub fn init(slice: []const u8) Self {
        return Self.{
            .slice = slice,
            .pos = 0,
            .stream = Stream.{ .readFn = readFn },
        };
    }

    fn readFn(in_stream: *Stream, dest: []u8) Error!usize {
        const self = @fieldParentPtr(Self, "stream", in_stream);
        const size = math.min(dest.len, self.slice.len - self.pos);
        const end = self.pos + size;

        mem.copy(u8, dest[0..size], self.slice[self.pos..end]);
        self.pos = end;

        return size;
    }
};
