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

pub const Sine = oscillator(sine, "Sine");
pub const Cosine = oscillator(cosine, "Cosine");
pub const Tri = oscillator(triangle, "Tri");

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

pub const Multicast = struct {
    signal        : Signal,
    samples       : [max_channels]Sample,
    sample_numbers: [max_channels]usize,
    x             : *Signal,

    const Self = @This();

    fn sample(signal: *Signal, ctx: *Context) Sample {
        const self = @fieldParentPtr(Self, "signal", signal);
        const i = ctx.channel;
        if (ctx.sample_number > self.sample_numbers[i]) {
            self.sample_numbers[i] = ctx.sample_number;
            self.samples[i] = self.x.sample(ctx);
        }
        return self.samples[i];
    }

    fn init(x: *Signal) Self {
        const signal = Signal {
            .sampleFn = sample,
            .label    = x.label,
        };

        return Self {
            .signal         = signal,
            .samples        = []Sample{0} ** max_channels,
            .sample_numbers = []usize{0} ** max_channels,
            .x              = x,
        };
    }
};

fn sine(phase: Sample) Sample {
    return math.sin(math.pi * phase); 
}

fn cosine(phase: Sample) Sample {
    return math.cos(math.pi * phase); 
}

fn triangle(phase: Sample) Sample {
    const x = 2 * phase; 
    if (x > 0) {
        return 1.0 - x;
    } else {
        return 1.0 + x;
    }
}

pub fn oscillator(f: fn (Sample) Sample, label: []const u8) type {
    return struct {
        signal: Signal,
        phasor: Phasor,

        const Self = @This();

        fn sample(signal: *Signal, ctx: *Context) Sample {
            const self = @fieldParentPtr(Self, "signal", signal);
            return f(self.phasor.signal.sample(ctx));
        }

        fn init(freq: *Signal, phase0: *Signal) Self {
            const signal = Signal {
                .sampleFn = sample,
                .label    = label,
            };

            return Self {
                .signal = signal,
                .phasor = Phasor.init(freq, phase0),
            };
        }
    };
}

fn getRandSeed() u64 {
    var buf: [8]u8 = undefined;
    std.os.getRandomBytes(buf[0..]) catch |err| std.debug.panic("{}", @errorName(err));
    return mem.readIntLE(u64, buf[0..8]);
}

