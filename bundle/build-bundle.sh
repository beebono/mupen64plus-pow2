#!/bin/bash
# Builds the static single-binary bundle (core + ui-inn + foir + arMLEt + altru + suxty) with LTO from COPIES of the sources.
#   mupen64plus-pow2/bundle/build-bundle.sh x86_64|aarch64|rg35xxsp [out-dir]   -> <out-dir>/mupen64plus-pow2   (default out-dir: <pow2>/out/<target>)
#   env: JOBS (default nproc), SDL2_LIBDIR (aarch64: dir with the device's libSDL2-2.0.so.0, default the host's aarch64 one),
#        RG35_TOOLCHAIN (default ../resources/toolchains/rg35xxsp, relative to this repo)
#        WORK (default <pow2>/work/<target>), SKIP_LINK=1 to stop after the archives, RELINK=1 to redo only the final link (and the copy)
# aarch64: Ubuntu cross gcc/g++ (rgdsplus, glibc 2.44).  rg35xxsp: resources/toolchains/rg35xxsp (glibc 2.31 floor): C with the host GCC 13 (LTO),
# arMLEt's C++ (parallel-rsp) with the host g++-12 and NO LTO (GCC 12 and 13 LTO bytecode do not mix), libstdc++/libgcc static from the sysroot (GCC 10).
# Generic armv8-a, -O3, no -mcpu/-march.
set -e
target=${1:?usage: build-bundle.sh x86_64|aarch64|rg35xxsp [out-dir]}
H=$(cd "$(dirname "$0")" && pwd); P=$(cd "$H/.." && pwd); R=$(cd "$P/.." && pwd)
JOBS=${JOBS:-$(nproc)}; W=${WORK:-$P/work/$target}; O=${2:-$P/out/$target}
LTO="-flto=$JOBS"
X=aarch64-linux-gnu-; ARCHMK=(HOST_CPU=aarch64 CROSS_COMPILE=$X)
SRC=$P/ext
for d in mupen64plus-core-dento mupen64plus-ui-inn mupen64plus-rdp-foir mupen64plus-rsp-armlet mupen64plus-audio-altru mupen64plus-input-suxty; do
    [ -f "$SRC/$d/Makefile" -o -d "$SRC/$d/src" ] || { echo "$SRC/$d is empty: git submodule update --init --recursive" >&2; exit 1; }
done
case $target in
x86_64)
    X=""; ARCHMK=(NEON=0); CC=gcc; CXXLTO=$LTO; TCFILE=""
    SDL_CFLAGS="$(pkg-config --cflags sdl2)"; SDL_LDLIBS="$(pkg-config --libs sdl2)"
    LIBDIR=/usr/lib/x86_64-linux-gnu; ZLIB=-lz; PNG=-lpng16; EXTRA_INC="$(pkg-config --cflags libpng)" ;;
aarch64)
    CC=${X}gcc; CXXLTO=$LTO
    TCFILE=$SRC/mupen64plus-rsp-armlet/ext/parallel-rsp/toolchain-aarch64-linux-gnu.cmake
    SDLLIB=${SDL2_LIBDIR:-/usr/lib/aarch64-linux-gnu}
    SDL_CFLAGS="-I/usr/aarch64-linux-gnu/include/SDL2 -D_REENTRANT"
    SDL_LDLIBS="-L$SDLLIB -l:libSDL2-2.0.so.0 -Wl,--allow-shlib-undefined -Wl,-rpath-link,$SDLLIB"
    EXTRA_INC=""; LIBDIR=/usr/lib/aarch64-linux-gnu; ZLIB=-l:libz.a; PNG="-l:libpng16.a" ;;
rg35xxsp)
    T=${RG35_TOOLCHAIN:-$R/resources/toolchains/rg35xxsp}; CC=$T/bin/rg35-gcc; CXXLTO=-fno-lto
    TCFILE=$T/toolchain-rg35xxsp.cmake
    SDL_CFLAGS="-I$T/sdl2-stub/include/SDL2 -D_REENTRANT"
    SDL_LDLIBS="-L$T/sdl2-stub/lib -l:libSDL2-2.0.so.0 -Wl,--allow-shlib-undefined"
    LIBDIR=/usr/lib/aarch64-linux-gnu; ZLIB="-l:libz.a"; PNG="-l:libpng16.a"
    # host libpng (headers are arch independent, libpng16.a has no glibc 2.3x-only imports; the floor check below proves it)
    EXTRA_INC="-I/usr/include/libpng16"
    STATIC_LIBGCC_DIR=$T/sysroot/usr/lib/gcc/aarch64-linux-gnu/10 ;;
*) echo "unknown target $target" >&2; exit 2 ;;
esac
API=$W/mupen64plus-core-dento/src/api
mkdir -p "$W" "$O"

# ---- copies, in the workspace layout so the Makefiles' ../../../<sibling> paths work
cp_src() { mkdir -p "$W/$1"; rsync -a --delete --exclude .git --exclude '_obj*' --exclude '_out*' --exclude 'test-output' --exclude 'test-data' \
    --exclude /work --exclude /out --exclude '/build*' --exclude '*.a' --exclude '*.so' --exclude '*.so.*' --exclude 'mupen64plus-pow2' "$SRC/$1/" "$W/$1/"; }
