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
```

Notes:

- Docker runs the build in a privileged Arch container.
- The wrapper uses Docker named volumes for `build/` and `work/` so case-sensitive paths work correctly on macOS.
- Generated ISOs still end up in local `out/`.
- Optional cleanup of old host-side artifacts from earlier runs:
  `rm -rf work build`

## Calamares package sourcing policy

UmaOS prefers official Arch repos.

- Default behavior: fail build if required Calamares packages are unavailable.
- Optional fallback: set `UMAOS_ALLOW_AUR=1` to build missing Calamares packages from AUR into a local repo used by `mkarchiso`.

Example:

```bash
UMAOS_ALLOW_AUR=1 ./scripts/check-prereqs.sh
UMAOS_ALLOW_AUR=1 ./scripts/build-iso.sh
```

## Installer flow

In the live KDE session:

- Calamares auto-launches once at login.
- Users can relaunch from `Install UmaOS` desktop icon or app menu entry.
- `umao-install` defaults to GUI-first and falls back to `archinstall` if Calamares is unavailable or exits with an error.

Installer command contract:

```bash
umao-install            # GUI first, then CLI fallback
umao-install --gui      # force Calamares
umao-install --cli      # force archinstall
```

## Theme pack structure

- Calamares branding: `archiso/airootfs/etc/calamares/branding/umaos`
- KDE colors: `archiso/airootfs/usr/share/color-schemes/UmaSkyPink.colors`
- Wallpaper pack: `archiso/airootfs/usr/share/wallpapers/UmaOS`
- SDDM theme: `archiso/airootfs/usr/share/sddm/themes/umaos-race`
- Icon mapping overlay: `archiso/airootfs/usr/share/icons/UmaOS-Papirus`

First-login theme apply hook:

- `/usr/local/bin/umao-apply-theme --once`
- autostarted from `/etc/skel/.config/autostart/umaos-first-login.desktop`

## Repository layout

- `scripts/` build and VM test utilities
- `archiso/` ArchISO overlay and package list
- `docs/` roadmap, theme spec, and licensing gates
- `assets/` source artwork placeholders

## Licensing and release guardrail

Uma Musume assets are copyrighted.

Current styling direction intentionally matches franchise aesthetics, but **public redistribution must remain blocked until asset-rights clearance is complete**. Track all shipped assets in `docs/ASSET-LICENSES.md`.
