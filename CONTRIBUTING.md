# Contributing

Bug reports are welcome, especially anything where the server misbehaves on the
wire. If you can describe the bytes you sent and the bytes you got back, that is
usually enough to reproduce it.

## Before you open a pull request

Run `make test` and make sure both suites pass. Add a test for whatever you
changed. A fix without a test that fails before it and passes after it is hard
to keep, because nothing stops the bug coming back.

Check the return value of every syscall you add. `syscall` puts a negative
errno in `rax` and there is no library underneath to notice a failure for you.
An unchecked call is the most common way something breaks quietly here.

## Style

Read `docs/adr/0002-register-convention.md` before writing a routine. Arguments
in `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`, return in `rax`, and `rbx`, `rbp`
and `r12` through `r15` are preserved by the routine that uses them.

Comments explain why something is done, not what the instruction does. A line
saying that `mov rax, 1` moves 1 into `rax` is noise. A line explaining that a
syscall wants its fourth argument in `r10` because `syscall` destroys `rcx` is
worth having.

Labels inside a routine start with a dot and are local to it. Exported names
are lower case with underscores.

## Decisions

If a change alters how the project works rather than what it does, add a record
in `docs/adr/`. Copy the shape of an existing one: the context, the decision,
and the consequences including the ones you would rather not admit to.
