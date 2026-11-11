#!/bin/bash
# Nykle.win GameSense edition duman testi. Gereken: redis-server ve redis-cli (Lua 5.1 + EVAL).
# Kullanim: tests/run_gs_smoke.sh           -> sonuc satirlari + "ALL PASSED" / "FAILED n"
#           tests/run_gs_smoke.sh -v        -> lua'nin konsola yazdigi satirlar da
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/../Nykle.win.gamesense.lua"
PORT=6399
if ! redis-cli -p $PORT ping >/dev/null 2>&1; then
    redis-server --port $PORT --daemonize yes --lua-time-limit 60000 >/dev/null
    sleep 1
fi
sha=$(redis-cli -p $PORT -x SCRIPT LOAD < "$DIR/gs_smoke.lua")
result=$(redis-cli -p $PORT -x EVALSHA "$sha" 0 < "$SRC")
if [ "${1:-}" = "-v" ]; then
    echo "$result"
else
    echo "$result" | grep -E '^(PASS|FAIL|ALL PASSED|FAILED)'
fi
last=$(echo "$result" | tail -1)
[ "$last" = "ALL PASSED" ]
