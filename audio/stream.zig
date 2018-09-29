const std = @import("std");
const mem = std.mem;
const warn = std.debug.warn;
const panic = std.debug.panic;
const c = @import("./c.zig").c;
const Context = @import("./context.zig").Context;
const signal = @import("./signal.zig");
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

        var userdata = UserData.init();

        out.*.format = c.SoundIoFormatFloat32NE;
        out.*.write_callback = writeCallback;
        out.*.userdata = @ptrCast(?*c_void, &userdata);

        var err: c_int = 0;

        err = c.soundio_outstream_open(out);
        if (err > 0) {
            return streamErr("unable to open out stream", err);
        }
        if (out.*.layout_error > 0) {
            return streamErr("unable to set out stream channel layout", out.*.layout_error);
        }

        err = c.soundio_outstream_start(out);
        if (err > 0) {
            return streamErr("unable to start out stream", err);
        }

        var in : ?*c.SoundIoInStream = null;

        if (with_input) {
            // TODO
        }

        return Result {
            .Ok = Stream {
                .in  = in,
                .out = @ptrCast(*c.SoundIoOutStream, out),
            }
        };
    }

    fn deinit(self: Stream) void {
        // TODO double-check in which order we want to destroy streams
        // for less problems with ring buffer caused by over/underflow
        c.soundio_outstream_destroy(@ptrCast(?[*]c.SoundIoOutStream, self.out));
        if (self.in) |in| {
            c.soundio_instream_destroy(@ptrCast(?[*]c.SoundIoInStream, self.in));
        }
    }
};

const UserData = struct {
    context: Context,
    signal: signal.Signal,

    fn init() UserData {
        const context = Context {
            .channel       = 0,
            .sample_number = 0,
            .sample_rate   = 0,
            .input         = 0.0
        };
        return UserData {
            .context = context,
            .signal = signal.WhiteNoise.init().signal,
        };
    }
};

extern fn writeCallback(
    maybe_outstream: ?[*]c.SoundIoOutStream,
    frame_count_min: c_int,
    frame_count_max: c_int,
) void {
    const outstream = @ptrCast(*c.SoundIoOutStream, maybe_outstream);
    var userdata: UserData = @ptrCast(*UserData, @alignCast(@alignOf(UserData), outstream.userdata)).*;
    const layout = &outstream.layout;
    const float_sample_rate = @intToFloat(f64, outstream.sample_rate);
    const seconds_per_frame = 1.0 / float_sample_rate;
    var frames_left = frame_count_max;

    while (frames_left > 0) {
        var frame_count = frames_left;

        var areas: [*]c.SoundIoChannelArea = undefined;
        sio_err(c.soundio_outstream_begin_write(
            maybe_outstream,
            @ptrCast([*]?[*]c.SoundIoChannelArea, &areas),
            (*[1]c_int)(&frame_count),
        )) catch |err| panic("write failed: {}", @errorName(err));

        if (frame_count == 0) break;

        var frame: c_int = 0;
        while (frame < frame_count) : (frame += 1) {
            var channel: usize = 0;
            while (channel < @intCast(usize, layout.channel_count)) : (channel += 1) {
                const sample = @floatCast(f32, (&userdata.signal).sample(&userdata.context));
                const channel_ptr = areas[channel].ptr.?;
                const sample_ptr = &channel_ptr[@intCast(usize, areas[channel].step * frame)];
                @ptrCast(*f32, @alignCast(@alignOf(f32), sample_ptr)).* = sample;
            }
        }

        sio_err(c.soundio_outstream_end_write(maybe_outstream))
            catch |err| panic("end write failed: {}", @errorName(err));

        frames_left -= frame_count;
    }
}

fn sio_err(err: c_int) !void {
    switch (@intToEnum(c.SoundIoError, err)) {
        c.SoundIoError.None => {},
        c.SoundIoError.NoMem => return error.NoMem,
        c.SoundIoError.InitAudioBackend => return error.InitAudioBackend,
        c.SoundIoError.SystemResources => return error.SystemResources,
        c.SoundIoError.OpeningDevice => return error.OpeningDevice,
        c.SoundIoError.NoSuchDevice => return error.NoSuchDevice,
        c.SoundIoError.Invalid => return error.Invalid,
        c.SoundIoError.BackendUnavailable => return error.BackendUnavailable,
        c.SoundIoError.Streaming => return error.Streaming,
        c.SoundIoError.IncompatibleDevice => return error.IncompatibleDevice,
        c.SoundIoError.NoSuchClient => return error.NoSuchClient,
        c.SoundIoError.IncompatibleBackend => return error.IncompatibleBackend,
        c.SoundIoError.BackendDisconnected => return error.BackendDisconnected,
        c.SoundIoError.Interrupted => return error.Interrupted,
        c.SoundIoError.Underflow => return error.Underflow,
        c.SoundIoError.EncodingString => return error.EncodingString,
    }
}
