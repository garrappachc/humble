const std = @import("std");
const net = std.net;
const tls = @import("tls");
const readPrefix = @import("read_prefix.zig").readPrefix;
const mumble = @import("proto/MumbleProto.pb.zig");
const packet = @import("packet.zig");

pub fn main() !void {
    var auth = try tls.config.CertKeyPair.fromFilePath(std.heap.page_allocator, std.fs.cwd(), ".cert/cert.pem", ".cert/key.pem");
    defer auth.deinit(std.heap.page_allocator);

    const addr = try net.Address.resolveIp("127.0.0.1", 64738);

    var server = try addr.listen(.{});
    std.log.info("listening on port 64738", .{});

    while (true) {
        const client = try server.accept();
        defer client.stream.close();

        var conn = tls.server(client.stream, .{ .auth = &auth }) catch |err| {
            std.debug.print("tls failed with {}\n", .{err});
            continue;
        };

        const client_reader = conn.reader();
        // const client_writer = client.stream.writer();

        while (true) {
            const prefix = readPrefix(client_reader) catch |err| {
                if (err == error.EndOfStream) {
                    std.log.info("client disconnected", .{});
                    break;
                } else {
                    std.log.err("error reading packet prefix: {}", .{err});
                    break;
                }
            };
            std.log.info("packet type: {d}, packet length: {d}", .{ prefix.type, prefix.length });

            if (prefix.length > 0) {
                // const data = try client_reader.readAllAlloc(std.heap.page_allocator, prefix.length);

                const a = std.heap.page_allocator;
                const data = try a.alloc(u8, prefix.length);
                defer a.free(data);

                const read = try client_reader.readAtLeast(data, prefix.length);
                if (read < prefix.length) {
                    std.log.info("client disconnected", .{});
                    break;
                }

                try packet.read_and_handle(prefix, data);
            }
        }
    }
}

test {
    @import("std").testing.refAllDecls(@This());
}
