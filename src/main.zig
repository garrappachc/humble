const std = @import("std");
const net = std.net;
const tls = @import("tls");
const mumble = @import("proto/MumbleProto.pb.zig");
const Client = @import("client.zig");
const protocol = @import("protocol.zig");
const server = @import("server.zig");

pub fn main() !void {
    var auth = try tls.config.CertKeyPair.fromFilePath(std.heap.page_allocator, std.fs.cwd(), ".cert/cert.pem", ".cert/key.pem");
    defer auth.deinit(std.heap.page_allocator);

    const addr = try net.Address.resolveIp("127.0.0.1", 64738);

    var s = try addr.listen(.{});
    std.log.info("listening on port 64738", .{});

    while (true) {
        const client = try s.accept();
        defer client.stream.close();

        std.log.debug("{} connected", .{client.address});

        var conn = tls.server(client.stream, .{ .auth = &auth }) catch |err| {
            std.log.err("tls failed with {}\n", .{err});
            continue;
        };
        defer conn.close() catch |err| std.log.err("tls close() error: {}\n", .{err});

        var c = Client.init(client.address, &conn);

        while (true) {
            readNext(&c) catch |err| {
                std.log.err("{}\n", .{err});
                break;
            };
        }
    }
}

const Error = error{
    ClientDisconnected,
};

fn readNext(client: *Client.Client) !void {
    const reader = client.connection.reader();
    const prefix = readPrefix(reader) catch |err| {
        if (err == error.EndOfStream) {
            return Error.ClientDisconnected;
        }
        return;
    };
    std.log.debug("packet type: {d}, packet length: {d}", .{ prefix.type, prefix.length });

    if (prefix.length > 0) {
        const a = std.heap.page_allocator;
        const data = try a.alloc(u8, prefix.length);
        defer a.free(data);

        const read = try reader.readAtLeast(data, prefix.length);
        if (read < prefix.length) {
            return Error.ClientDisconnected;
        }

        try readAndHandle(client, prefix, data);
    }
}

const PacketPrefix = packed struct(u48) {
    type: u16,
    length: u32,
};

fn readPrefix(reader: anytype) !PacketPrefix {
    const prefix_length = 6;
    var buf: [prefix_length]u8 = undefined;
    _ = try reader.readAtLeast(&buf, prefix_length);

    const packet_type = std.mem.readInt(u16, buf[0..2], .big);
    const packet_length = std.mem.readInt(u32, buf[2..6], .big);
    return PacketPrefix{ .length = packet_length, .type = packet_type };
}

test "readPrefix" {
    const testing = std.testing;

    const data = [_]u8{ 0x00, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00 };
    var reader = std.io.fixedBufferStream(&data);

    const prefix = try readPrefix(reader.reader());
    try testing.expect(prefix.type == 1);
    try testing.expect(prefix.length == 16);
}

fn readAndHandle(client: *Client.Client, prefix: PacketPrefix, data: []u8) !void {
    switch (prefix.type) {
        2 => {
            const packet = try mumble.Authenticate.decode(data, std.heap.page_allocator);
            try server.authenticate(client, packet);
        },
        3 => {
            const packet = try mumble.Ping.decode(data, std.heap.page_allocator);
            try server.pong(client, packet);
        },
        else => {
            std.log.warn("unhandled packet type: {}", .{prefix.type});
            return;
        },
    }
}

test {
    @import("std").testing.refAllDecls(@This());
}
