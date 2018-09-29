pub fn Result(comptime T: type, E: type) type {
    return union(enum) {
        Ok: T,
        Err: E 
    };
}

