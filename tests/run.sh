#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/bin/nasmnetd"
PORT="${TEST_PORT:-19080}"
TMP="$(mktemp -d)"
SRV=""
PASS=0
FAIL=0

cleanup() {
    [ -n "$SRV" ] && kill -9 "$SRV" 2>/dev/null
    rm -rf "$TMP"
}
trap cleanup EXIT

ok() {
    PASS=$((PASS + 1))
    printf '  ok   %s\n' "$1"
}

no() {
    FAIL=$((FAIL + 1))
    printf '  FAIL %s\n' "$1"
    [ $# -gt 1 ] && printf '       %s\n' "$2"
}

check() {
    if [ "$2" = "$3" ]; then
        ok "$1"
    else
        no "$1" "want [$2] got [$3]"
    fi
}

start_server() {
    "$BIN" "$PORT" >"$TMP/server.log" 2>&1 &
    SRV=$!
    for _ in $(seq 1 50); do
        if exec 9<>"/dev/tcp/127.0.0.1/$PORT" 2>/dev/null; then
            exec 9<&-
            exec 9>&-
            return 0
        fi
        sleep 0.1
    done
    echo "server did not come up on port $PORT"
    cat "$TMP/server.log"
    exit 1
}

roundtrip() {
    local payload="$1"
    exec 3<>"/dev/tcp/127.0.0.1/$PORT" || return 1
    printf '%s' "$payload" >&3
    head -c "${#payload}" <&3
    exec 3<&-
    exec 3>&-
}

echo "argument handling"

out="$("$BIN" --version)"
check "--version prints the version" "nasmnetd 1.0" "$out"

"$BIN" --help >/dev/null 2>&1
check "--help exits zero" "0" "$?"

"$BIN" abc >/dev/null 2>&1
check "rejects a non numeric port" "1" "$?"

"$BIN" 70000 >/dev/null 2>&1
check "rejects a port above 65535" "1" "$?"

"$BIN" 0 >/dev/null 2>&1
check "rejects port zero" "1" "$?"

"$BIN" "" >/dev/null 2>&1
check "rejects an empty port" "1" "$?"

"$BIN" 12abc >/dev/null 2>&1
check "rejects trailing garbage in the port" "1" "$?"

echo
echo "echo behaviour"

start_server
ok "server starts and accepts connections"

check "startup line names the port" \
    "nasmnetd listening on 0.0.0.0:$PORT" \
    "$(cat "$TMP/server.log")"

got="$(roundtrip "hello world")"
check "echoes a short payload" "hello world" "$got"

got="$(roundtrip "second connection")"
check "serves connections one after another" "second connection" "$got"

got="$(roundtrip "line one
line two")"
check "keeps newlines intact" "line one
line two" "$got"

printf 'abc\000def' >"$TMP/nul.bin"
exec 3<>"/dev/tcp/127.0.0.1/$PORT"
cat "$TMP/nul.bin" >&3
head -c 7 <&3 >"$TMP/nul.out"
exec 3<&-
exec 3>&-
if cmp -s "$TMP/nul.bin" "$TMP/nul.out"; then
    ok "passes null bytes through unchanged"
else
    no "passes null bytes through unchanged"
fi

head -c 262144 /dev/urandom >"$TMP/big.bin"
exec 3<>"/dev/tcp/127.0.0.1/$PORT"
head -c 262144 <&3 >"$TMP/big.out" &
READER=$!
cat "$TMP/big.bin" >&3
wait $READER
exec 3<&-
exec 3>&-
if cmp -s "$TMP/big.bin" "$TMP/big.out"; then
    ok "echoes 256 KB byte for byte"
else
    no "echoes 256 KB byte for byte"
fi

exec 3<>"/dev/tcp/127.0.0.1/$PORT"
exec 3<&-
exec 3>&-
got="$(roundtrip "still alive")"
check "survives a client that closes without sending" "still alive" "$got"

echo
echo "signals"

kill -PIPE "$SRV" 2>/dev/null
sleep 0.3
if kill -0 "$SRV" 2>/dev/null; then
    ok "ignores SIGPIPE"
else
    no "ignores SIGPIPE" "the server exited"
fi

got="$(roundtrip "after sigpipe")"
check "keeps serving after SIGPIPE" "after sigpipe" "$got"

echo
echo "socket errors"

"$BIN" "$PORT" >"$TMP/busy.log" 2>&1
rc=$?
check "second bind on a used port exits with code 2" "2" "$rc"

if grep -q "EADDRINUSE" "$TMP/busy.log"; then
    ok "names EADDRINUSE when the port is taken"
else
    no "names EADDRINUSE when the port is taken" "$(cat "$TMP/busy.log")"
fi

kill -9 "$SRV" 2>/dev/null
SRV=""

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
