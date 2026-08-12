# 0008. An epoll event loop with a fixed slot table

Status: Accepted
Date: 2026-08-12
Supersedes: 0003

## Context

0003 chose a blocking accept loop for v1 and said the event loop would follow.
That version served one connection to completion before looking at the next, so
a client that connected and said nothing stalled everyone behind it. A test
against a build of v1.1.2 shows it plainly: open a connection, send nothing,
and a second client waits forever.

## Decision

One process, one thread, non blocking sockets and `epoll`.

Connections live in a fixed pool of slots allocated at assembly time. A slot
holds the descriptor, the state, a buffer and the offset and length of anything
still waiting to go out. A free list of indices hands slots out and takes them
back in constant time.

The index, not the descriptor, is the identity of a connection. `epoll` carries
a 64 bit value with every event, the index goes in it, and the event comes back
with the slot already identified. The listening socket uses an all ones tag that
no index can collide with.

Each connection is a two state machine. Reading pulls one buffer from the socket
and tries to write it straight back. A short write leaves the remainder in the
slot, moves the connection to writing and asks `epoll` for EPOLLOUT instead of
EPOLLIN. Nothing more is read from that connection until the buffer drains.

`epoll` is used level triggered.

## Consequences

Memory is decided at build time rather than by load. A slot is a little over 4
KB and the default is 1024 of them, so the pool is about 4 MB of `.bss` that is
never touched until the slots are used. There is no allocator and no way for a
client to make the server reserve more.

Not reading while a write is outstanding is what makes that bound hold. A client
that sends fast and reads slowly fills its own socket buffer and then simply
stops being read from. Its data waits in the kernel, which is exactly where the
back pressure belongs.

A connection arriving with no slot free is accepted and closed immediately
rather than left queued, so the client learns straight away instead of waiting
on a server that will not answer it. Testing that path needs a table small
enough to fill, which is the reason MAX_CONNS is a build option. The suite
builds a four slot server for it.

Level triggered was chosen over edge triggered because it forgives an
incomplete drain. Edge triggered only reports the transition, so a handler that
does not read until EAGAIN silently loses the rest, and that failure appears
under load rather than in a test. Level triggered costs an extra wakeup here and
there. Edge triggered can come later behind a measurement, not a preference.

`ppoll` from 0007 is gone, but the reasoning behind it is not. `epoll_pwait`
takes the same signal mask and applies it the same way, so the shutdown race
stays closed by exactly the mechanism 0007 describes.

The obvious cost is that the straight line from 0003 is gone. A connection is
now a record that outlives any single pass through the loop, and reading the
code means holding the state machine in your head. That is the price of doing
more than one thing at a time, and it is paid once here rather than repeatedly
in every layer built on top.
