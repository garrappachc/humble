const std = @import("std");
const mumble = @import("proto/MumbleProto.pb.zig");
const protobuf = @import("protobuf");
const Client = @import("client.zig").Client;

pub fn authenticate(client: *Client, packet: mumble.Authenticate) !void {
    if (packet.username) |username| {
        std.log.debug("user {s} authenticated", .{username.getSlice()});
        client.username = try std.heap.page_allocator.alloc(u8, username.getSlice().len);
        @memcpy(client.username.?, username.getSlice());

        var userState = mumble.UserState.init(std.heap.page_allocator);
        defer userState.deinit();

        userState.session = client.session_id;
        userState.name = protobuf.ManagedString.managed(client.username orelse unreachable);
        userState.channel_id = 1;
        userState.suppress = false;

        try client.send(userState);

        var serverSync = mumble.ServerSync.init(std.heap.page_allocator);
        defer serverSync.deinit();

        serverSync.session = client.session_id;
        serverSync.max_bandwidth = 76000;
        serverSync.welcome_text = protobuf.ManagedString.static("dupa!\n");
        // serverSync.permissions = 0;

        try client.send(serverSync);
    }
}

pub fn pong(client: *Client, ping: mumble.Ping) !void {
    if (ping.timestamp) |_| {
        const p = try ping.dupe(std.heap.page_allocator);
        try client.send(p);
    }
}
