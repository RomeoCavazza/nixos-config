PLUGIN_NAME = hypr-canvas

CXX = g++
CXXFLAGS = -shared -fPIC -std=c++2b -O2
CXXFLAGS += $(shell pkg-config --cflags hyprland pixman-1 libdrm)
INCLUDES = -I/usr/include/hyprland

SRC = src/main.cpp src/canvas.cpp
OUT = $(PLUGIN_NAME).so

all: $(OUT)

$(OUT): $(SRC) src/canvas.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) $(SRC) -o $(OUT)

install: $(OUT)
	hyprctl plugin load $(PWD)/$(OUT)

unload:
	hyprctl plugin unload $(PWD)/$(OUT)

reload: $(OUT)
	-hyprctl plugin unload $(PWD)/$(OUT)
	-hyprctl plugin unload /tmp/$(PLUGIN_NAME)-live.so
	cp $(PWD)/$(OUT) /tmp/$(PLUGIN_NAME)-live.so
	hyprctl plugin load /tmp/$(PLUGIN_NAME)-live.so

clean:
	rm -f $(OUT)

.PHONY: all install unload reload clean
