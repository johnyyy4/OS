#!/usr/bin/env bash
# Build the felineOS live ISO with archiso.
# Usage: sudo ./build.sh        (output goes to ./out/)
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

if [[ $EUID -ne 0 ]]; then
    echo "mkarchiso needs root. Run: sudo ./build.sh" >&2
    exit 1
fi
command -v mkarchiso >/dev/null || { echo "archiso is not installed: sudo pacman -S archiso" >&2; exit 1; }

# Start from a clean work dir so old builds can't leak into new ones.
rm -rf work
mkdir -p out

mkarchiso -v -w work -o out archiso

# Hand the result back to the user who ran sudo, and drop the multi-GB work dir.
rm -rf work
[[ -n "${SUDO_UID:-}" ]] && chown "$SUDO_UID:$SUDO_GID" out out/*
echo
echo "Done. ISO:"
ls -lh out/*.iso
