const std = @import("std");
const os = std.os;
const io = std.io;
const mem = std.mem;
const warn = std.debug.warn;
const math = std.math;
const proto = @import("protocol.zig");
const builtin = @import("builtin");

pub const ReadError = os.File.ReadError || error.{BadInput};
pub const InStream = io.InStream(ReadError);
const default_message_size: usize = 8192;

// content_length is the header key which stoares the length of the message
// content.
const content_length = "Content-Length";

pub const Reader = struct.{
    stream: *InStream,
    allocator: *mem.Allocator,

    pub fn readHeader(self: *Reader) !proto.Header {
        var list = std.ArrayList(u8).init(self.allocator);
        var header: proto.Header = undefined;
        var crlf = []u8.{0} ** 2;
        var in_header = true;
        var end_content_length = false;
        var balanced: usize = 0;
        while (true) {
            const ch = try self.stream.readByte();
            switch (ch) {
                '\r' => if (in_header) crlf[0] = '\r',
                '\n' => {
                    if (in_header) {
                        if (crlf[0] != '\r') {
                            return error.BadInput;
                        }
                        // we have reached delimiter now
                        crlf[1] = crlf[1] + 1;
                        crlf[0] = 0;
                        if (end_content_length) {
                            const s = list.toSlice();
                            const v = try std.fmt.parseInt(u64, s, 10);
                            header.content_length = v;
                            end_content_length = false;
                        }
                    }
                },
                '{' => {
                    if (crlf[1] == 0) {
                        // we are not supposed to encounter message body before
                        // any headers.
                        return error.BadInput;
                    }

                    // remove in_header state the content body begins here. It is
                    // better to add the check here so we can have flexibility
                    // for changes which might add more headers.
                    if (in_header) in_header = false;
                    try list.append(ch);
                    balanced += 1;
                },
                ':' => {
                    if (in_header) {
                        const h = list.toOwnedSlice();
                        if (mem.eql(u8, h, content_length)) {
                            end_content_length = true;
                        } else {
                            return error.BadInput;
                        }
                    } else {
                        try list.append(ch);
                    }
                },
                '}' => {
                    balanced -= 1;
                    if (balanced == 0) return header;
                },
                else => {
                    // skip spaces in the header section to avoid trimming
                    // spaces before reading values.
                    if (in_header and ch == ' ') continue;
                    try list.append(ch);
                },
            }
        }
    }
};

// SliceInStream  implements io.InStream but reads from a slice.
pub const SliceInStream = struct.{
    const Self = @This();
    pub stream: InStream,
    pos: usize,
    slice: []const u8,

    pub fn init(slice: []const u8) Self {
        return Self.{
            .slice = slice,
            .pos = 0,
            .stream = InStream.{ .readFn = readFn },
        };
    }

    fn readFn(in_stream: *InStream, dest: []u8) ReadError!usize {
        const self = @fieldParentPtr(Self, "stream", in_stream);
        const size = math.min(dest.len, self.slice.len - self.pos);
        const end = self.pos + size;

        mem.copy(u8, dest[0..size], self.slice[self.pos..end]);
        self.pos = end;

        return size;
    }
};
