const std = @import("std");
const tls = @import("tls");
const mumble = @import("proto/MumbleProto.pb.zig");
const protocol = @import("protocol.zig");

pub fn init(address: std.net.Address, connection: *tls.Connection(std.net.Stream)) Client {
    return .{
        .address = address,
        .connection = connection,
        .session_id = 1,
    };
}

const SendError = error{
    UnknownPacketType,
};

pub const Client = struct {
    address: std.net.Address,
    session_id: u32,
    connection: *tls.Connection(std.net.Stream),
    username: ?[]u8 = null,

    pub fn send(self: *Client, packet: anytype) !void {
        const packet_type_number = try protocol.packetTypeNumber(@TypeOf(packet));
        const data = try packet.encode(std.heap.page_allocator);
        defer std.heap.page_allocator.free(data);
        var prefix: [6]u8 = undefined;
        std.mem.writeInt(u16, prefix[0..2], packet_type_number, .big);
        std.mem.writeInt(u32, prefix[2..], @intCast(data.len), .big);
        try self.connection.writeAll(&prefix);
        try self.connection.writeAll(data);
    }
};
