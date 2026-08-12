# Architecture decision records

Each file records one decision, why it was made and what it costs. They are
written when the decision is taken and are not edited afterwards. If a decision
is reversed later, a new record supersedes the old one and the old one stays
where it is.

| Record | Title | Status |
| ------ | ----- | ------ |
| [0001](0001-raw-syscalls-no-libc.md) | Raw syscalls with no libc | Accepted |
| [0002](0002-register-convention.md) | Register and calling convention | Accepted |
| [0003](0003-blocking-accept-loop.md) | Blocking accept loop before epoll | Accepted |
| [0004](0004-no-tls.md) | No TLS, run behind a reverse proxy | Accepted |
| [0005](0005-tests-without-a-framework.md) | Tests without a framework | Accepted |
| [0006](0006-signal-handling.md) | Signal handling with a flag | Accepted |
