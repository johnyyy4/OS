#!/usr/bin/env bash
# Publish felineOS packages to the [felineos] pacman repo on GitHub Releases.
#
# Usage:  ./scripts/publish-repo.sh [--dry-run] [--key FINGERPRINT]
#
# What it does:
#   1. Checks git is clean and pushed (what's published must be in git).
#   2. Downloads the currently published database and checks its signature.
#   3. Builds only packages whose version is newer than the published one,
#      and refuses if a package changed since the last publish without a version bump.
#   4. Signs packages + database with your key (gpg asks for your passphrase).
#   5. Uploads packages first, database last, then removes replaced old packages.
#
# --dry-run  build and sign into a temp dir, upload nothing.
# --key      signing key fingerprint (default: the first felineOS key you have the secret key for).
# Run as your normal user, not with sudo. Needs: gh (logged in), base-devel, gnupg.
set -euo pipefail

GH_REPO=johnyyy4/OS
TAG=repo-x86_64
DB=felineos

cd "$(dirname "$(readlink -f "$0")")/.."
ROOT=$(pwd)

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

DRY_RUN=0
KEY=
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=1 ;;
        --key) KEY=${2:?--key needs a fingerprint}; shift ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

[[ $EUID -ne 0 ]] || die "run as your normal user, not root"
for cmd in gh git makepkg repo-add gpg gpgv vercmp bsdtar; do
    command -v "$cmd" >/dev/null || die "missing $cmd (Arch: sudo pacman -S --needed github-cli git base-devel gnupg)"
done

# --- git must match what's on GitHub -----------------------------------------
if [[ -n $(git status --porcelain) ]]; then
    ((DRY_RUN)) && echo "WARNING: uncommitted changes (ok for --dry-run)" >&2 \
                || die "uncommitted changes; commit and push first"
fi
if ((!DRY_RUN)); then
    git fetch -q origin
    [[ $(git rev-parse HEAD) == "$(git rev-parse '@{u}')" ]] \
        || die "your branch is not the same as origin; pull/push first"
fi
COMMIT=$(git rev-parse HEAD)

