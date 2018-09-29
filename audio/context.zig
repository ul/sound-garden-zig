pub const Sample = f64;

pub const Context = struct {
    channel       : i8,
    sample_number : i64,
    sample_rate   : i64,
    input         : Sample,
};
