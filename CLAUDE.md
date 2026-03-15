# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the scripts

Both scripts must be run from the project root directory with `bash` (not `sh` — the shebang is ignored if called with `sh` and will crash on bash-isms):

```bash
bash mf-bandit.sh          # TUI whiptail interface
bash nfc-bandit.sh backup  # CLI interface
bash nfc-bandit.sh restore -n data/mybadge-AABBCCDD-2026-01-01_12-00-00.dmp
bash nfc-bandit.sh clone
bash nfc-bandit.sh optimize
```

Hardware required: ACR122U-A9 NFC reader + libnfc 1.7.1 (newer versions have a driver bug with this reader).

## Architecture

Two parallel interfaces, identical core logic — **keep them in sync**:

| File | Interface |
|------|-----------|
| `nfc-bandit.sh` | CLI (read/echo) |
| `mf-bandit.sh` | TUI (whiptail + dialog) |

### Shared functions (must stay in sync between both scripts)

- `presence()` — calls `nfc-list`, returns 0=badge found (prints UID), 1=no badge, 2=hardware error
- `checkIfIndexed(uid)` — looks up UID in `assets/index.csv`, prepends known keys to the dictionary so mfoc finds them faster
- `mfocWithFallback(uid, output.dmp)` — runs mfoc with `| tee LastMfocOut.tmp`; on failure, falls back to mfcuk (darkside attack), injects found keys into dict, retries mfoc. Uses `${PIPESTATUS[0]}` to get mfoc's exit code through the pipe.
- `optimize(uid)` — called after a successful mfoc run; reads `LastMfocOut.tmp`, extracts keys via `grep -oE 'Found[[:space:]]+Key [AB]: [0-9a-fA-F]{12}'`, deduplicates and prepends them to `assets/dictionaire.keys`, updates `assets/index.csv`
- `manualOptimize()` — deduplicates dict and index without a fresh mfoc run (menu item 10 / `optimize` command)
- `buildFromSource(name)` — runs `autoreconf -i && ./configure && make && sudo make install` in `./libnfc`, `./mfoc`, or `./mfcuk`
- `checkDependencies()` — called at startup; auto-compiles from bundled sources if tools are missing

### Asset files

| Path | Purpose |
|------|---------|
| `assets/dictionaire.keys` | Key dictionary fed to mfoc `-f`; frequently-used keys are kept at the top. No comments, no blank lines (stripped by optimize). |
| `assets/index.csv` | `UID,key1,key2,...` — known keys per badge UID, used by checkIfIndexed to accelerate repeat encounters |
| `assets/dumb.dmb` | Blank badge image used by format() to wipe a badge |
| `data/` | Dump files (`.dmp`), created at runtime |

### Key implementation details

- `CURDIR=$(pwd)` is captured at startup. All functions `cd "$CURDIR"` before writing to `assets/` or `data/` because mfoc may change cwd.
- `optimize()` consumes `LastMfocOut.tmp` left by `mfocWithFallback()` — this temp file is the coupling point between the two functions; always clean it up on error paths.
- `cmp --ignore-initial=32` skips the first 32 bytes (sector 0 block 0, which contains the UID) when comparing dumps — necessary because the target badge has a different UID than the source.
- mfcuk key extraction uses `grep -oiE '\b[0-9a-f]{12}\b'` on raw mfcuk output — heuristic, may need tuning if mfcuk output format changes.
- `Filebrowser()` in mf-bandit.sh uses a bash array `dir_list` with `find . -maxdepth 1 -printf '%P\0'` to handle filenames with spaces.
- `dialog` (not whiptail) is used for `displayDump()` because it supports `--textbox` for scrollable content.

### Dependency build order

libnfc must be built before mfoc and mfcuk. Sources are bundled as git submodules/clones in `./libnfc/`, `./mfoc/`, `./mfcuk/`. `autoreconf -i` is used instead of `chmod +x configure` because autotools files may be absent from the clone.
