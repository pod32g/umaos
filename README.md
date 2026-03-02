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

## Wallhaven wallpaper sync (Uma Musume)

Fetch all SFW results for `uma musume` from Wallhaven and stage them for ISO import:

```bash
python3 ./scripts/sync-wallhaven-wallpapers.py
```

Options:

```bash
# Metadata only (no downloads)
python3 ./scripts/sync-wallhaven-wallpapers.py --metadata-only

# Test subset of pages
python3 ./scripts/sync-wallhaven-wallpapers.py --max-pages 3

# Keep only desktop-grade images and remove low-res/weird-ratio local files
python3 ./scripts/sync-wallhaven-wallpapers.py \
  --min-width 1920 --min-height 1080 \
  --min-aspect 1.6 --max-aspect 1.9 \
  --prune-images
```

Build integration:

- If `assets/wallpapers/wallhaven/manifest.tsv` exists, `build-iso.sh` imports all downloaded files as KDE wallpaper options under `/usr/share/wallpapers/Wallhaven-*`.
- Disable import with `UMAOS_INCLUDE_WALLHAVEN=0`.
- Large downloads can significantly increase ISO size and build time.
- Build verification now checks that Wallhaven entries were actually imported when manifest import is enabled.

## Package sourcing policy

UmaOS prefers official Arch repos.

- Default behavior: fail build if required packages are unavailable in official repos.
- Optional fallback: set `UMAOS_ALLOW_AUR=1` to build missing packages from AUR into a local repo used by `mkarchiso`.
- Current AUR-backed requirements:
  - `plasma6-wallpapers-smart-video-wallpaper-reborn` (video wallpaper plugin)
  - `yay` (AUR helper included in live and installed UmaOS)

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
- On first login of an installed system, UmaOS now attempts to:
  - install Steam automatically (enabling `multilib` if needed), then
  - open `steam://install/3224770` for Umamusume.
- Default wallpaper target is video: `/usr/share/wallpapers/UmaOS/contents/videos/qloo.mp4`.
- In virtual machines, video wallpaper is skipped by default (use `umao-apply-theme --video` to force it).
- If Plasma crashes/restarts after applying video wallpaper, UmaOS auto-falls back to static SVG, clears `VideoUrls`, and records a disable marker at `~/.config/umaos/video-wallpaper.disabled`.
- Manual controls: `umao-apply-theme --video`, `umao-apply-theme --no-video`, `umao-apply-theme --debug-video`.
- `umao-install` defaults to GUI-first and falls back to `archinstall` if Calamares is unavailable or exits with an error.
- Before launching Calamares, `umao-install` re-syncs UmaOS Calamares defaults (`umao-sync-calamares-config`).
- Before launching Calamares, `umao-install` regenerates `unpackfs.conf` from detected live-media paths (`umao-prepare-calamares`) to avoid source-path install failures.
- Successful `pacman` package transactions print `Umazing!` via an ALPM post-transaction hook.
- `yay` is preinstalled as the AUR helper (`yay -S <package>`).

Installer command contract:

```bash
umao-install            # GUI first in desktop session; in TTY offers CLI fallback
umao-install --gui      # force Calamares
umao-install --cli      # force archinstall
sudo uma-update         # pull latest GitHub scripts and sync system script paths
umao-driver-setup --report-only
sudo umao-driver-setup --yes
umao-audio-doctor       # print audio diagnostics
sudo umao-audio-doctor --apply-thinkpad-p1-legacy
umao-debug              # collect a full diagnostics bundle (.tar.gz)
umao-debug-upload --host <ip> --user <user> [--password <pass>]  # upload bundle
```

Calamares integration:

- ArchISO post-package hook (`/etc/pacman.d/hooks/95-umao-calamares-config.hook`) reapplies UmaOS Calamares config from `/etc/calamares/umaos-defaults` so package defaults cannot override it.
- Build fallback (`/root/customize_airootfs.sh`) also re-syncs those defaults in chroot.
- Installer pre-initcpio fix normalizes `linux.preset` (`umao-fix-initcpio-preset`) to avoid ArchISO preset leakage into installed systems.
- Installer post-bootloader fix enforces valid `root=...` boot arguments (`umao-fix-boot-root-cmdline`) to prevent empty-root boot failures.
- Installer post-bootloader stage also applies GRUB branding (`umao-apply-grub-branding`) on systems that install GRUB.
- Installer post-bootloader finalizer (`umao-finalize-installed-customization`) applies live-theme defaults to installed users and system config (SDDM, KDE defaults, cursor defaults, lsb-release).
- Installer post-bootloader finalizer also enforces GUI boot (`graphical.target` + `sddm.service` symlinks) and pins SDDM to `DisplayServer=x11` for stability.
- During install, UmaOS runs `umao-driver-setup --yes --best-effort` automatically in target chroot via Calamares shellprocess stages.
- If hardware-specific driver installs fail (e.g. no network), installation continues and you can rerun manually after first boot.

`uma-update` options:

```bash
sudo uma-update --ref main
sudo uma-update --ref <tag-or-branch>
sudo uma-update --dry-run
scripts/verify-calamares-profile.sh archiso/airootfs
scripts/verify-customization-profile.sh build/profile/airootfs build/profile/packages.x86_64
scripts/audit-customization-parity.sh
```

## Theme pack structure

- Calamares branding: `archiso/airootfs/etc/calamares/branding/umaos`
- KDE colors: `archiso/airootfs/usr/share/color-schemes/UmaSkyPink.colors`
- Wallpaper pack: `archiso/airootfs/usr/share/wallpapers/UmaOS`
- Boot-art wallpaper option: `archiso/airootfs/usr/share/wallpapers/UmaBoot`
- SDDM theme: `archiso/airootfs/usr/share/sddm/themes/umaos-race`
- Plasma startup splash (KSplash): generated at build time from `ura_logo.png`
- Icon mapping overlay: `archiso/airootfs/usr/share/icons/UmaOS-Papirus`
- Custom cursor packs: place `.tar.gz`/`.tgz` archives in `assets/cursors/`; build imports them into `/usr/share/icons`.

First-login theme apply hook:

- `/usr/local/bin/umao-apply-theme --once`
- autostarted from `/etc/skel/.config/autostart/umaos-first-login.desktop`

Quick runtime checks (inside live/installed UmaOS):

```bash
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/umaos-race
umao-apply-theme --debug-video
umao-debug --journal-lines 800
umao-debug-upload --host 192.168.68.225 --user pod32g --password '<password>'
```

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
