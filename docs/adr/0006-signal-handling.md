# 0006. Signal handling with a flag rather than work in the handler

Status: Accepted
Date: 2026-08-12

## Context

A server that runs until it is stopped has to deal with three signals. SIGPIPE
arrives when it writes to a socket the peer has reset, and the default
behaviour is to terminate the process, so one client leaving at the wrong
moment takes the server down. SIGINT and SIGTERM are how anyone stops it, and
the default for both is to die immediately, leaving the listening socket to be
cleaned up by the kernel.

A signal handler runs in the middle of whatever the program was doing. Only a
small set of operations is safe there, because the code it interrupts may be
halfway through something the handler would then reenter.

## Decision

SIGPIPE is ignored outright. SIGINT and SIGTERM share one handler whose entire
body sets a byte in `.bss` to 1.

The accept loop reads that byte at the top of every iteration. A signal
interrupts the blocking `accept`, which returns EINTR, the loop comes back
round, sees the flag and shuts down. A read interrupted in the middle of a
connection checks the same flag and stops rather than retrying.

## Consequences

Nothing in the handler can be unsafe, because writing a byte is the only thing
it does. There is no reentrancy to reason about and no ordering problem, since
the flag only ever moves from 0 to 1.

Shutdown is not instant. It happens at the next loop boundary, so a signal that
arrives while the server is blocked writing to a slow client is not acted on
until that write finishes or fails. For an echo server that is at most one
buffer of delay. A later version with timeouts would bound it properly.

Installing any handler at all needed more than expected. x86_64 has no default
signal restorer, so a program without libc has to supply its own stub that
calls `rt_sigreturn` and set SA_RESTORER in the flags. Without both the kernel
rejects the call. This is invisible when libc is present because it fills the
field in silently.

SA_RESTART is deliberately not set. Restarting the interrupted syscall is
usually the convenient default, but here the interruption is the mechanism, and
an automatically restarted `accept` would never return to the loop that checks
the flag.

Testing SIGPIPE by provoking it over a socket does not work. The first write
after a peer resets the connection returns ECONNRESET and raises nothing, and
only a second write raises the signal, so a test written that way passes
whether or not the signal is handled. The test sends the signal to the process
directly instead, which fails against a build that does not ignore it.
