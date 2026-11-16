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
- `felineos-desktop`: Hyprland and desktop apps, plus the Tabby theme installed as defaults in `/usr/share/felineos/config` (Hyprland, Waybar, fuzzel, kitty, mako) and wallpapers. We never overwrite files owned by other packages.
- `felineos-gaming`: Steam, gamescope, MangoHud, GameMode, Mesa and Vulkan drivers for AMD and Intel.

### Ricing
- **Hyprland:** `~/.config/hypr/hyprland.lua` loads the felineOS defaults with `dofile(...)`. Add your changes below that line and they override the defaults, while you still get theme updates.
- **Waybar, fuzzel, kitty, mako:** copy the folder from `/usr/share/felineos/config/<app>/` to `~/.config/<app>/` and edit your copy. Yours wins.

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

## Team
- johnyyy4
- pokoplokop2008
