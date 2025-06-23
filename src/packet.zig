const std = @import("std");
const mumble = @import("proto/MumbleProto.pb.zig");
const authenticate = @import("authenticate.zig").authenticate;
const Client = @import("client.zig").Client;

const handlers = .{ .{ mumble.Version, null }, .{ mumble.UDPTunnel, null }, .{ mumble.Authenticate, authenticate } };

pub const Error = error{
    ClientDisconnected,
};

pub fn readNext(client: Client) !void {
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

        try readAndHandle(prefix, data);
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

fn readAndHandle(prefix: PacketPrefix, data: []u8) !void {
    switch (prefix.type) {
        inline 0...handlers.len - 1 => |i| {
            const packetType, const handler = handlers[i];
            if (@TypeOf(handler) == @TypeOf(null)) {
                return;
            }

            const packet = try packetType.decode(data, std.heap.page_allocator);
            try handler(packet);
        },
        else => {},
    }
}
