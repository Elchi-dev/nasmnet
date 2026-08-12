AS      := nasm
ASFLAGS := -f elf64 -I src/ -w+all
LD      := ld
LDFLAGS := --build-id=none -z noexecstack -z separate-code

BIN      := bin/nasmnetd
UNIT     := bin/unit
LIBOBJ   := build/io.o build/str.o build/err.o build/sig.o
OBJ      := build/nasmnetd.o $(LIBOBJ)
UNITOBJ  := build/unit.o $(LIBOBJ)

PREFIX  ?= /usr/local

.PHONY: all clean test unit integration install uninstall

all: $(BIN)

$(BIN): $(OBJ)
	@mkdir -p bin
	$(LD) $(LDFLAGS) -o $@ $(OBJ)

$(UNIT): $(UNITOBJ)
	@mkdir -p bin
	$(LD) $(LDFLAGS) -o $@ $(UNITOBJ)

build/%.o: src/%.asm
	@mkdir -p build
	$(AS) $(ASFLAGS) -o $@ $<

build/unit.o: tests/unit.asm src/sys.inc
	@mkdir -p build
	$(AS) $(ASFLAGS) -o $@ tests/unit.asm

build/nasmnetd.o: src/nasmnetd.asm src/sys.inc
build/io.o: src/io.asm src/sys.inc
build/sig.o: src/sig.asm src/sys.inc

test: unit integration

unit: $(UNIT)
	@$(UNIT)

integration: $(BIN)
	@tests/run.sh

clean:
	rm -rf build bin

install: $(BIN)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 $(BIN) $(DESTDIR)$(PREFIX)/bin/nasmnetd

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/nasmnetd
