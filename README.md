# UmaOS

UmaOS is an Arch Linux derivative focused on:

1. Easy installation for newcomers.
2. A cohesive Uma Musume-inspired KDE identity.

This repository builds a branded Arch ISO with:

- Calamares GUI installer path
- `archinstall` CLI fallback
- live-session installer auto-launch
- KDE theme pack skeleton (SDDM, wallpapers, colors, icon mapping)

## Project status

This is a v1 integration scaffold. It is intended for VM validation and iterative hardening before public release.

## Quick start

On an Arch-based build machine:

```bash
sudo pacman -S --needed archiso rsync pacman
./scripts/check-prereqs.sh
./scripts/build-iso.sh
./scripts/run-qemu.sh
```

Resulting ISOs are written to `out/`.

## Build on macOS (Docker wrapper)

If you do not want local Arch dependencies (`pacman`, `mkarchiso`) on macOS, use Docker:

```bash
./scripts/build-iso-docker.sh
```

Optional variables:

```bash
DOCKER_PLATFORM=linux/amd64 ./scripts/build-iso-docker.sh
UMAOS_ALLOW_AUR=1 ./scripts/build-iso-docker.sh
UMAOS_SKIP_DOCKER_BUILD=1 ./scripts/build-iso-docker.sh
MKARCHISO_MODES=iso ./scripts/build-iso-docker.sh
```

Notes:

- Docker runs the build in a privileged Arch container.
- The wrapper uses Docker named volumes for `build/` and `work/` so case-sensitive paths work correctly on macOS.
- Each build starts from a clean `work/` and `out/` state to avoid stale mkarchiso markers.
- Generated ISOs still end up in local `out/`.
- Optional cleanup of old host-side artifacts from earlier runs:
  `rm -rf work build`
- Build automatically runs ISO branding verification (`scripts/verify-iso-branding.sh`) after successful ISO creation.
- Skip verification with: `UMAOS_SKIP_BRANDING_VERIFY=1`.

## Package sourcing policy

UmaOS prefers official Arch repos.

- Default behavior: fail build if required packages are unavailable in official repos.
- Optional fallback: set `UMAOS_ALLOW_AUR=1` to build missing packages from AUR into a local repo used by `mkarchiso`.
- Current AUR-backed requirement: `plasma6-wallpapers-smart-video-wallpaper-reborn` (video wallpaper plugin).

Example:

```bash
UMAOS_ALLOW_AUR=1 ./scripts/check-prereqs.sh
UMAOS_ALLOW_AUR=1 ./scripts/build-iso.sh
```

## Installer flow

In the live KDE session:

- live boot target is `graphical.target` (SDDM enabled in the ISO)
- UEFI boot path uses GRUB (`uefi.grub`) so boot menu branding/background matches the themed experience.
- Calamares auto-launches once at login.
- Users can relaunch from `Install UmaOS` desktop icon or app menu entry.
- Desktop includes `Install Uma Musume.sh` to install the game via Steam (`steam://install/3224770`).
- Default wallpaper target is video: `/usr/share/wallpapers/UmaOS/contents/videos/qloo.mp4`.
- If Plasma crashes/restarts right after applying video wallpaper, UmaOS auto-falls back to static SVG and can log diagnostics.
- Manual controls: `umao-apply-theme --video`, `umao-apply-theme --no-video`, `umao-apply-theme --debug-video`.
- `umao-install` defaults to GUI-first and falls back to `archinstall` if Calamares is unavailable or exits with an error.
- Successful `pacman` package transactions print `Umazing!` via an ALPM post-transaction hook.

Installer command contract:

```bash
umao-install            # GUI first in desktop session; in TTY offers CLI fallback
umao-install --gui      # force Calamares
umao-install --cli      # force archinstall
```

## Theme pack structure

- Calamares branding: `archiso/airootfs/etc/calamares/branding/umaos`
- KDE colors: `archiso/airootfs/usr/share/color-schemes/UmaSkyPink.colors`
- Wallpaper pack: `archiso/airootfs/usr/share/wallpapers/UmaOS`
- Boot-art wallpaper option: `archiso/airootfs/usr/share/wallpapers/UmaBoot`
- SDDM theme: `archiso/airootfs/usr/share/sddm/themes/umaos-race`
- Icon mapping overlay: `archiso/airootfs/usr/share/icons/UmaOS-Papirus`
- Custom cursor packs: place `.tar.gz`/`.tgz` archives in `assets/cursors/`; build imports them into `/usr/share/icons`.

First-login theme apply hook:

- `/usr/local/bin/umao-apply-theme --once`
- autostarted from `/etc/skel/.config/autostart/umaos-first-login.desktop`

## Repository layout

- `scripts/` build and VM test utilities
- `archiso/` ArchISO overlay and package list
- `docs/` roadmap, theme spec, and licensing gates
- `assets/boot/` GRUB and Syslinux source images (`uma1*.png`)
- `assets/cursors/` cursor theme archives imported during build
- `assets/wallpapers/` source wallpaper/video files
- `assets/ascii/` terminal splash art sources

## Licensing and release guardrail

`Uma Musume: Pretty Derby` and related names, characters, logos, and media are owned by Cygames, Inc. and their respective rights holders.

UmaOS is a fan project and is not affiliated with or endorsed by Cygames.

Current styling direction intentionally matches franchise aesthetics, but **public redistribution must remain blocked until asset-rights clearance is complete**. Track all shipped assets in `docs/ASSET-LICENSES.md`.

If Cygames (or another valid rights holder) requests removal, the maintainers will remove affected assets and may take down this repository at any time.

## Acknowledgements

- Cursor theme packs (`assets/cursors/*.tar.gz`) are credited to the artist at: https://ko-fi.com/N4N8U8SL2
