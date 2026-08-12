AS      := nasm
ASFLAGS := -f elf64 -I src/ -w+all
LD      := ld
LDFLAGS := --build-id=none -z noexecstack -z separate-code

BIN      := bin/nasmnetd
UNIT     := bin/unit
LIBOBJ   := build/io.o build/str.o build/err.o build/sig.o build/conn.o build/ep.o
OBJ      := build/nasmnetd.o $(LIBOBJ)
UNITOBJ  := build/unit.o $(LIBOBJ)
SMALL    := bin/nasmnetd-small
SMALLOBJ := build/small/nasmnetd.o build/small/io.o build/small/str.o \
            build/small/err.o build/small/sig.o build/small/conn.o \
            build/small/ep.o

PREFIX  ?= /usr/local

.PHONY: all debug clean test unit integration install uninstall

all: $(BIN)

debug:
	$(MAKE) clean
	$(MAKE) ASFLAGS="$(ASFLAGS) -g -F dwarf"

$(BIN): $(OBJ)
	@mkdir -p bin
	$(LD) $(LDFLAGS) -o $@ $(OBJ)

$(UNIT): $(UNITOBJ)
	@mkdir -p bin
	$(LD) $(LDFLAGS) -o $@ $(UNITOBJ)

build/%.o: src/%.asm
	@mkdir -p build
	$(AS) $(ASFLAGS) -o $@ $<

$(SMALL): $(SMALLOBJ)
	@mkdir -p bin
	$(LD) $(LDFLAGS) -o $@ $(SMALLOBJ)

build/small/%.o: src/%.asm
	@mkdir -p build/small
	$(AS) $(ASFLAGS) -DMAX_CONNS=4 -o $@ $<

build/unit.o: tests/unit.asm src/sys.inc
	@mkdir -p build
	$(AS) $(ASFLAGS) -o $@ tests/unit.asm

build/nasmnetd.o: src/nasmnetd.asm src/sys.inc
build/io.o: src/io.asm src/sys.inc
build/sig.o: src/sig.asm src/sys.inc
build/conn.o: src/conn.asm src/sys.inc
build/ep.o: src/ep.asm src/sys.inc

test: unit integration

unit: $(UNIT)
	@$(UNIT)

integration: $(BIN) $(SMALL)
	@tests/run.sh

clean:
	rm -rf build bin

install: $(BIN)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 $(BIN) $(DESTDIR)$(PREFIX)/bin/nasmnetd

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/nasmnetd
