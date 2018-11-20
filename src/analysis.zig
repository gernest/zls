const std = @import("std");
const zig = std.zig;
const warn = std.debug.warn;
const Node = zig.ast.Node;

test "file" {
    const src =
        \\pub const a=1;
        \\pub const b=struct{};
    ;
    var ast = try zig.parse(std.debug.global_allocator, src);
    defer ast.deinit();
    const size = ast.root_node.decls.len;
    var i: usize = 0;
    while (i < size) : (i += 1) {
        var node = ast.root_node.iterate(i);
        if (node != null) {
            switch (node.?.id) {
                Node.Id.VarDecl => {
                    var var_decl = node.?.cast(Node.VarDecl);
                    if (var_decl.?.visib_token) |visib_token| {
                        var tok = ast.tokens.at(visib_token);
                        const v = ast.source[tok.start..tok.end];
                        warn("visib_token ={} {}\n", v, tok);
                    }
                },
                else => {},
            }
        }
    }
}

// File is a parsed single .zig source file.
pub const File = struct {
    name: []const u8,
    package: ?*Package,
    ast: *ast.Tree,
};

/// Package is a collection of .zig source files that are in the same directory.
/// The files don't have to be related, this is a way to organize source files
pub const Package = struct {
    name: []const u8,
    files: ?*FileList,
    allocator: *std.heap.ArenaAllocator,

    pub fn init(a: *mem.Allocator, name: []const u8) Package {}
};

pub const FileList = std.ArrayList(*File);
