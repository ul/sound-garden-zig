const std = @import("std");
const warn = std.debug.warn;
const panic = std.debug.panic;
const os = std.os;
const mem = std.mem;
// TODO why doesn't just @import("audio") work?
const audio = @import("audio/index.zig");

const Config = struct {
    with_input: bool,
    backend: ?[]const u8,

    fn init() Config {
        return Config {
            .with_input = false,
            .backend = null,
        };
    }
};

pub fn main() !void {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var arena = std.heap.ArenaAllocator.init(&direct_allocator.allocator);
    defer arena.deinit();

    var config = Config.init();

    const a = &arena.allocator;
    var args = os.args();

    while (args.next(a)) |maybe_arg| {
        const arg = try maybe_arg;
        if (mem.eql(u8, arg, "--with-input")) {
            config.with_input = true;
        } else if (mem.eql(u8, arg, "--backend")) {
            config.backend = try args.next(a) orelse error.InvalidArg;
        }
    }

    const sio = switch (audio.Io.init(config.backend, config.with_input)) {
        audio.Io.Result.Ok  => |x| x,
        audio.Io.Result.Err => |s| panic("{}", s),
    };
    defer sio.deinit();

    var noise = audio.signal.WhiteNoise.init();
    var userdata = audio.stream.UserData.init(&noise.signal);

    const stream = switch (audio.Stream.init(sio, config.with_input, &userdata)) {
        audio.Stream.Result.Ok  => |x| x,
        audio.Stream.Result.Err => |s| panic("{}", s),
    };
    defer stream.deinit();

    while (true) {
        audio.c.soundio_wait_events(sio.sio);
    }
}