for d in mupen64plus-core-dento mupen64plus-ui-inn mupen64plus-rdp-foir mupen64plus-rsp-armlet mupen64plus-audio-altru mupen64plus-input-suxty; do cp_src $d; done
mkdir -p "$W/mupen64plus-pow2"; rsync -a --delete --exclude '*.pyc' "$H/" "$W/mupen64plus-pow2/bundle/"
ln -sfn mupen64plus-core-dento "$W/mupen64plus-core"
(cd "$W/mupen64plus-pow2/bundle" && python3 gen-rename.py "$W" >/dev/null)

FOIRLIB=$W/mupen64plus-rdp-foir/projects/unix/$([ $target = x86_64 ] || echo _out_AARCH/)libfoir.a
MK=("${ARCHMK[@]}" CC="$CC" AR_LTO=gcc-ar APIDIR="$API" OPTFLAGS="-O3 $LTO")
if [ -z "$RELINK" ]; then
rm -rf "$W"/*/projects/unix/_obj*
echo "== core"
make -C "$W/mupen64plus-core-dento/projects/unix" -j"$JOBS" static "${MK[@]}" $([ $target = x86_64 ] || echo USE_GLES=1 GLES_LIB=) VULKAN=0 OSD=0 \
    ZLIB_CFLAGS= ZLIB_LDLIBS="$ZLIB" LIBPNG_CFLAGS="$EXTRA_INC" LIBPNG_LDLIBS="$PNG" SDL_CFLAGS="$SDL_CFLAGS" SDL_LDLIBS=
echo "== foir";   make -C "$W/mupen64plus-rdp-foir/projects/unix" -j"$JOBS" all BUNDLE=1 "${MK[@]}"
echo "== altru";  make -C "$W/mupen64plus-audio-altru/projects/unix" -j"$JOBS" all BUNDLE=1 "${MK[@]}" SDL_CFLAGS="$SDL_CFLAGS" SDL_LDLIBS=
echo "== suxty";  make -C "$W/mupen64plus-input-suxty/projects/unix" -j"$JOBS" all BUNDLE=1 "${MK[@]}" SDL_CFLAGS="$SDL_CFLAGS" SDL_LDLIBS=
echo "== armlet"
cmake -S "$W/mupen64plus-rsp-armlet" -B "$W/armlet-build" -G Ninja -DCMAKE_BUILD_TYPE=Release ${TCFILE:+-DCMAKE_TOOLCHAIN_FILE="$TCFILE"} \
    -DARMLET_STATIC=ON -DARMLET_BUNDLE_DIR="$W/mupen64plus-pow2/bundle" -DM64P_API_INCLUDE_DIR="$API" \
    -DCMAKE_C_FLAGS="$LTO" -DCMAKE_CXX_FLAGS="$CXXLTO" -DCMAKE_AR=/usr/bin/${X}gcc-ar -DCMAKE_RANLIB=/usr/bin/${X}gcc-ranlib >/dev/null
cmake --build "$W/armlet-build"
python3 "$W/mupen64plus-pow2/bundle/check-clashes.py" ui=/dev/null core="$W/mupen64plus-core-dento/projects/unix/libmupen64plus.a" \
    foir="$FOIRLIB" altru="$W/mupen64plus-audio-altru/projects/unix/libaltru.a" \
    suxty="$W/mupen64plus-input-suxty/projects/unix/libsuxty.a" armlet="$W/armlet-build/libarmlet.a" 2>/dev/null | tail -1 || true
fi   # RELINK
[ -n "$SKIP_LINK" ] && exit 0

echo "== link"
LIBS="$W/mupen64plus-core-dento/projects/unix/libmupen64plus.a $FOIRLIB $W/armlet-build/libarmlet.a $W/mupen64plus-audio-altru/projects/unix/libaltru.a $W/mupen64plus-input-suxty/projects/unix/libsuxty.a"
LD="-L$LIBDIR $ZLIB $PNG -lm -ldl -lpthread"
if [ -n "$STATIC_LIBGCC_DIR" ]; then
    "$T/bin/rg35-g++" -O2 -fno-lto -c "$H/stdcxx_compat.cpp" -o "$W/stdcxx_compat.o"
    LD="$W/stdcxx_compat.o -Wl,--wrap=pow -L$STATIC_LIBGCC_DIR $LD"
fi
make -C "$W/mupen64plus-ui-inn/projects/unix" all BUNDLE=1 "${MK[@]}" SDL_CFLAGS="$SDL_CFLAGS" SDL_LDLIBS="$SDL_LDLIBS" BUNDLE_LIBS="$LIBS" BUNDLE_LDLIBS="$LD"
cp "$W/mupen64plus-ui-inn/projects/unix/mupen64plus-pow2" "$O/"
f=$O/mupen64plus-pow2
echo "$f: $(stat -c %s "$f") bytes; exports: $(${X}nm -D --defined-only "$f" | wc -l)"
echo "NEEDED: $(${X}readelf -d "$f" | awk '/NEEDED/{print $5}' | tr -d '[]' | tr '\n' ' ')"
g=$(${X}objdump -T "$f" | grep -o 'GLIBC_[0-9.]*' | sort -V | tail -1); echo "glibc max: $g; GLIBCXX: $(${X}objdump -T "$f" | grep -o 'GLIBCXX_[0-9.]*' | sort -V | tail -1)"
if [ $target = x86_64 ]; then :; elif [ $target = rg35xxsp ] && [ "$(printf '%s\nGLIBC_2.17\n' "$g" | sort -V | tail -1)" != GLIBC_2.17 ]; then echo "FAIL: glibc floor above 2.17" >&2; exit 1; fi
