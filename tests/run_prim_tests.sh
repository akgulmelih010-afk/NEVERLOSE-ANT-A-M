#!/bin/bash
# Nykle.win primordial edition testi. Gereken: redis-server ve redis-cli (Lua 5.1 + EVAL), python3.
# Sahte primordial API'si tests/prim_harness.lua icinde; script primordial/Nykle.win.lua.
# Kullanim: tests/run_prim_tests.sh             -> 4 mod (full, noffi, missing, nofeature) + local sayaci
#           tests/run_prim_tests.sh -v          -> lua'nin butun satirlari (PASS / FAIL disindakiler de)
#           tests/run_prim_tests.sh full        -> sadece bir mod (ikinci arguman -v olabilir)
# Kaynak metin stdin'den gelir (redis-cli -x son arguman olarak ekler): ARGV[1] = mod, ARGV[2] = kaynak.
# Port 6398: GameSense / Neverlose testleri 6399'u kullanir, birbirine karismaz.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/../primordial/Nykle.win.lua"
PORT=6398
VERBOSE=0
MODES="full noffi missing nofeature"
for a in "$@"; do
    case "$a" in
        -v) VERBOSE=1 ;;
        full|noffi|missing|nofeature) MODES="$a" ;;
        *) echo "bilinmeyen arguman: $a"; exit 2 ;;
    esac
done
if [ ! -f "$SRC" ]; then
    echo "FAIL T-LOAD-1 script yok: $SRC"
    exit 1
fi
if ! redis-cli -p $PORT ping >/dev/null 2>&1; then
    redis-server --port $PORT --daemonize yes --lua-time-limit 600000 --save "" --appendonly no >/dev/null
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        redis-cli -p $PORT ping >/dev/null 2>&1 && break
        sleep 0.3
    done
fi
sha=$(redis-cli -p $PORT -x SCRIPT LOAD < "$DIR/prim_harness.lua")
case "$sha" in
    *ERR*|"") echo "FAIL harness yuklenemedi: $sha"; exit 1 ;;
esac
status=0
for mode in $MODES; do
    result=$(redis-cli -p $PORT -x EVALSHA "$sha" 0 "$mode" < "$SRC" 2>&1)
    if [ $VERBOSE -eq 1 ]; then
        echo "$result"
    else
        echo "$result" | grep -E '^(PASS|FAIL|ALL PASSED|FAILED|ERR)'
    fi
    last=$(echo "$result" | tail -1)
    echo "== $mode: $last"
    [ "$last" = "ALL PASSED" ] || status=1
done
# T-LOAD-4: ana bolum local sayisi (tests/count_locals.py ile, hedef <= 24; LuaJIT siniri 200).
count=$(python3 "$DIR/count_locals.py" "$SRC" | tail -1)
if [ "$count" -le 24 ] 2>/dev/null; then
    echo "PASS T-LOAD-4 ana bolumde local sayisi $count (hedef <= 24, sinir 200)"
else
    echo "FAIL T-LOAD-4 ana bolumde local sayisi $count (hedef <= 24, sinir 200)"
    status=1
fi
exit $status
