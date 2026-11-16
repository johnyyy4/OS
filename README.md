# felineOS 

An Arch-based Linux distro focused on gaming, built to be lightweight, easy to rice, and nice to look at.

**Status:** early development. Right now it builds a console-only live ISO with felineOS branding.

## Roadmap
1. **Base ISO**: boots, felineOS branding, reproducible build *(in progress)*
2. **Gaming base**: Steam, Proton, gamescope, MangoHud, GameMode, GPU drivers, gaming kernel
3. **Desktop**: Hyprland (Wayland) with a default felineOS rice, including cat-themed options
4. **Installer**
5. **Later**: Steam console mode, own package repo, theme presets

## Building
Requires an Arch Linux host.

```sh
sudo pacman -S archiso
sudo ./build.sh
```

The ISO ends up in `out/`.

## Testing in a VM
Boot the ISO in QEMU/virt-manager with **UEFI, Secure Boot off**. archiso images aren't signed for Secure Boot.

## Layout
- `archiso/`: the archiso profile, based on the official `releng` profile
  - `profiledef.sh`: ISO name, label, boot modes
  - `packages.x86_64`: packages included in the live system
  - `airootfs/`: files copied into the live system
  - `efiboot/`, `grub/`, `syslinux/`: boot menus
- `build.sh`: builds the ISO

## Team
- johnyyy4
- pokoplokop2008
