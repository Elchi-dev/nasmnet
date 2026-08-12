# 0002. Register and calling convention

Status: Accepted
Date: 2026-08-12

## Context

Without libc there is nothing forcing a particular calling convention. Any
internal scheme would work as long as it is used consistently. Consistency is
the thing that matters, because the alternative is checking the source of a
routine every time it is called to find out which registers it destroys.

## Decision

Follow the System V AMD64 convention already used by the kernel interface.

Arguments go in `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`, in that order. Return
values come back in `rax`. A routine may destroy `rax`, `rcx`, `rdx`, `rsi`,
`rdi`, `r8`, `r9`, `r10` and `r11`. A routine must preserve `rbx`, `rbp` and
`r12` through `r15`, saving them on the stack if it needs them.

Failures are reported the same way the kernel reports them: a negative value in
`rax` holding the negated errno. Routines that answer a yes or no question
return 1 or 0. Routines that parse return `-1` when the input is not valid.

## Consequences

The first three arguments of a routine land in the same registers the syscall
interface wants, so a wrapper around a syscall usually has to change nothing
before executing it. The only difference worth remembering is that the kernel
takes its fourth argument in `r10` rather than `rcx`, because `syscall` itself
overwrites `rcx` with the return address.

Anyone who has read compiler output for x86_64 already knows this convention,
so the source reads the way they expect. If a routine is later replaced with a
C implementation for comparison, the call sites do not change.

The cost is the push and pop pairs in routines that need a callee saved
register, which is most of them. That is a few instructions of overhead in
exchange for never having to think about whether a call has quietly destroyed
something.
