# Changelog

All notable changes to this project are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions are numbered vX.0 for a major change, vX.Y for a smaller feature and
vX.Y.Z for a fix.

## [v2.0] - 2026-08-12

The server handles many connections at once. It is a single threaded epoll
event loop over non blocking sockets, with no thread or process per connection.

### Added
- An epoll event loop. Up to 1024 connections at a time by default, from one
  thread.
- A fixed pool of connection slots with a free list, so taking and returning a
  slot is constant time and no memory is allocated while the server runs. Each
  slot carries the descriptor, the state, a buffer and the offset and length of
  anything still waiting to be written.
- Partial writes are remembered. A connection with a buffer still going out
  switches to waiting for EPOLLOUT and is not read from again until it drains,
  which is what stops a slow reader from growing memory.
- `MAX_CONNS` can be set at assembly time with `-DMAX_CONNS=`, since the slot
  pool is the only sizeable reservation the server makes.
- A connection arriving with no slot free is accepted and closed immediately
  instead of being left in the backlog.
- Shutdown closes every open connection before it exits.
- Unit tests for the slot allocator, and integration tests for thirty
  simultaneous clients, an idle client that must not block anyone, and a four
  slot build used to fill the connection table.
- ADR 0008, which supersedes 0003.

### Changed
- `ppoll` is replaced by `epoll_pwait`, which takes the same signal mask and
  keeps the shutdown race from v1.1.1 closed by the same mechanism.
- Every socket read in the test suite has a timeout, so a server that stops
  answering fails the suite instead of hanging it.

## [v1.1.2] - 2026-08-12

Tooling only. The server itself is unchanged.

### Added
- `make debug`, which rebuilds with dwarf line information so gdb can point at
  the line that faulted instead of an offset into a symbol. The default build
  is unchanged and stays without it.
- The test harness turns an exit above 128 into the signal that caused it, so a
  crash reports `killed by SIGSEGV` rather than `139`.
- A check that the long running server survived the whole suite, since a crash
  partway through previously surfaced as an unrelated socket failure later on.
- Notes in CONTRIBUTING on enabling core dumps, reaching them with
  `coredumpctl` on systemd, and the handful of mistakes that usually cause a
  fault when there is no libc underneath.

## [v1.1.1] - 2026-08-12

### Fixed
- A signal arriving between the shutdown flag being read and `accept` being
  entered was lost, and the server then blocked with nothing left to wake it.
  It stayed up until a client happened to connect and otherwise had to be
  killed. SIGINT and SIGTERM are now blocked around the flag check and handed
  to `ppoll`, which unblocks them as part of the wait itself, so a signal in
  that gap is held pending rather than dropped.
- The listening socket is non blocking. A connection reset between `poll`
  reporting it and `accept` running would previously drop the server back into
  a blocking `accept`.

### Added
- A shutdown timing test that signals fifteen servers at varying moments and
  requires every one of them to exit.
- ADR 0007, covering the race, the fix and why the self pipe trick was not
  used.

## [v1.1] - 2026-08-12

Signal handling. The server can now be stopped properly and can no longer be
killed by a client that walks away.

### Added
- SIGINT and SIGTERM close the listening socket and exit with code 0. The
  handler only sets a flag, and the accept loop acts on it at the top of the
  next iteration, so nothing unsafe runs inside the handler itself.
- A read interrupted mid connection checks the same flag instead of retrying,
  so a shutdown is not held up by an idle client.
- `src/sig.asm`, which installs handlers and carries the rt_sigreturn stub that
  x86_64 requires when there is no libc to supply one.
- Tests for both signals, idle and with a connection open, and a check that the
  port is bindable again immediately after shutdown.
- ADR 0006 covering the approach and why SA_RESTART is deliberately not set.

### Fixed
- SIGPIPE is ignored. Writing to a socket whose peer had reset the connection
  would terminate the process, so a single client disappearing at the wrong
  moment could take the server down.

## [v1.0] - 2026-08-12

First release. A blocking TCP echo server in x86_64 assembly with no libc and
no dependencies.

### Added
- TCP server that binds `0.0.0.0`, listens and echoes every byte back to the
  client. Handles one connection at a time.
- Port taken from the first argument, defaulting to 8080. Values that are not
  a number from 1 to 65535 are rejected before any socket is opened.
- `--help` and `--version`.
- Every syscall return value is checked. Failures name the call and translate
  the errno to its symbolic name, so a busy port reports
  `bind failed: errno 98 (EADDRINUSE)`.
- `write_all` retries on short writes and on EINTR rather than losing bytes.
- `accept` retries on EINTR and ECONNABORTED instead of treating a client that
  went away as fatal.
- `SO_REUSEADDR` on the listening socket so a restart does not have to wait for
  the socket to leave TIME_WAIT.
- Unit test binary written in assembly covering the string, parsing and
  formatting routines.
- Integration test script that drives a running server over `/dev/tcp` and
  checks null bytes, a 256 KB payload and the bind failure path.
- GitHub Actions running both suites, checking the binary has no dynamic
  links, and running shellcheck over the test script.
- Architecture decision records covering the choice of raw syscalls, the
  register convention, the blocking accept loop, the absence of TLS and the
  approach to testing.

[v2.0]: https://github.com/Elchi-dev/nasmnet/releases/tag/v2.0
[v1.1.2]: https://github.com/Elchi-dev/nasmnet/releases/tag/v1.1.2
[v1.1.1]: https://github.com/Elchi-dev/nasmnet/releases/tag/v1.1.1
[v1.1]: https://github.com/Elchi-dev/nasmnet/releases/tag/v1.1
[v1.0]: https://github.com/Elchi-dev/nasmnet/releases/tag/v1.0
