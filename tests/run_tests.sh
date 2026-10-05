#!/bin/bash
# Nykle.win test calistirici. Gereken: redis-server ve redis-cli (Lua 5.1 + EVAL), python3.
# Kullanim: tests/run_tests.sh            -> butun modlar + strict + local sayaci
#           tests/run_tests.sh mutate     -> ayrica tam mutasyon seti (uzun surer, ~1 saat)
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/../Nykle.win.lua"
PORT=6399
if ! redis-cli -p $PORT ping >/dev/null 2>&1; then
    redis-server --port $PORT --daemonize yes --lua-time-limit 60000 >/dev/null
    sleep 1
fi
run() { # $1 = harness dosyasi, $2 = mod
    local sha
    sha=$(redis-cli -p $PORT -x SCRIPT LOAD < "$1")
    redis-cli -p $PORT -x EVALSHA "$sha" 0 "$2" < "$SRC"
}
# strict: tanimsiz global okuma / global yazma hata verir.
python3 - "$DIR/harness.lua" "$DIR/.strict.lua" <<'PY'
import sys
s = open(sys.argv[1]).read()
marker = 'local fn, err = loadstring(src'
ins = ('setmetatable(env, { __index = function(_, k) if k == "rage" or k == "utils" or k == "db" then return nil end '
       'error("undefined global " .. tostring(k), 2) end,\n'
       '    __newindex = function(_, k) error("global write " .. tostring(k), 2) end })\n')
open(sys.argv[2], 'w').write(s.replace(marker, ins + marker))
PY
status=0
for mode in none norage notrace badvalues v46 nohull nobinds; do
    result=$(run "$DIR/harness.lua" $mode | tail -1)
    echo "$mode: $result"
    [ "$result" = "ALL PASSED" ] || status=1
done
result=$(run "$DIR/.strict.lua" none | tail -1)
echo "strict: $result"
[ "$result" = "ALL PASSED" ] || status=1
rm -f "$DIR/.strict.lua"
echo "ana bolumde local sayisi (en fazla 200): $(python3 "$DIR/count_locals.py" "$SRC" | tail -1)"
if [ "${1:-}" = "mutate" ]; then
    (cd "$DIR" && python3 mutate.py harness.lua | tail -1)
fi
exit $status
