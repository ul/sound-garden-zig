const c = @cImport({
    @cInclude("soundio/soundio.h");
});
const std = @import("std");
const mem = std.mem;
const warn = std.debug.warn;
const TResult = @import("./result.zig").Result;
const fmt = @import("./fmt.zig").fmt;
const Io = @import("./io.zig").Io;

fn streamErr(comptime msg: []const u8, err: c_int) Stream.Result {
    return Stream.Result {
        .Err = fmt(msg ++ ": {s}", c.soundio_strerror(err) orelse c"")
    };
}

pub const Stream = struct {
    in : ?*c.SoundIoInStream,
    out:  *c.SoundIoOutStream, 

    const Result = TResult(Stream, []const u8);

    fn init(io: Io, with_input: bool) Result {
        const out = c.soundio_outstream_create(@ptrCast(?[*]c.SoundIoDevice, io.out))
            orelse return streamErr("unable to create out stream", @enumToInt(c.SoundIoErrorNoMem));

        var in: ?*c.SoundIoInStream = null;

        return Result {
            .Ok = Stream {
                .in  = in,
                .out = @ptrCast(*c.SoundIoOutStream, out),
            }
        };
    }

    fn deinit(self: Stream) void {
    }
};
