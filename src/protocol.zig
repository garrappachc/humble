const std = @import("std");
const mumble = @import("proto/MumbleProto.pb.zig");

// order is important
// https://github.com/mumble-voip/mumble/blob/master/docs/dev/network-protocol/protocol_stack_tcp.md
const packets = .{ mumble.Version, mumble.UDPTunnel, mumble.Authenticate, mumble.Ping, mumble.Reject, mumble.ServerSync, mumble.ChannelRemove, mumble.ChannelState, mumble.UserRemove, mumble.UserState, mumble.BanList, mumble.TextMessage, mumble.PermissionDenied, mumble.ACL, mumble.QueryUsers, mumble.CryptSetup, mumble.ContextActionModify, mumble.ContextAction, mumble.UserList, mumble.VoiceTarget, mumble.PermissionQuery, mumble.CodecVersion, mumble.UserStats, mumble.RequestBlob, mumble.ServerConfig, mumble.SuggestConfig };

pub const PacketTypeError = error{
    UnknownPacketType,
};

pub fn packetTypeNumber(comptime packet_type: type) PacketTypeError!u16 {
    comptime var i = 0;
    return inline while (i < packets.len) : (i += 1) {
        if (packets[i] == packet_type) {
            break i;
        }
    } else return PacketTypeError.UnknownPacketType;
}
