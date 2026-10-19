#!/bin/bash
# HOST. One short session on the rg35xxsp under its lock: deploy (md5-checked), run runs.txt, fetch to <local>/<label>/, clear the device out/.
#   bundle/device/device-session.sh LABEL RUN...      RUN = TAG|VARIANT|ROM|LAST|KIND (see rg35xxsp_functions.sh)
# Env: BUNDLE (the bundle exe), SODIR (dir with the four plugin .so: mupen64plus-{rdp-foir,rsp-armlet,audio-altru,input-suxty}.so),
#      LOCAL (fetch dir), PIN=1 (pin clocks, restored), X (device work dir, default /mnt/sdcard/n64-dev/pow2), WAIT (default 300).
set -e
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/../../.." && pwd)
LABEL=$1; shift
: "${BUNDLE:?}" "${SODIR:?}" "${LOCAL:?}"
X=${X:-/mnt/sdcard/n64-dev/pow2}; WAIT=${WAIT:-300}; DEV=rg35xxsp; LOCKDIR=/tmp/n64-plugins-locks
export X WAIT DEV LABEL BUNDLE SODIR LOCAL H R PIN; export RUNS; RUNS=$(printf '%s\n' "$@")
mkdir -p "$LOCAL" "$LOCKDIR"
flock -w 3600 "$LOCKDIR/$DEV.lock" bash -c '
set -e
ssh -o ConnectTimeout=15 "$DEV" "mkdir -p $X/plug $X/bundle $X/out"
if ssh "$DEV" "pgrep -x mupen64plus" > /dev/null; then echo "device busy: mupen64plus running" >&2; exit 3; fi
sf() { m=$(md5sum < "$1" | cut -d" " -f1); r=$(ssh -n "$DEV" "test -f $2 && md5sum < $2" 2>/dev/null | cut -d" " -f1); [ "$m" = "$r" ] || scp -qC "$1" "$DEV:$2"; }
sf "$BUNDLE" $X/bundle/mupen64plus
ssh "$DEV" "chmod +x $X/bundle/mupen64plus"
for p in mupen64plus-rdp-foir mupen64plus-rsp-armlet mupen64plus-audio-altru mupen64plus-input-suxty; do sf "$SODIR/$p.so" $X/plug/$p.so; done
sf "$H/rg35xxsp_functions.sh" $X/rg35xxsp_functions.sh
sf "$R/mupen64plus-pow2/ext/mupen64plus-rsp-armlet/tools/equiv/device/rg35xxsp_session.sh" $X/rg35xxsp_session.sh
sf "$R/resources/toolchains/rg35xxsp/scripts/cpu_perf.sh" $X/cpu_perf.sh
ssh "$DEV" "rm -rf $X/out/* $X/done; cat > $X/runs.txt" <<< "$RUNS"
ssh "$DEV" "MAXWAIT=$WAIT PIN=$PIN timeout $((WAIT + 120)) sh $X/rg35xxsp_session.sh $X" > "$LOCAL/session.$LABEL.out" 2>&1 || true
ssh "$DEV" "pgrep -x mupen64plus" >> "$LOCAL/session.$LABEL.out" 2>&1 || true
mkdir -p "$LOCAL/$LABEL"; scp -rqC "$DEV:$X/out/*" "$LOCAL/$LABEL/"
ssh "$DEV" "rm -rf $X/out/*"
cat "$LOCAL/session.$LABEL.out"
'
