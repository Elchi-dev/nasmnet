# 0004. No TLS, run behind a reverse proxy

Status: Accepted
Date: 2026-08-12

## Context

Serving `https://` means implementing TLS. In a project with no dependencies
that means implementing it by hand: X25519 key exchange, AES-GCM or ChaCha20
for the record layer, SHA-384, HKDF, the handshake state machine, ASN.1 and
X.509 certificate parsing, and chain validation against a trust store. Then
certificate renewal on top.

Every one of those is a place where a subtle mistake is invisible in testing
and fatal in production. Constant time comparison, padding handling and nonce
reuse have all produced real vulnerabilities in libraries written by people who
work on nothing else.

## Decision

The server speaks plain HTTP on a local port and never implements TLS.
Termination belongs to nginx, Caddy or another proxy in front of it.

## Consequences

A public deployment looks like the proxy holding the certificate and the domain
and forwarding to `127.0.0.1:8080`. That is how most services are already
deployed, so it asks nothing unusual of anyone running this.

It also removes the largest source of risk in the project and keeps the whole
codebase small enough to read. The cryptography that would have dominated it is
handled by software that is audited, has a security team and gets patched.

The proxy takes the domain with it. Because it matches the Host header and
routes on it, the server only ever binds an address and a port, so the DNS
client that no libc would otherwise have forced is not needed either. The HTTP
layer does have to handle what a proxy sends, which means reading `Host`,
`X-Forwarded-For` and `X-Forwarded-Proto` rather than treating the peer address
as the client address.

Running this directly on port 443 is not supported and will not be. Anyone who
tries is running plaintext on the port where browsers expect encryption.
