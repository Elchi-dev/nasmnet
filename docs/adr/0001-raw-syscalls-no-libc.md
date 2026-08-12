# 0001. Raw syscalls with no libc

Status: Accepted
Date: 2026-08-12

## Context

An assembly program on Linux can reach the kernel in two ways. It can link
against a C library and call `socket`, `bind` and `write` as ordinary
functions, or it can put the arguments in registers and execute `syscall`
itself.

Linking libc is the easier path. It brings `getaddrinfo`, `printf`, `malloc`
and error strings for free, and glibc handles the awkward differences between
architectures.

## Decision

No libc. Every kernel call is made directly with the `syscall` instruction. The
program is linked with `ld` alone and starts at `_start` with no C runtime
underneath it.

## Consequences

The binary is around 13 KB and statically linked against nothing, so it runs on
any x86_64 Linux without a loader, a shared object or a version of glibc that
has to match. A container image can be built `FROM scratch` and contain one
file.

Nothing comes for free. There is no `malloc`, so buffers are fixed size and
live in `.bss`. There is no `printf`, so number formatting is written by hand
in `src/str.asm`. There is no `strerror`, so `src/err.asm` carries its own
table of errno names. There is no `getaddrinfo`, which means hostname
resolution would require writing a DNS client, and that is why the server binds
an address rather than a name.

Errors also arrive in the raw kernel form. `syscall` returns the negative errno
in `rax` instead of setting a separate variable, so every call site checks the
sign of the result. That is more consistent than the libc convention, but it
has to be done every single time, and forgetting once means a failure passes
silently.