# --- signing key ---------------------------------------------------------------
mapfile -t TRUSTED < <(cd packages/felineos-keyring && source ./PKGBUILD && printf '%s\n' "${_trusted[@]}")
[[ ${#TRUSTED[@]} -gt 0 ]] || die "no trusted fingerprints in packages/felineos-keyring/PKGBUILD"
if [[ -z $KEY ]]; then
    for fpr in "${TRUSTED[@]}"; do
        if gpg --batch --list-secret-keys "$fpr" >/dev/null 2>&1; then KEY=$fpr; break; fi
    done
    [[ -n $KEY ]] || die "none of the felineOS signing keys is on this computer (GNUPGHOME=${GNUPGHOME:-~/.gnupg})"
fi
printf '%s\n' "${TRUSTED[@]}" | grep -qx "$KEY" || die "$KEY is not a trusted felineOS key"
gpg --batch --list-secret-keys "$KEY" >/dev/null 2>&1 || die "no secret key for $KEY"
info "Signing with $KEY"

STAGE=$(mktemp -d -t felineos-publish.XXXXXX)
((DRY_RUN)) || trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/old" "$STAGE/new" "$STAGE/build" "$STAGE/gnupg"
chmod 700 "$STAGE/gnupg"

# Keyring with only the trusted felineOS keys, to check what we download.
gpg --homedir "$STAGE/gnupg" --batch --quiet --import keyring/*.asc
gpg --homedir "$STAGE/gnupg" --batch --export "${TRUSTED[@]}" > "$STAGE/trusted.gpg"
verify_sig() {  # file sig -> ok only if signed by a trusted felineOS key
    local status
    status=$(gpgv --keyring "$STAGE/trusted.gpg" --status-fd 1 "$2" "$1" 2>/dev/null) \
        || die "bad signature on $(basename "$1")"
    local signer
    signer=$(awk '$2=="VALIDSIG"{print $NF}' <<<"$status")
    printf '%s\n' "${TRUSTED[@]}" | grep -qx "$signer" || die "$(basename "$1") signed by untrusted key $signer"
}

# --- currently published state ---------------------------------------------------
declare -A PUB_VER PUB_FILE
LAST_COMMIT=
RELEASE_EXISTS=0
if gh release view "$TAG" -R "$GH_REPO" >/dev/null 2>&1; then
    RELEASE_EXISTS=1
    info "Downloading published database"
    gh release download "$TAG" -R "$GH_REPO" -D "$STAGE/old" \
        -p "$DB.db" -p "$DB.db.sig" -p "$DB.files" -p "$DB.files.sig"
    for f in db files; do
        verify_sig "$STAGE/old/$DB.$f" "$STAGE/old/$DB.$f.sig"
        cp "$STAGE/old/$DB.$f" "$STAGE/new/$DB.$f.tar.gz"
    done
    while IFS=$'\t' read -r name ver file; do
        PUB_VER[$name]=$ver; PUB_FILE[$name]=$file
    done < <(bsdtar -xOf "$STAGE/old/$DB.db" '*/desc' | awk '
        /^%NAME%$/{getline n} /^%VERSION%$/{getline v} /^%FILENAME%$/{getline f}
        /^$/ && n && v && f {print n "\t" v "\t" f; n=v=f=""}
        END{if(n&&v&&f) print n "\t" v "\t" f}')
    LAST_COMMIT=$(gh release view "$TAG" -R "$GH_REPO" --json body -q .body \
        | grep -oE 'Published from commit [0-9a-f]{40}' | awk '{print $4}' || true)
else
    info "No release '$TAG' yet: this is the first publish"
fi

# --- decide what to build ----------------------------------------------------------
TO_BUILD=()
for dir in packages/*/; do
    dir=${dir%/}
    srcinfo=$(cd "$dir" && makepkg --printsrcinfo)
    name=$(awk -F' = ' '$1=="pkgname"{print $2; exit}' <<<"$srcinfo")
    pkgver=$(awk -F' = ' '$1=="\tpkgver"{print $2; exit}' <<<"$srcinfo")
    pkgrel=$(awk -F' = ' '$1=="\tpkgrel"{print $2; exit}' <<<"$srcinfo")
    epoch=$(awk -F' = ' '$1=="\tepoch"{print $2; exit}' <<<"$srcinfo")
    ver="${epoch:+$epoch:}$pkgver-$pkgrel"
    [[ -z $epoch ]] || die "$name: epoch is not supported (':' breaks GitHub asset names)"

    pub=${PUB_VER[$name]:-}
    if [[ -z $pub ]]; then
        info "$name $ver: new package"
        TO_BUILD+=("$dir")
        continue
    fi
    cmp=$(vercmp "$ver" "$pub")
    if ((cmp > 0)); then
        info "$name: $pub -> $ver"
        TO_BUILD+=("$dir")
    elif ((cmp < 0)); then
        die "$name: local version $ver is OLDER than published $pub"
    else
        paths=("$dir")
        if [[ $name == felineos-keyring ]]; then paths+=(keyring); fi
        if [[ -n $LAST_COMMIT ]] && git cat-file -e "$LAST_COMMIT" 2>/dev/null; then
            if ! git diff --quiet "$LAST_COMMIT" HEAD -- "${paths[@]}"; then
                die "$name changed since the last publish but is still $ver: bump pkgrel (or pkgver) in $dir/PKGBUILD"
            fi
        else
            echo "WARNING: can't tell if $name changed since the last publish (last commit unknown)" >&2
        fi
        info "$name $ver: unchanged, skipping"
    fi
done

if [[ ${#TO_BUILD[@]} -eq 0 ]]; then
    info "Nothing to publish: everything is up to date."
    exit 0
fi

# --- build + sign -----------------------------------------------------------------
NEW_PKGS=()
for dir in "${TO_BUILD[@]}"; do
    info "Building $dir"
    (cd "$dir" && PKGDEST="$STAGE/new" BUILDDIR="$STAGE/build" SRCDEST="$STAGE/build" \
        makepkg --nodeps --force --clean --noconfirm --sign --key "$KEY")
done
for f in "$STAGE"/new/*.pkg.tar.zst; do
    base=$(basename "$f")
    [[ $base =~ ^[A-Za-z0-9._-]+$ ]] || die "file name not safe for GitHub assets: $base"
    verify_sig "$f" "$f.sig"
    NEW_PKGS+=("$f")
done

info "Updating and signing the database"
repo-add --quiet --sign --key "$KEY" "$STAGE/new/$DB.db.tar.gz" "${NEW_PKGS[@]}"
# GitHub can't store symlinks: upload real files under the names pacman requests.
UPLOAD_DB=()
for f in db files; do
    cp "$STAGE/new/$DB.$f.tar.gz"     "$STAGE/new/upload-$DB.$f"
    cp "$STAGE/new/$DB.$f.tar.gz.sig" "$STAGE/new/upload-$DB.$f.sig"
    verify_sig "$STAGE/new/upload-$DB.$f" "$STAGE/new/upload-$DB.$f.sig"
done
mkdir -p "$STAGE/upload"
for f in db db.sig files files.sig; do
    mv "$STAGE/new/upload-$DB.$f" "$STAGE/upload/$DB.$f"
    UPLOAD_DB+=("$STAGE/upload/$DB.$f")
done

# Old package files that the new database no longer points to.
OLD_ASSETS=()
for f in "${NEW_PKGS[@]}"; do
    name=$(bsdtar -xOf "$f" .PKGINFO | awk -F' = ' '$1=="pkgname"{print $2}')
    old=${PUB_FILE[$name]:-}
    if [[ -n $old && $old != "$(basename "$f")" ]]; then OLD_ASSETS+=("$old" "$old.sig"); fi
done

if ((DRY_RUN)); then
    info "Dry run: nothing uploaded. Would upload:"
    for f in "${NEW_PKGS[@]}"; do echo "    $(basename "$f") + .sig"; done
    echo "    $DB.db $DB.db.sig $DB.files $DB.files.sig"
    if [[ ${#OLD_ASSETS[@]} -gt 0 ]]; then echo "  and delete: ${OLD_ASSETS[*]}"; fi
    echo "Files are in: $STAGE/new and $STAGE/upload"
    exit 0
fi

# --- upload: packages first, database last ------------------------------------------
NOTES="Signed pacman repository for felineOS. Do not download files from here by hand: use pacman with felineos-keyring.

Published from commit $COMMIT"
if ((!RELEASE_EXISTS)); then
    info "Creating release $TAG"
    gh release create "$TAG" -R "$GH_REPO" --target "$COMMIT" --latest=false \
        --title "felineOS package repository (x86_64)" --notes "$NOTES"
fi
info "Uploading packages"
for f in "${NEW_PKGS[@]}"; do
    gh release upload "$TAG" -R "$GH_REPO" --clobber "$f" "$f.sig"
done
info "Uploading database"
gh release upload "$TAG" -R "$GH_REPO" --clobber "${UPLOAD_DB[@]}"
for a in "${OLD_ASSETS[@]}"; do
    info "Removing old $a"
    gh release delete-asset "$TAG" "$a" -R "$GH_REPO" --yes || echo "WARNING: could not delete $a" >&2
done
gh release edit "$TAG" -R "$GH_REPO" --notes "$NOTES" >/dev/null

info "Published. Repo: https://github.com/$GH_REPO/releases/tag/$TAG"
