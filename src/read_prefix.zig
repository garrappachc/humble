const std = @import("std");

pub const PacketPrefix = packed struct(u48) {
    type: u16,
    length: u32,
};

pub fn readPrefix(reader: anytype) !PacketPrefix {
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
