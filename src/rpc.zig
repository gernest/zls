const std = @import("std");
const os = std.os;
const io = std.io;
const mem = std.mem;
const warn = std.debug.warn;
const assert = std.debug.assert;
const math = std.math;
const proto = @import("protocol.zig");
const builtin = @import("builtin");
const json = @import("./zson/src/main.zig");

pub const ReadError = os.File.ReadError || error{BadInput};
pub const InStream = io.InStream(ReadError);
const default_message_size: usize = 8192;

// content_length is the header key which stoares the length of the message
// content.
const content_length = "Content-Length";

/// Reader defines method for reading rpc messages.
pub const Reader = struct {
    allocator: *mem.Allocator,

    pub fn init(a: *mem.Allocator) Reader {
        return Reader{ .allocator = a };
    }

    /// readStream decodes a rpc message from stream. stream must implement the
    /// io.Instream interface.
    ///
    /// This reads one byte at a time from the stream. No verification of the
    /// message is done , meaning we don't check if the content has the same
    /// length as Content-Length header.
    ///
    /// Convenient for streaming purposes where input can be streamed and decoded
    /// as it flows.
    pub fn readStream(self: *Reader, stream: var) !proto.Message {
        var list = std.ArrayList(u8).init(self.allocator);
        defer list.deinit();
        var header: proto.Header = undefined;
        var message: proto.Message = undefined;
        var crlf = []u8{0} ** 2;
        var in_header = true;
        var end_content_length = false;
        var balanced: usize = 0;
        while (true) {
            const ch = try stream.readByte();
            switch (ch) {
                '\r' => {
                    if (in_header) {
                        crlf[0] = '\r';
                    }
                },
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

                            // clear the buffer, we don't want the content body
                            // to be messed up.
                            try list.resize(0);
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
                    try list.append(ch);
                    balanced -= 1;
                    const v = list.toSlice();
                    if (balanced == 0) {
                        // we are at the end otf the top level json object. We
                        // parse the body too json values.
                        //
                        const buf = list.toOwnedSlice();
                        var p = json.Parser.init(self.allocator, true);
                        var value = try p.parse(buf);
                        message.header = header;
                        message.content = value;
                        return message;
                    }
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
