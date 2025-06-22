const std = @import("std");
const mumble = @import("proto/MumbleProto.pb.zig");
const authenticate = @import("authenticate.zig").authenticate;
const PacketPrefix = @import("read_prefix.zig").PacketPrefix;

const handlers = .{ .{ mumble.Version, null }, .{ mumble.UDPTunnel, null }, .{ mumble.Authenticate, authenticate } };

pub fn read_and_handle(prefix: PacketPrefix, data: []u8) !void {
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
