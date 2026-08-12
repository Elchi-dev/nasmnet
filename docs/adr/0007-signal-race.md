# 0007. Blocking signals around the wait to close the shutdown race

Status: Accepted
Date: 2026-08-12
Supersedes part of: 0006

## Context

The shutdown flag added in 0006 is read at the top of the accept loop, and
`accept` is entered a few instructions later. Those few instructions are a
window. A signal arriving inside it runs the handler, sets the flag, and returns
to a program that has already read the flag and is about to block. `accept`
then waits with nothing left to wake it, because the signal has been and gone.

The server sits there. The next client to connect releases it and the flag is
noticed, but nothing else will, and until then it can only be killed.

This was reported after v1.1 shipped. It is not theoretical. Widening the gap
with a delay loop reproduces it every time.

## Decision

Block SIGINT and SIGTERM before reading the flag, and hand the blocked mask to
the kernel as part of the wait itself.

The loop blocks both signals with `rt_sigprocmask`, reads the flag, then calls
`ppoll` on the listening socket with an empty signal mask. `ppoll` swaps the
mask in and out around the wait as a single kernel operation. A signal that
arrives while the flag is being read is held pending and delivered the instant
the wait opens. A signal that arrives during the wait interrupts it normally.
Both paths return to the top of the loop, where the flag is read again.

The listening socket is also switched to non blocking. `poll` reporting a
readable listener says a connection was queued, not that it will still be there
by the time `accept` runs, and a connection reset in that gap would otherwise
put the server straight back into a blocking `accept`.

The mask is restored immediately after the wait, so signals are unblocked for
the whole time a connection is being served and an interrupted read still ends
it.

## Consequences

The race is gone rather than made unlikely, because the gap it depended on no
longer exists at any width. This is the same mechanism `epoll_pwait` provides,
so v2.0 keeps the approach and drops `ppoll` for it.

The cost is two extra syscalls per accepted connection and a wait that is now
two calls rather than one. For a server handling one connection at a time this
does not matter, and it stops mattering at all once the event loop lands.

The alternative was the self pipe trick, where the handler writes a byte to a
pipe that the wait also watches. It works on any Unix and needs no signal mask
juggling, but it costs a pair of file descriptors, a drain step, and a handler
that does more than set a byte. `ppoll` is Linux specific and this project is
already committed to Linux syscall numbers, so there was nothing to gain by
being portable here.

Worth recording for anyone reading the tests: the committed test cannot target
the window directly, because it is a few instructions wide and arrival time
cannot be controlled from a shell. It signals fifteen servers at varying moments
and requires all of them to exit, which catches a shutdown path that hangs in
general. The proof that this specific race existed and is fixed came from a
throwaway build with a delay loop inserted at the gap, which hung before the
change and exited cleanly after it.
