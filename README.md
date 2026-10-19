# mupen64plus-pow2

One static Mupen64Plus executable for aarch64 retro handhelds: the core, the console front-end and a fixed set of four plugins, linked
together with LTO. No plugin search path, no `.so` files to deploy; `--gfx`, `--audio`, `--input`, `--rsp`, `--plugindir` and `--corelib`
are ignored with a warning. SDL2 stays dynamic (the device's own). Generic armv8-a, `-O3`.

## What Is Inside

- **Core (dento)**: `mupen64plus-core-dento`, our core fork; new arm64 dynarec on aarch64. Built with a built-in plugin table
  (`M64P_STATIC_PLUGINS`), no OSD (suxty draws the menu).
- **Front-end (inn)**: `mupen64plus-ui-inn`, the console front-end; in bundle mode the core is the executable itself.
- **Video (foir)**: `mupen64plus-rdp-foir`, LLE software RDP, hand-written NEON kernels, order-exact worker threads, no GPU rendering path.
- **RSP (arMLEt)**: `mupen64plus-rsp-armlet`, rsp-hle audio/JPEG/video HLE, native C/NEON graphics for the known ucodes (probe + validated latch for
  unknown ones), parallel-rsp's Lightning JIT as the reference and fallback for everything else, RDP list coalescing.
- **Audio (altru)**: `mupen64plus-audio-altru`, audio-sdl fork: dynamic rate control instead of pause/delay sync, normal-pitch fast-forward,
  automatic buffer size.
- **Input (suxty)**: `mupen64plus-input-suxty`, gamepad-only in-game menu: states, reset, remapping, hotkeys, foir and altru options.

## Layout

| path | content |
|---|---|
| `ext/` | the six components as submodules (`devel` branches) |
| `bundle/` | `build-bundle.sh`, `gen-rename.py`, `check-clashes.py`, generated rename headers and export lists, `stdcxx_compat.cpp` |
| `LICENSES/`, `NOTICE` | licence texts and the per-component table |

## How It Is Linked

- Each plugin builds as a static archive with its own symbol prefix (`foir_`, `armlet_`, `altru_`, `suxty_`, `ui_`): a generated header
  (`-include bundle/rename-<p>.h`) renames its plugin API exports and its `Config*` / `VidExt_*` / `Core*` pointer globals; `check-clashes.py` finds
  the remaining duplicate globals, which go in `bundle/extra-<p>.txt`.
- `plugin.c` in the core resolves the plugin API from a built-in table instead of `dlsym`.
- The executable exports only the core API (`--dynamic-list` + `--version-script`, `bundle/core_api.*`), which the plugins still look up with `dlsym`.
- suxty finds foir's and altru's option interfaces through weak symbols (the `dlopen` scan stays for `.so` builds).

## Build

```sh
git clone --recurse-submodules https://github.com/beebono/mupen64plus-pow2
bundle/build-bundle.sh x86_64                  # desktop, native gcc, scalar foir   -> out/x86_64/mupen64plus-pow2
bundle/build-bundle.sh aarch64                 # Ubuntu aarch64-linux-gnu-* cross   -> out/aarch64/mupen64plus-pow2
RG35_TOOLCHAIN=<path to toolchains/rg35xxsp> \
bundle/build-bundle.sh rg35xxsp                # glibc 2.31 sysroot, floor check <= 2.17 -> out/rg35xxsp/mupen64plus-pow2
POW2_SRC=sibling bundle/build-bundle.sh ...    # sources from ../<repo> instead of ext/
```

- Sources are copied to `work/<target>/` first; `JOBS`, `SDL2_LIBDIR` (aarch64: dir with the device's `libSDL2-2.0.so.0`), `SKIP_LINK=1`,
  `RELINK=1` are the knobs. An LTO link takes 7-10 minutes (mostly serial).
- aarch64 needs the Ubuntu cross toolchain plus cmake/ninja; rg35xxsp uses the host GCC 13 for C (LTO) and g++-12 for parallel-rsp (no LTO, the two
  LTO formats do not mix), with static libstdc++/libgcc from the sysroot. Two small shims in `bundle/stdcxx_compat.cpp` keep the glibc floor at 2.17.
- `vu_inline.cpp` (parallel-rsp, built with the fixed `-ffixed-x*` registers) is kept out of LTO.

## Running

```sh
./mupen64plus-pow2 --configdir <dir> --datadir <core data dir> game.z64
```

- On spruce the process must be called `./mupen64plus`: rename (or copy) `mupen64plus-pow2` at deploy time.
- No OSD from the core; the in-game menu is suxty's.

## Licence

GPL-3.0-or-later as a whole (foir and the arMLEt/Lightning combination are GPL-3 / LGPL-3, the rest is GPL-2.0-or-later). Per-component table in
[NOTICE](NOTICE), texts in [LICENSES/](LICENSES).
