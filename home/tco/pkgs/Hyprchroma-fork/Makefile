all:
	mkdir -p out
	$(CXX) -shared -fPIC -std=c++2b -O2 src/main.cpp \
	  -o out/hyprchroma.so \
	  $(shell pkg-config --cflags hyprland pixman-1 libdrm) \
	  -DWLR_USE_UNSTABLE

clean:
	rm -rf out

load: unload
	hyprctl plugin load $(shell pwd)/out/hyprchroma.so

unload:
	hyprctl plugin unload $(shell pwd)/out/hyprchroma.so
