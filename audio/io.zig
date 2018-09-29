const std = @import("std");
const mem = std.mem;
const warn = std.debug.warn;
const c = @import("./c.zig").c;
const TResult = @import("./result.zig").Result;
const fmt = @import("./fmt.zig").fmt;

fn ioErr(comptime msg: []const u8, err: c_int) Io.Result {
    return Io.Result {
        .Err = fmt(msg ++ ": {s}", c.soundio_strerror(err) orelse c"")
    };
}

pub const Io = struct {
    sio: ?[*]c.SoundIo,
    in : ?*c.SoundIoDevice,
    out:  *c.SoundIoDevice, 

    const Result = TResult(Io, []const u8);

    fn init(backend: ?[]const u8, with_input: bool) Result {
        const s = c.soundio_create()
            orelse return ioErr("unable to create soundio", @enumToInt(c.SoundIoErrorNoMem));
        var err: c_int = 0;

        if (backend) |tag| {
            var b = c.SoundIoBackendDummy;
            if (mem.eql(u8, tag, "coreaudio")) {
                b = c.SoundIoBackendCoreAudio;
            } else if (mem.eql(u8, tag, "jack")) {
                b = c.SoundIoBackendJack;
            } else if (mem.eql(u8, tag, "pulseaudio")) {
                b = c.SoundIoBackendPulseAudio;
            } else if (mem.eql(u8, tag, "alsa")) {
                b = c.SoundIoBackendAlsa;
            }
            err = c.soundio_connect_backend(s, b);
        } else {
            err = c.soundio_connect(s);    
        }
        
        if (err > 0) {
            return ioErr("unable to connect to backend", err);
        }

        c.soundio_flush_events(s);

        const out_dev_id = c.soundio_default_output_device_index(s);

        if (out_dev_id < 0) {
            return ioErr("output device not found", @enumToInt(c.SoundIoErrorNoSuchDevice));
        }

        const out_dev = c.soundio_get_output_device(s, out_dev_id)
            orelse return ioErr("", @enumToInt(c.SoundIoErrorNoMem));

        if (out_dev.*.probe_error > 0) {
            c.soundio_device_unref(out_dev);
            return ioErr("cannot probe device", out_dev.*.probe_error);
        }

        var in: ?*c.SoundIoDevice = null;

        if (with_input) {
            const in_dev_id = c.soundio_default_output_device_index(s);

            if (in_dev_id < 0) {
                return ioErr("input device not found", @enumToInt(c.SoundIoErrorNoSuchDevice));
            }

            const in_dev = c.soundio_get_output_device(s, in_dev_id)
                orelse return ioErr("", @enumToInt(c.SoundIoErrorNoMem));

            if (in_dev.*.probe_error > 0) {
                c.soundio_device_unref(in_dev);
                return ioErr("cannot probe device", in_dev.*.probe_error);
            }

            in = @ptrCast(*c.SoundIoDevice, in_dev);
        }

        return Result {
            .Ok = Io {
                .sio = s,
                .in  = in,
                .out = @ptrCast(*c.SoundIoDevice, out_dev),
            }
        };
    }

    fn deinit(self: Io) void {
        if (self.in) |in| {
            c.soundio_device_unref(@ptrCast(?[*]c.SoundIoDevice, in));
        }
        c.soundio_device_unref(@ptrCast(?[*]c.SoundIoDevice, self.out));
        c.soundio_destroy(self.sio);
    }
};

