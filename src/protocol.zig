const std = @import("std");
const json = @import("./zson/src/main.zig");
const mem = std.mem;
const warn = std.debug.warn;
const Channel = std.event.Channel;
const ArenaAllocator = std.heap.ArenaAllocator;

pub const json_rpc_version = "2.0";

// JSON is an interface for encoding/decoding json values. We use ArenaAllocator
// here for consistency and making it easy to free memory after the
// encoding/decoding is done..
//
// It is recommended to use the allocator passed for all allocations done by
// memebers which implement this interface.
pub const JSON = struct {
    marshalJSON: fn (self: *JSON, a: *ArenaAllocator) !json.Value,
};

pub const RequestMessage = struct {
    jsonrpc: []const u8,
    id: ID,
    params: ?json.Value,

    pub fn toJson(self: RequestMessage, a: *ArenaAllocator) !json.Value {
        var obj = json.ObjectMap.init(&a.allocator);
        const rpc_version_value = json.Value{ .String = self.jsonrpc };
        const id_value = self.id.toJson(a);
        _ = try obj.put("jsonrpc", rpc_version_value);
        _ = try obj.put("id", id_value);
        if (self.params != null) {
            _ = try obj.put("params", self.params.?);
        }
        return json.Value{ .Object = obj };
    }
};

test "RequestMessage.encode" {
    var b = try std.Buffer.init(std.debug.global_allocator, "");
    var buf = &b;
    defer buf.deinit();
    var stream = &std.io.BufferOutStream.init(buf).stream;

    const req = RequestMessage{
        .jsonrpc = json_rpc_version,
        .id = ID{ .Number = 10 },
        .params = null,
    };
    var arena = ArenaAllocator.init(std.debug.global_allocator);
    const value = try req.toJson(&arena);
    try value.dump(stream);
    warn("{}\n", buf.toSlice());
}

pub const ID = union(enum) {
    String: []const u8,
    Number: i64,
    Null,

    pub fn toJson(self: ID, a: *ArenaAllocator) json.Value {
        switch (self) {
            ID.String => |v| {
                return json.Value{ .String = v };
            },
            ID.Number => |v| {
                return json.Value{ .Integer = v };
            },
            ID.Null => |v| {
                return json.Value.Null;
            },
            else => unreachable,
        }
    }
};

pub const ResponseMessage = struct {
    jsonrpc: []const u8,
    id: ID,
    result: ?json.Value,
    error_value: ?ResponseError,
};

pub const ErrorCode = enum(i64) {
    ParseError = -32700,
    InvalidRequest = -32600,
    MethodNotFound = -32601,
    InvalidParams = -32602,
    InternalError = -32603,
    ServerErrorStart = -32099,
    ServerErrorEnd = -32000,
    ServerNotInitialized = -32002,
    UnknownErrorCode = -32001,
    RequestCancelled = -32800,
};

pub const ResponseError = struct {
    code: ErrorCode,
    message: []const u8,
    data: ?json.Value,
};

pub const NotificationMessage = struct {
    jsonrpc: []const u8,
    id: ID,
    method: []const u8,
    params: ?json.Value,
};

pub const CancelParam = struct {
    id: ID,
};

/// Header is the first part of the lsp protocol message. This is delimited with
/// \r\r.
///
/// It is a must to have at least one field.
pub const Header = struct {
    /// The length of the content part in bytes
    content_length: u64,

    /// The mime type of the content part. Defaults to
    /// application/vscode-jsonrpc; charset=utf-8
    content_type: ?[]const u8,
};

// Message defines a json-rpc message. This consist of a header and content.
// Make sure you cann deinit after you are done with the messsage to freeup
// resources.
pub const Message = struct {
    header: Header,
    content: ?json.ValueTree,
};

pub const MessageChannel = Channel(Message);

// Bus stores async i/o for rpc messages.
pub const Bus = struct {
    in: *MessageChannel,
    out: *MessageChannel,

    pub fn init(loop: *std.event.Loop) anyerror!Bus {
        return Bus{
            .in = try MessageChannel.create(loop, 10),
            .out = try MessageChannel.create(loop, 10),
        };
    }
};
