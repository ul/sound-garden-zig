pub const Sample = f64;

pub const Context = struct {
    channel          : usize,
    sample_number    : usize,
    sample_rate      : usize,
    sample_rate_float: Sample,
    input            : Sample,
};
