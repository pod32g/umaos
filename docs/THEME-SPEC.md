# UmaOS Theme Spec (v1)

## Goal

Define a cohesive KDE visual baseline for UmaOS using a sky-blue and pink accent palette.

## Palette tokens

| Token | Hex | Usage |
|---|---|---|
| `uma.sky.500` | `#2F74CC` | primary controls, focus, highlights |
| `uma.sky.700` | `#1F4F90` | dark primary surfaces |
| `uma.pink.400` | `#FF91C0` | accent, selection emphasis |
| `uma.pink.300` | `#FFD6E8` | soft accent backgrounds |
| `uma.ink.900` | `#132B4F` | dark text on light backgrounds |
| `uma.cloud.050` | `#F8FBFF` | light backgrounds |

## Typography direction

- UI family: `Noto Sans`
- Monospace: `Noto Sans Mono` (or distro fallback)
- Keep headings bold and rounded in feel, avoid condensed families.

## Icon strategy

- Base theme: `Papirus`
- Override theme: `UmaOS-Papirus`
- Required mapping rules:
  - keep freedesktop icon names for compatibility
  - only override brand-critical icons first (`distributor-logo`, installer icon)
  - keep unknown icons inherited from base theme

## Component targets

- SDDM: `umaos-race`
- Plasma colors: `UmaSkyPink.colors`
- Wallpapers: `/usr/share/wallpapers/UmaOS`
- Calamares branding: `/etc/calamares/branding/umaos`

## Placeholder asset specs

- Calamares banner: `960x160`, SVG preferred
- Calamares welcome: `640x320`, SVG preferred
- Wallpaper primary: `1920x1080`, SVG or PNG
- Wallpaper 4K: `3840x2160`, SVG or PNG
- SDDM background: `1920x1080`, SVG or PNG
- App/distributor logo: square `128x128` minimum

## Legal gate note

This project currently targets direct franchise styling by request.

`Uma Musume: Pretty Derby` and related names, characters, logos, and media are owned by Cygames, Inc. and their respective rights holders.

UmaOS is a fan project and is not affiliated with or endorsed by Cygames.

If Cygames (or another valid rights holder) requests removal, maintainers will remove affected assets and may take down this repository at any time.

Do not publish public ISO artifacts until all shipped assets are marked `CLEARED` in `docs/ASSET-LICENSES.md`.
