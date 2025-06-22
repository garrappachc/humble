const std = @import("std");
const mumble = @import("proto/MumbleProto.pb.zig");

pub fn authenticate(packet: mumble.Authenticate) !void {
    std.log.info("username: {?}", .{packet.username});
}
