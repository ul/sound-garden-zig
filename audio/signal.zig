const std = @import("std");
const context = @import("./context.zig");
const Context = context.Context;
const Sample = context.Sample;

const Env = []u8;

pub const Signal = struct {
    sampleFn: SampleFn, 
    label: ?[]const u8,

    const Self = @This();

    const SampleFn = fn (*Self, *Context) Sample;

    fn sample(self: *Signal, ctx: *Context) Sample {
        return self.sampleFn(self, ctx);
    }
};

pub const Silence = struct {
    signal: Signal,

    const Self = @This();

    fn sample(signal: *Signal, ctx: *Context) Sample {
        return 0.0;
    }

    fn init() Self {
        const signal = Signal {
            .sampleFn = sample,
            .label    = "Silence",
        };
        return Self {
            .signal = signal,
        };
    }
};

fn getRandSeed() u64 {
    var buf: [8]u8 = undefined;
    std.os.getRandomBytes(buf[0..]) catch |err| std.debug.panic("{}", @errorName(err));
    return std.mem.readIntLE(u64, buf[0..8]);
}

pub const WhiteNoise = struct {
    signal: Signal,
    rng: std.rand.Random,

    const Self = @This();

    fn sample(signal: *Signal, ctx: *Context) Sample {
        const self = @fieldParentPtr(Self, "signal", signal);
        return self.rng.float(Sample) * 2.0 - 1.0;
    }

    fn init() Self {
        const signal = Signal {
            .sampleFn = sample,
            .label    = "WhiteNoise",
        };

        const rng = std.rand.DefaultPrng.init(getRandSeed());

        return Self {
            .signal = signal,
            .rng    = rng.random,
        };
    }
};
