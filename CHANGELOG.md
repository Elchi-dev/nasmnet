# Changelog

All notable changes to this project are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions are numbered vX.0 for a major change, vX.Y for a smaller feature and
vX.Y.Z for a fix.

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

[v1.0]: https://github.com/Elchi-dev/nasmnet/releases/tag/v1.0
