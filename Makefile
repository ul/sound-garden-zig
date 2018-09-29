watch:
	mkdir -p target/debug
	watchexec -e zig -- 'zig build-exe main.zig --library soundio --output target/debug/sound-garden && echo "\033[42;1m    d(^.^)b    \033[0m"'

build:
	mkdir -p target/release
	zig build-exe main.zig --library soundio --release-fast --output target/release/sound-garden
