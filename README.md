# nasmnet

A TCP server written in x86_64 assembly. No libc, no runtime, no dependencies. It talks to the Linux kernel directly through the `syscall` instruction and nothing else.

The current release is an echo server: every byte you send it comes straight back. That is deliberately small. The point of v1 is to get the socket lifecycle, the error handling and the test harness right before anything is built on top of them. HTTP comes later, and it will sit on this code rather than replace it.

```
$ make
$ ./bin/nasmnetd 8080
nasmnetd listening on 0.0.0.0:8080
```

The binary is about 13 KB and links against nothing at all.

## Building

You need `nasm` and GNU `ld`. That is the whole list.

```
sudo pacman -S nasm       # Arch
sudo apt install nasm     # Debian and Ubuntu
```

Then:

```
make            # build bin/nasmnetd
make test       # build everything and run all the tests
make clean      # remove build/ and bin/
make install    # install to /usr/local/bin, override with PREFIX=
```

## Running

```
nasmnetd [port]
```

The port defaults to 8080. It must be a plain number between 1 and 65535, and anything else is rejected before a socket is ever opened. `--help` and `--version` do what you would expect.

The server binds `0.0.0.0` and handles one connection at a time. A second client will sit in the listen backlog until the first one disconnects. Concurrency is the v2 job and it is going to be an epoll event loop, not a process per connection.

Exit codes:

| Code | Meaning |
| ---- | ------- |
| 0 | asked for help or the version |
| 1 | the port argument was not usable |
| 2 | a socket syscall failed, and the message says which one |

When a syscall fails the server prints the call that failed and the errno by name, so `bind failed: errno 98 (EADDRINUSE)` rather than a bare number you have to go and look up.

## Testing

```
make test
```

Two suites run. The unit tests are a separate assembly binary that exercises the pure helper routines, the string length and comparison, the port parser and the number formatter, against their edge cases. The integration tests are a bash script that starts a real server, opens real sockets through `/dev/tcp` and checks what comes back over the wire, including null bytes, a 256 KB payload and the error path when the port is already taken.

Neither suite needs anything installed. No test framework, no scripting language, no network access.

## Layout

```
src/nasmnetd.asm   entry point, argument handling, socket setup, accept loop
src/io.asm         write helpers that survive short writes and signals
src/str.asm        string length, string compare, port parsing, number formatting
src/err.asm        errno number to errno name
src/sys.inc        syscall numbers and socket constants
tests/unit.asm     unit tests for the helper routines
tests/run.sh       integration tests over a real socket
docs/adr/          why the design is the way it is
```

## Roadmap

- **v1.0** blocking echo server, argument handling, errno reporting
- **v1.1** signal handling and a clean shutdown on SIGINT and SIGTERM
- **v1.2** a matching client binary, useful on its own and used by the tests
- **v2.0** an epoll event loop with non blocking sockets and many concurrent connections
- **v3.0** HTTP/1.1, a request parser, routing and real responses
- **v3.1** static file serving through `sendfile`
- **v4.0** IPv6 and dual stack

## Why you would use this

Honestly, for a production website you probably would not, and I would rather say so here than oversell it. Go and nginx give you TLS, HTTP/2, memory safety and fifteen years of people finding the edge cases. This project has none of that yet.

What it does give you is size and transparency. The binary is around 13 KB with no interpreter, no garbage collector and no scheduler underneath it, so it starts in well under a millisecond and holds a couple of hundred KB of memory. In a container built `FROM scratch` the image is the binary and nothing else. That matters for an initramfs, for a rescue system, or for a sidecar whose entire job is answering a health check.

It is also small enough to read end to end. There are no dependencies to audit and no framework hiding the syscalls from you, which is the other reason it exists: writing it is the fastest way to understand what a socket actually is underneath everything that normally wraps it.

TLS is not planned and that is a design decision, not an oversight. It belongs to a reverse proxy in front of this, which is where the certificates already live. See `docs/adr/0004-no-tls.md`.

## License

MIT. See [LICENSE](LICENSE).
