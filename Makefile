AS      := nasm
ASFLAGS := -f elf64 -I src/ -w+all
LD      := ld
LDFLAGS := --build-id=none -z noexecstack -z separate-code

BIN     := bin/nasmnetd
OBJ     := build/nasmnetd.o build/io.o build/str.o build/err.o

PREFIX  ?= /usr/local

.PHONY: all clean install uninstall

all: $(BIN)

$(BIN): $(OBJ)
	@mkdir -p bin
	$(LD) $(LDFLAGS) -o $@ $(OBJ)

build/%.o: src/%.asm
	@mkdir -p build
	$(AS) $(ASFLAGS) -o $@ $<

build/nasmnetd.o: src/nasmnetd.asm src/sys.inc
build/io.o: src/io.asm src/sys.inc

clean:
	rm -rf build bin

install: $(BIN)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 $(BIN) $(DESTDIR)$(PREFIX)/bin/nasmnetd

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/nasmnetd
