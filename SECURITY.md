# Security

## Scope

This is a hand written server with no memory safety and no security audit. It
handles one connection at a time, has no read timeout, and does not implement
TLS. Do not put it in front of a network you do not trust yet.

The intended deployment is behind a reverse proxy that terminates TLS and
handles the public internet, with this server bound to a local port. See
`docs/adr/0004-no-tls.md`.

## Supported versions

The latest release only. There are no backports.

## Reporting

Report anything you find privately through GitHub's security advisory form on
this repository, under the Security tab, rather than opening a public issue.

Include what you sent, what happened, and the version. A crash, a hang or a
read outside a buffer are all worth reporting even if you do not have a full
exploit for them.

Expect a reply within a week. This is a personal project rather than a funded
one, so there is no bounty attached.
