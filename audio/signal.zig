const std = @import("std");
const mem = std.mem;
const math = std.math;
const DefaultPrng = std.rand.DefaultPrng;
const context = @import("./context.zig");
const Context = context.Context;
const Sample = context.Sample;

pub const max_channels = 2;

pub const silence = zero;
pub const zero = Constant.init(0);
pub const one = Constant.init(1);

pub const Signal = struct {
    sampleFn: SampleFn, 
    label   : ?[]const u8,

    const Self = @This();

    const SampleFn = fn (*Self, *Context) Sample;

    fn sample(self: *Signal, ctx: *Context) Sample {
        return self.sampleFn(self, ctx);
    }
};

pub const Constant = struct {
    signal: Signal,
    x     : Sample,

    const Self = @This();

    fn sample(signal: *Signal, ctx: *Context) Sample {
        const self = @fieldParentPtr(Self, "signal", signal);
        return self.x;
    }

    fn init(x: Sample) Self {
        const signal = Signal {
            .sampleFn = sample,
            .label    = "Constant",
        };

        return Self {
            .signal = signal,
            .x      = x,
        };
    }
};

pub const WhiteNoise = struct {
    signal: Signal,
    rng   : DefaultPrng,

    const Self = @This();

    fn sample(signal: *Signal, ctx: *Context) Sample {
        const self = @fieldParentPtr(Self, "signal", signal);
        return self.rng.random.float(Sample) * 2 - 1;
    }

    fn init() Self {
        const signal = Signal {
            .sampleFn = sample,
            .label    = "WhiteNoise",
        };

        return Self {
            .signal = signal,
            .rng    = DefaultPrng.init(getRandSeed()),
        };
    }
};

pub const Phasor = struct {
    signal: Signal,
    phases: [max_channels]Sample,
    freq  : *Signal,
    phase0: *Signal,

    const Self = @This();

    fn sample(signal: *Signal, ctx: *Context) Sample {
        const self = @fieldParentPtr(Self, "signal", signal);
        const i = ctx.channel;
        self.phases[i] = @mod(self.phases[i] + 2 * self.freq.sample(ctx) / ctx.sample_rate_float, 2);
        const p0 = self.phase0.sample(ctx) + 1; 
        return @mod(p0 + self.phases[i], 2) - 1;
    }

    fn init(freq: *Signal, phase0: *Signal) Self {
        const signal = Signal {
            .sampleFn = sample,
            .label    = "Phasor",
        };

        return Self {
            .signal = signal,
            .phases = []Sample{0} ** max_channels,
            .freq   = freq,
            .phase0 = phase0,
        };
    }
};

pub const Sine = struct {
    signal: Signal,
    phasor: Phasor,

    const Self = @This();

    fn sample(signal: *Signal, ctx: *Context) Sample {
        const self = @fieldParentPtr(Self, "signal", signal);
        return math.sin(math.pi * self.phasor.signal.sample(ctx));
    }

    fn init(freq: *Signal, phase0: *Signal) Self {
        const signal = Signal {
            .sampleFn = sample,
            .label    = "Sine",
        };

        return Self {
            .signal = signal,
            .phasor = Phasor.init(freq, phase0),
        };
    }
};

fn getRandSeed() u64 {
    var buf: [8]u8 = undefined;
    std.os.getRandomBytes(buf[0..]) catch |err| std.debug.panic("{}", @errorName(err));
    return mem.readIntLE(u64, buf[0..8]);
}

