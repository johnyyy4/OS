# felineOS 😼

An Arch-based Linux distro focused on cats, gaming, built to be lightweight and easy to rice

**Status:** no.

## Roadmap
1. **Base ISO**: boots, felineOS branding, reproducible build 
2. **Gaming base**: Steam, Proton, gamescope, MangoHud, GameMode, AMD/Intel drivers
3. **Desktop**: Hyprland (Wayland) with a default felineOS rice, including cat-themed options *(in progress: "Tabby" theme)*
4. **Installer**
5. **Later**: Steam console mode, own package repo, theme presets

## Building
Requires an Arch Linux host.

```sh
sudo pacman -S archiso base-devel
sudo ./build.sh
```

`build.sh` first builds our own packages (`packages/*`) into a local repo in `repo/`, then builds the ISO with them. The ISO ends up in `out/`.

## felineOS packages
Everything felineOS-specific is shipped as normal pacman packages, so installed systems get fixes through `pacman -Syu`:
- `felineos-desktop`: Hyprland and desktop apps, plus the Tabby theme installed as defaults in `/usr/share/felineos/config` (Hyprland, Waybar, fuzzel, mako) and `/etc/xdg/kitty` and wallpapers. We never overwrite files owned by other packages.
- `felineos-gaming`: Steam, gamescope, MangoHud, GameMode, Mesa and Vulkan drivers for AMD and Intel.
- `felineos-keyring`: the team's public signing keys (from `keyring/`), so pacman can verify the `[felineos]` repo. Also ships `/etc/pacman.d/felineos-mirrorlist`.

### Package repo
Installed systems get our packages from a signed pacman repo on GitHub Releases (tag `repo-x86_64`), with this in `/etc/pacman.conf`:
```ini
[felineos]
SigLevel = Required
Include = /etc/pacman.d/felineos-mirrorlist
```
pacman only accepts packages and databases signed by a key in `felineos-keyring`.

**Publishing:** bump `pkgrel` (or `pkgver`) of every package you changed, commit, push, then run:
```bash
./scripts/publish-repo.sh            # add --dry-run to build and sign without uploading
```
It builds only packages that are newer than the published ones, signs them with your key (gpg asks for your passphrase), and uploads them. It refuses to publish uncommitted work, or a changed package whose version wasn't bumped.

**Keys:** a new or lost key means changing `keyring/*.asc` and the fingerprint lists in `packages/felineos-keyring/PKGBUILD`, then bumping its `pkgrel` and publishing. A lost key goes into `_revoked`, not just deleted.

### Ricing
- **Hyprland:** `~/.config/hypr/hyprland.lua` loads the felineOS defaults with `dofile(...)`. Add your changes below that line and they override the defaults, while you still get theme updates.
- **Waybar, fuzzel, mako:** copy the folder from `/usr/share/felineos/config/<app>/` to `~/.config/<app>/` and edit your copy. Yours wins.
- **kitty:** copy `/etc/xdg/kitty/kitty.conf` to `~/.config/kitty/kitty.conf`.

## Testing in a VM
Boot the ISO in QEMU/virt-manager with **UEFI, Secure Boot off**. archiso images aren't signed for Secure Boot.
Hyprland needs 3D acceleration: use a **Virtio** video device with **3D acceleration** on, and Spice display with **OpenGL** on.

The live system logs in as user `feline` (no password, passwordless sudo) and starts Hyprland.
On boot it guesses the timezone from your public IP (ipapi.co, fallback ip-api.com), waiting at most ~8 s; offline it stays on UTC.

## Display
Resolution is automatic: Hyprland uses each monitor's native resolution (1080p, 1440p, 4K...).
**TODO:** some high-refresh monitors report 60 Hz as their preferred mode; we still need an automatic "highest refresh rate at native resolution" step.

## Default keybinds
| Keys | Action |
|---|---|
| Super + Enter | Terminal (kitty) |
| Super + Space | App launcher (fuzzel) |
| Super + Q | Close window |
| Super + E | File manager (Thunar) |
| Super + G | Steam |
| Super + V | Toggle floating |
| Super + 1–0 | Switch workspace |
| Super + Shift + 1–0 | Move window to workspace |
| Print | Screenshot a region to clipboard |
| Super + Shift + E | Exit Hyprland |

## Layout
- `archiso/`: the archiso profile, based on the official `releng` profile
  - `profiledef.sh`: ISO name, label, boot modes
  - `packages.x86_64`: packages included in the live system
  - `airootfs/`: files copied into the live system
- `packages/`: felineOS's own packages (PKGBUILD + `files/` laid out like the target system)
- `assets/wallpapers/`: wallpaper sources (SVG). Re-render with `rsvg-convert -w 3840 -h 2160 black-cat.svg -o black-cat.png`
  - `efiboot/`, `grub/`, `syslinux/`: boot menus
- `build.sh`: builds the ISO
- `scripts/publish-repo.sh`: publishes the signed `[felineos]` package repo
- `keyring/`: the team's public package signing keys

## Team
- johnyyy4
- pokoplokop2008

## License
felineOS is free software, licensed under the [GNU General Public License v3.0 or later](LICENSE) (GPL-3.0-or-later).
The `archiso/` profile is based on Arch Linux's official `releng` profile from [archiso](https://gitlab.archlinux.org/archlinux/archiso), which is also GPL-3.0-or-later.
Packages installed into the ISO (Hyprland, Steam, Mesa, ...) keep their own licenses.
