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

signal_name() {
    case "$1" in
        2)  printf 'SIGINT' ;;
        4)  printf 'SIGILL' ;;
        6)  printf 'SIGABRT' ;;
        7)  printf 'SIGBUS' ;;
        8)  printf 'SIGFPE' ;;
        9)  printf 'SIGKILL' ;;
        11) printf 'SIGSEGV' ;;
        13) printf 'SIGPIPE' ;;
        15) printf 'SIGTERM' ;;
        *)  printf 'signal %s' "$1" ;;
    esac
}

describe_exit() {
    if [ "$1" -ge 128 ]; then
        printf 'killed by %s' "$(signal_name $(($1 - 128)))"
    else
        printf '%d' "$1"
    fi
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
check "--version prints the version" "nasmnetd 1.1.1" "$out"

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
echo "shutdown"

shutdown_case() {
    local sig="$1"
    local port="$2"
    local hold="$3"
    "$BIN" "$port" >"$TMP/shut.log" 2>&1 &
    local pid=$!
    for _ in $(seq 1 50); do
        if exec 9<>"/dev/tcp/127.0.0.1/$port" 2>/dev/null; then
            exec 9<&-
            exec 9>&-
            break
        fi
        sleep 0.1
    done
    if [ "$hold" = "hold" ]; then
        exec 8<>"/dev/tcp/127.0.0.1/$port"
        printf 'x' >&8
        head -c 1 <&8 >/dev/null
    fi
    kill -"$sig" "$pid" 2>/dev/null
    wait "$pid"
    local rc=$?
    if [ "$hold" = "hold" ]; then
        exec 8<&- 2>/dev/null
        exec 8>&- 2>/dev/null
    fi
    describe_exit "$rc"
}

rc="$(shutdown_case TERM $((PORT + 1)) idle)"
check "exits with code 0 on SIGTERM" "0" "$rc"
check "says that it is shutting down" "nasmnetd shutting down" "$(tail -1 "$TMP/shut.log")"

rc="$(shutdown_case INT $((PORT + 2)) idle)"
check "exits with code 0 on SIGINT" "0" "$rc"

rc="$(shutdown_case TERM $((PORT + 3)) hold)"
check "shuts down while a connection is open" "0" "$rc"

rc="$(shutdown_case TERM $((PORT + 4)) idle)"
check "first run on the reuse port exits cleanly" "0" "$rc"
rc="$(shutdown_case TERM $((PORT + 4)) idle)"
check "the port is free again straight after shutdown" "0" "$rc"

hung=0
for i in $(seq 1 15); do
    port=$((PORT + 10 + i))
    "$BIN" "$port" >/dev/null 2>&1 &
    pid=$!
    sleep "0.0$((RANDOM % 90 + 10))"
    kill -TERM "$pid" 2>/dev/null
    waited=0
    while kill -0 "$pid" 2>/dev/null; do
        sleep 0.2
        waited=$((waited + 1))
        if [ "$waited" -gt 15 ]; then
            kill -9 "$pid" 2>/dev/null
            hung=1
            break
        fi
    done
    wait "$pid" 2>/dev/null
done
if [ "$hung" -eq 0 ]; then
    ok "exits whenever the signal lands, across 15 runs"
else
    no "exits whenever the signal lands, across 15 runs" "a run had to be killed"
fi

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

if kill -0 "$SRV" 2>/dev/null; then
    ok "the long running server came through every test alive"
else
    no "the long running server came through every test alive" "it exited early"
fi

kill -9 "$SRV" 2>/dev/null
SRV=""

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
