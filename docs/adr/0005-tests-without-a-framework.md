# 0005. Tests without a framework

Status: Accepted
Date: 2026-08-12

## Context

The tests need to drive a real socket, send bytes and check what comes back.
The usual answer is a few lines of Python, which is on every developer machine
and every CI runner and handles binary data and threads without complaint.

The project otherwise has two build dependencies, `nasm` and `ld`. Adding a
language runtime to run the tests would make it three, and it would be the
largest of them by several orders of magnitude.

## Decision

No test framework and no scripting language. Unit tests are a second assembly
binary linked against the same object files as the server. Integration tests
are a bash script that opens sockets with the `/dev/tcp` redirection built into
bash.

## Consequences

Anyone who can build the project can run its tests, and the CI job installs
nothing beyond the assembler. The unit tests exercise the helper routines
through exactly the same calling convention the server uses, so they catch a
register that a routine forgot to preserve, which a test written in another
language could not see.

`/dev/tcp` turns out to be enough. Binary payloads work by redirecting `cat`,
and the one case that needs reading and writing at the same time, a payload
larger than the socket buffers, works by backgrounding the reader. Writing the
harness this way did find one thing worth knowing: an echo server that is not
being read from while it is being written to will deadlock against its client
once both buffers fill, which is a property of the protocol rather than a bug,
and the test now reflects it.

The limits are real. There is no mocking, so a syscall failure cannot be forced
and the error paths for `socket` and `listen` are only reachable by argument,
not by test. Assertions in the unit binary are hand written, and a case that is
never called is never noticed. `/dev/tcp` also needs bash specifically, not any
POSIX shell, which the CI job pins.

The v1.2 client binary replaces most of the bash with a tool written in the
same assembly, which removes the last shell dependency from the wire tests and
ships something useful at the same time.
