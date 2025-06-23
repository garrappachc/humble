const std = @import("std");
const net = std.net;
const tls = @import("tls");
const mumble = @import("proto/MumbleProto.pb.zig");
const packet = @import("packet.zig");
const Client = @import("client.zig").Client;

pub fn main() !void {
    var auth = try tls.config.CertKeyPair.fromFilePath(std.heap.page_allocator, std.fs.cwd(), ".cert/cert.pem", ".cert/key.pem");
    defer auth.deinit(std.heap.page_allocator);

    const addr = try net.Address.resolveIp("127.0.0.1", 64738);

    var server = try addr.listen(.{});
    std.log.info("listening on port 64738", .{});

    while (true) {
        const client = try server.accept();
        defer client.stream.close();

        std.log.debug("{} connected", .{client.address});

        var conn = tls.server(client.stream, .{ .auth = &auth }) catch |err| {
            std.log.err("tls failed with {}\n", .{err});
            continue;
        };
        defer conn.close() catch |err| std.log.err("tls close() error: {}\n", .{err});

        const c: Client = .{
            .address = client.address,
            .connection = &conn,
            .session_id = 1,
        };

        while (true) {
            packet.readNext(c) catch |err| {
                std.log.err("client error: {}\n", .{err});
                break;
            };
        }
    }
}

test {
    @import("std").testing.refAllDecls(@This());
}
