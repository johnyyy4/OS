#!/usr/bin/env bash
# Build the felineOS live ISO with archiso.
# Usage: sudo ./build.sh        (output goes to ./out/)
#
# Steps:
#   1. Build our packages (packages/*) as your normal user into a local repo (./repo)
#   2. Make a copy of the archiso profile that points at that repo
#   3. Run mkarchiso
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
ROOT=$(pwd)

if [[ $EUID -ne 0 ]]; then
    echo "mkarchiso needs root. Run: sudo ./build.sh" >&2
    exit 1
fi
if [[ -z ${SUDO_USER:-} || $SUDO_USER == root ]]; then
    echo "Run this with sudo from your normal user (makepkg refuses to run as root)." >&2
    exit 1
fi
for cmd in mkarchiso makepkg repo-add; do
    command -v "$cmd" >/dev/null || { echo "Missing $cmd. Install: sudo pacman -S archiso base-devel" >&2; exit 1; }
done

as_user() { sudo -u "$SUDO_USER" -- "$@"; }

# --- 1. Build felineOS packages into a local repo -----------------------------
REPO="$ROOT/repo/x86_64"
rm -rf "$ROOT/repo" "$ROOT/build"
as_user mkdir -p "$REPO" "$ROOT/build/makepkg"

for pkgdir in packages/*/; do
    echo "==> Building package: $pkgdir"
    (cd "$pkgdir" && as_user env PKGDEST="$REPO" BUILDDIR="$ROOT/build/makepkg" SRCDEST="$ROOT/build/makepkg" \
        makepkg --nodeps --force --clean --noconfirm)
done
as_user repo-add -q "$REPO/felineos.db.tar.gz" "$REPO"/*.pkg.tar.zst

# --- 2. Profile copy pointing at the local repo -------------------------------
PROFILE="$ROOT/build/profile"
cp -a archiso "$PROFILE"
sed -i "s|@FELINEOS_REPO@|$REPO|" "$PROFILE/pacman.conf"

# --- 3. Build the ISO ----------------------------------------------------------
# Start from a clean work dir so old builds can't leak into new ones.
rm -rf work
mkdir -p out
mkarchiso -v -w work -o out "$PROFILE"

# Drop the multi-GB work dir and hand the results back to the user who ran sudo.
rm -rf work "$ROOT/build"
chown -R "$SUDO_UID:$SUDO_GID" out repo
echo
echo "Done. ISO:"
ls -lh out/*.iso
