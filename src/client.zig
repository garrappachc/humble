const std = @import("std");
const tls = @import("tls");

pub const Client = struct {
    address: std.net.Address,
    session_id: u32,
    connection: *tls.Connection(std.net.Stream),
};
