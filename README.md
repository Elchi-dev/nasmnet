# Packaging

This branch holds packaging files. It is kept separate from `main` so that
distribution churn, version bumps and checksum updates never touch the history
of the source.

Nothing here is published to a repository yet.

## Arch

`aur/PKGBUILD` builds from the tagged source tarball on GitHub, runs the test
suite during `check()` and installs the binary, the license and the README.

Every step in it was run by hand against the v1.0 tarball before it was
committed, but it has not been through `makepkg` on an Arch machine yet, so
treat it as unverified until someone does that.

To try it:

```
cd aur
makepkg -si
```

Bumping a version means changing `pkgver`, resetting `pkgrel` to 1 and
replacing the checksum with the output of `updpkgsums`.

## Planned

Debian and Homebrew are not started. Debian is the more useful of the two
because the build dependency is only `nasm`. Homebrew would need the formula to
handle the fact that this builds for Linux only, since the syscall numbers and
the ELF output are not portable to macOS.
