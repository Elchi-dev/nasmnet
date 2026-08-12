# Contributing

Bug reports are welcome, especially anything where the server misbehaves on the
wire. If you can describe the bytes you sent and the bytes you got back, that is
usually enough to reproduce it.

## Before you open a pull request

Run `make test` and make sure both suites pass. Add a test for whatever you
changed. A fix without a test that fails before it and passes after it is hard
to keep, because nothing stops the bug coming back.

Check the return value of every syscall you add. `syscall` puts a negative
errno in `rax` and there is no library underneath to notice a failure for you.
An unchecked call is the most common way something breaks quietly here.

## Debugging a crash

`make debug` rebuilds with dwarf line information. Without it gdb can only tell
you which symbol you were inside and how far into it, which for a routine of
any length is not much. With it you get the line.

```
make debug
gdb ./bin/nasmnetd
```

Remember to `make clean` afterwards, because the object files carry the debug
information and a plain `make` will not rebuild them just because the flags
changed.

Core dumps are worth turning on before you need one. Nothing in the program
enables them, since it is the kernel that writes the file and the shell that
decides whether it is allowed to.

```
ulimit -c unlimited
```

On Arch and anywhere else running systemd the dump goes to the journal rather
than the working directory, and `coredumpctl` is how you reach it:

```
coredumpctl list nasmnetd
coredumpctl gdb nasmnetd
```

Elsewhere `/proc/sys/kernel/core_pattern` decides where the file lands.

A fault with no libc underneath usually means one of a small number of things.
A register that a routine was supposed to preserve and did not, an offset into
a structure that is wrong by a few bytes, or a syscall whose failure went
unchecked and left a negative number being used as a file descriptor or a
pointer.

## Style

Read `docs/adr/0002-register-convention.md` before writing a routine. Arguments
in `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`, return in `rax`, and `rbx`, `rbp`
and `r12` through `r15` are preserved by the routine that uses them.

Comments explain why something is done, not what the instruction does. A line
saying that `mov rax, 1` moves 1 into `rax` is noise. A line explaining that a
syscall wants its fourth argument in `r10` because `syscall` destroys `rcx` is
worth having.

Labels inside a routine start with a dot and are local to it. Exported names
are lower case with underscores.

## Decisions

If a change alters how the project works rather than what it does, add a record
in `docs/adr/`. Copy the shape of an existing one: the context, the decision,
and the consequences including the ones you would rather not admit to.
