# 0003. Blocking accept loop before epoll

Status: Superseded by 0008
Date: 2026-08-12

## Context

A server has to decide how it handles more than one client. On Linux there are
three realistic shapes. Accept one connection, serve it to completion, then
accept the next. Fork a process for each connection. Or run a single non
blocking event loop on top of `epoll`.

The event loop is the right end state. It keeps one process, one thread and a
fixed memory footprint no matter how many clients connect, and it is what every
serious server on this platform does.

## Decision

v1.0 uses a blocking accept loop and serves one connection at a time. epoll
arrives in v2.0. Fork per connection is rejected outright and will not be
implemented at any point.

## Consequences

The whole server is a straight line that can be read in one sitting. There is
no connection state to allocate, no partial read to remember and no state
machine to reason about, which means the socket lifecycle and the error
handling underneath it can be tested properly before concurrency arrives to
hide any bugs in them.

The obvious cost is that a second client waits in the listen backlog until the
first disconnects, and a client that opens a connection and never sends
anything stalls the server indefinitely. There is no read timeout in v1.0.
Anything exposed to a network it does not trust needs v2.0.

Fork is rejected because it trades a page table and a process control block for
every connection, and because the shared state that a later HTTP layer will
want, an open file cache and counters, becomes awkward the moment the address
spaces are separate. The work of writing an event loop is worth doing once
rather than working around a process model forever.

Nothing in v1.0 is thrown away by the move to epoll. The read and write helpers
already deal with short transfers and interruption, which is exactly what non
blocking sockets demand.
