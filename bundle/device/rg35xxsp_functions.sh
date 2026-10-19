#!/bin/sh
# ON rg35xxsp, sourced by the spruce launcher copy (armlet's tools/equiv/device/rg35xxsp_session.sh replaces run_mupen_standalone with run_exp).
# Bundle vs .so-set runs of $X/runs.txt; nothing of spruce is modified (private HOME/XDG/--configdir/--datadir under $X).
#   runs.txt line:  TAG|VARIANT|ROM|LAST|KIND (eq | tm)        VARIANT so (spruce's core + console, our four plugins as .so in $X/plug) | bundle ($X/bundle/mupen64plus)
#   per run: $X/out/TAG/{log,fl.bin (FOIR_FRAMELOG),frame_*.ppm,armlet.log,foir.log,status}; screenshots at LAST/3, 2*LAST/3, LAST.
X=${X:-/mnt/sdcard/n64-dev/pow2}
run_exp() {
    S=/mnt/SDCARD/Emu/N64/mupen64plus; ROMDIR=/mnt/SDCARD/Roms/N64
    rm -rf "$X/home"; mkdir -p "$X/home/cache" "$X/out" "$X/data"
    touch "$X/marker"
    for f in mupen64plus.ini font.ttf mupencheat.txt; do [ -f "$X/data/$f" ] || cp "$S/$f" "$X/data/"; done
    export HOME=$X/home XDG_CONFIG_HOME=$X/home XDG_DATA_HOME=$X/home XDG_CACHE_HOME=$X/home/cache SDL_AUDIODRIVER=dummy
    export LD_LIBRARY_PATH="$S:/mnt/SDCARD/App/PyUI/dll-mali:/mnt/SDCARD/spruce/flip/lib:/usr/lib:/usr/lib/aarch64-linux-gnu:$LD_LIBRARY_PATH"
    echo "launcher env: gov $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor) freq $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq) online $(cat /sys/devices/system/cpu/online)" > "$X/out/session.info"
    [ -n "$PIN" ] && sh "$X/cpu_perf.sh" on >> "$X/out/session.info" 2>&1
    while IFS='|' read -r TAG VAR ROM LAST KIND; do
        [ -z "$TAG" ] && continue
        OUT=$X/out/$TAG; rm -rf "$OUT" "$X/cfg"; mkdir -p "$OUT" "$X/cfg"
        S1=$((LAST / 3))
        export FOIR_SHOT_DIR=$OUT FOIR_SHOT_FRAMES=$S1,$((S1 * 2)),$LAST FOIR_FRAMELOG=$OUT/fl.bin FOIR_FRAMELOG_MAX=$((LAST + 600)) \
               FOIR_LOGFILE=$OUT/foir.log ARMLET_LOGFILE=$OUT/armlet.log
        # eq: deterministic (FOIR_KNOBS=exact: no frame skip, exact precision) + a hash of every presented frame in foir.log; tm: the plugin's defaults
        unset FOIR_KNOBS FOIR_FRAMEHASH; [ "$KIND" = eq ] && export FOIR_KNOBS=exact FOIR_FRAMEHASH=1
        COMMON="--configdir $X/cfg --datadir $X/data --noosd --set Core[RandomizeInterrupt]=False --emumode 2 --fullscreen --resolution 640x480"
        if [ "$VAR" = bundle ]; then CMD="$X/bundle/mupen64plus $COMMON"
        else CMD="$S/mupen64plus --corelib $S/libmupen64plus.so.2 $COMMON --plugindir $X/plug --gfx $X/plug/mupen64plus-rdp-foir.so \
--rsp $X/plug/mupen64plus-rsp-armlet.so --audio $X/plug/mupen64plus-audio-altru.so --input $X/plug/mupen64plus-input-suxty.so"; fi
        echo "== $TAG $VAR $ROM $(date +%T) temp $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null) freq $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq) load $(cut -d' ' -f1 /proc/loadavg)" >> "$X/out/session.info"
        TMO=$((LAST / 30 + 45))
        # shellcheck disable=SC2086
        timeout -s KILL "$TMO" $CMD "$ROMDIR/$ROM" > "$OUT/log" 2>&1 &
        MP=$!; i=0; status=timeout; LASTF=$OUT/frame_$(printf %05d "$LAST").ppm
        while [ $i -lt $((TMO * 2)) ]; do
            sleep 0.5; i=$((i + 1))
            [ -f "$LASTF" ] && { sleep 1; status=ok; break; }
            kill -0 $MP 2>/dev/null || { status=exited; break; }
        done
        echo "$status after $((i / 2))s" > "$OUT/status"
        pkill -KILL -P $MP 2>/dev/null; kill -KILL $MP 2>/dev/null; pkill -KILL -x mupen64plus 2>/dev/null
        wait $MP 2>/dev/null
        sleep 3
    done < "$X/runs.txt"
    [ -n "$PIN" ] && sh "$X/cpu_perf.sh" off >> "$X/out/session.info" 2>&1
    { echo "outside-writes check (newer than marker, outside $X):"
      find /mnt/SDCARD/Emu/N64 /mnt/SDCARD/Roms/N64 /mnt/SDCARD/Saves /mnt/SDCARD/App/PyUI /root -xdev -newer "$X/marker" -not -path "$X/*" 2>/dev/null | head -20
      echo "(end of list)"; } >> "$X/out/session.info"
}
