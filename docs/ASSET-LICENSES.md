# Asset License Register

Track each shipped image, icon, font, audio clip, and animation before release.

## Franchise ownership notice

`Uma Musume: Pretty Derby` and related names, characters, logos, and media are owned by Cygames, Inc. and their respective rights holders.

UmaOS is a fan project and is not affiliated with or endorsed by Cygames.

If Cygames (or another valid rights holder) requests removal, maintainers will remove affected assets and may take down this repository at any time.

## Required metadata fields

Every asset entry must include:

- Path
- Asset type
- Source URL or provenance statement
- Original creator/rights holder
- License
- Proof of license (URL, purchase receipt, contract, or grant)
- Modification status
- Allowed redistribution scope (private build only / public mirror allowed)
- Reviewer
- Review date
- Release gate status (`BLOCKED` or `CLEARED`)

## Release gate policy

- Any missing field => `BLOCKED`
- Any unknown or non-redistributable license => `BLOCKED`
- Any direct franchise-derived media without explicit permission => `BLOCKED`
- Public ISO release is allowed only when all bundled assets are `CLEARED`

## Register

| Path | Type | Source | Rights Holder | License | Proof | Modified | Redistribution | Reviewer | Review Date | Gate | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| assets/icons/.gitkeep | placeholder | N/A | N/A | N/A | N/A | no | N/A | TBD | TBD | BLOCKED | Replace with licensed icon assets |
| umao-cursor-switcher repo: cursors/*.tar.gz (24 packs) | cursor theme archives | https://ko-fi.com/N4N8U8SL2 | pixloen (cursor artist) | TBD — no grant on record | none | no | **must not redistribute** | TBD | TBD | BLOCKED | Moved out of this repo: the packs now live in the `umao-cursor-switcher` repo and are installed to `/usr/share/icons` by that package (which `packages.x86_64` pulls into the ISO). The old `assets/cursors/` path no longer exists. Bundled READMEs grant no redistribution rights; artist credit: https://ko-fi.com/N4N8U8SL2 |
| assets/wallpapers/wallhaven/images/ (gitignored; populated by sync) | wallpaper images | https://wallhaven.cc/search?q=uma%20musume | individual Wallhaven uploaders | varies/unknown | pending | no | private build only | TBD | TBD | BLOCKED | Synced via `scripts/sync-wallhaven-wallpapers.py`; do not publicly redistribute until rights verified per image |
| steam://install/3224770 launcher script | software install helper | Steam app ID protocol | Valve / Cygames and related rights holders | N/A (runtime URL) | pending | yes | private build only | TBD | TBD | BLOCKED | First-login helper can trigger Steam install URL; game/software rights remain with their owners |
| archiso/airootfs/usr/share/wallpapers/UmaOS/contents/images/1920x1080.jpg | wallpaper | provided media file | TBD | pack metadata claims CC0 | pending | no | private build only | TBD | TBD | BLOCKED | Pack metadata.json asserts CC0/UmaOS Project; provenance of the actual JPEG is unverified — validate before trusting that label |
| archiso/airootfs/usr/share/wallpapers/UmaOS/contents/images/3840x2160.jpg | wallpaper | provided media file | TBD | pack metadata claims CC0 | pending | no | private build only | TBD | TBD | BLOCKED | Same pack as above; unverified provenance |
| archiso/airootfs/usr/share/wallpapers/UmaOS/contents/videos/qloo.mp4 | wallpaper video | provided media file | TBD | TBD | pending | no | private build only | TBD | TBD | BLOCKED | Confirm source rights before any public redistribution; also duplicated at assets/wallpapers/qloo.mp4 |
| archiso/airootfs/usr/share/wallpapers/UmaBoot/contents/images/1920x1080.png | wallpaper | derived from assets/boot/uma1.png | TBD | Proprietary (per pack metadata) | pending | yes | private build only | TBD | TBD | BLOCKED | Pack metadata.json declares License=Proprietary |
| archiso/airootfs/usr/share/wallpapers/UmaMusumeDuo/contents/images/1920x1080.jpg | wallpaper | AlphaCoders | AlphaCoders / Cygames (franchise) | Proprietary (per pack metadata) | none | no | **must not redistribute** | TBD | TBD | BLOCKED | Pack metadata.json declares Author=AlphaCoders, License=Proprietary. Franchise-derived character art shipped in the ISO with no grant on record |
| archiso/airootfs/usr/share/wallpapers/UmaMusumeDuo/contents/images/3504x1971.png | wallpaper | AlphaCoders | AlphaCoders / Cygames (franchise) | Proprietary (per pack metadata) | none | no | **must not redistribute** | TBD | TBD | BLOCKED | As above |
| archiso/airootfs/usr/share/wallpapers/UmaMusumeRace/contents/images/1920x1080.jpg | wallpaper | AlphaCoders | AlphaCoders / Cygames (franchise) | Proprietary (per pack metadata) | none | no | **must not redistribute** | TBD | TBD | BLOCKED | As above |
| archiso/airootfs/usr/share/wallpapers/UmaMusumeRace/contents/images/2800x1980.png | wallpaper | AlphaCoders | AlphaCoders / Cygames (franchise) | Proprietary (per pack metadata) | none | no | **must not redistribute** | TBD | TBD | BLOCKED | As above |
| archiso/airootfs/usr/share/wallpapers/UmaOS-Dynamic/*.svg | wallpaper (generated) | generated gradients | UmaOS Project | CC0 (intended) | pending | yes | public mirror allowed (pending confirm) | TBD | TBD | BLOCKED | Time-of-day gradient SVGs; no franchise content |
| archiso/airootfs/usr/share/sddm/themes/umaos-race/background.jpg | sddm background | provided media file | TBD | TBD | pending | no | private build only | TBD | TBD | BLOCKED | Referenced by theme.conf `Background=background.jpg`; provenance unverified |
| ura_logo.png | franchise logo | URA / Uma Musume franchise | Cygames, Inc. | Proprietary (franchise) | none | no | **must not redistribute** | TBD | TBD | BLOCKED | Source image for the KSplash logo generated at build time by `install_uma_ksplash_theme` |
| archiso/airootfs/etc/calamares/branding/umaos/ura_logo.png | franchise logo | URA / Uma Musume franchise | Cygames, Inc. | Proprietary (franchise) | none | no | **must not redistribute** | TBD | TBD | BLOCKED | Copy of the franchise logo shipped in the installer branding (currently unreferenced by branding.desc) |
| archiso/airootfs/etc/calamares/branding/umaos/ura_logo_sidebar.png | franchise logo | URA / Uma Musume franchise | Cygames, Inc. | Proprietary (franchise) | none | no | **must not redistribute** | TBD | TBD | BLOCKED | Installer sidebar logo |
| archiso/airootfs/usr/share/sddm/themes/umaos-race/ura_logo.png | franchise logo | URA / Uma Musume franchise | Cygames, Inc. | Proprietary (franchise) | none | no | **must not redistribute** | TBD | TBD | BLOCKED | Login-screen logo |
| archiso/airootfs/usr/share/umaos/goldship.png | character art | Uma Musume franchise | Cygames, Inc. and/or original artist | Proprietary (franchise) | none | no | **must not redistribute** | TBD | TBD | BLOCKED | Character artwork shipped in the ISO |
| archiso/airootfs/usr/share/umaos/themes/konsole/goldship.webp | character art | Uma Musume franchise | Cygames, Inc. and/or original artist | Proprietary (franchise) | none | no | **must not redistribute** | TBD | TBD | BLOCKED | Konsole background artwork |
| archiso/airootfs/usr/share/umaos/uma-musume-icon.png | franchise icon | Uma Musume franchise | Cygames, Inc. | Proprietary (franchise) | none | no | **must not redistribute** | TBD | TBD | BLOCKED | Franchise-derived icon |
| archiso/airootfs/usr/share/umaos/sounds/login.ogg | audio | provided media file | TBD | TBD | pending | no | private build only | TBD | TBD | BLOCKED | Played on login by `umao-login-sound`; provenance unverified |
| assets/sounds/umao/stereo/*.oga | audio (unshipped) | placeholders | TBD | TBD | pending | no | private build only | TBD | TBD | BLOCKED | assets/sounds/umao/README.md states these are placeholders; currently not shipped by any build step or package |
| assets/boot/uma1.png, assets/boot/uma1-syslinux.png | boot art | derived franchise art | Cygames, Inc. and/or original artist | Proprietary (franchise) | none | yes | **must not redistribute** | TBD | TBD | BLOCKED | Source art for GRUB/syslinux boot branding |
| assets/wallpapers/bakushin.gif | animation (unreferenced) | Uma Musume franchise | Cygames, Inc. and/or original artist | Proprietary (franchise) | none | no | **must not redistribute** | TBD | TBD | BLOCKED | Tracked in git but referenced by nothing; delete or clear rights |
| archiso/airootfs/etc/calamares/branding/umaos/{banner,logo,welcome,wallpaper}.svg | installer branding | local artwork | UmaOS Project | CC0 (intended) | pending | yes | public mirror allowed (pending confirm) | TBD | TBD | BLOCKED | Generated/authored SVGs; confirm no franchise-derived elements |
| archiso/airootfs/usr/share/icons/UmaOS-Papirus/apps/scalable/{distributor-logo.svg,umaos-launcher.png} | launcher/distributor icon | local artwork | UmaOS Project | CC0 (intended) | pending | yes | public mirror allowed (pending confirm) | TBD | TBD | BLOCKED | Confirm the launcher glyph contains no franchise-derived elements |
| archiso/airootfs/usr/share/plymouth/themes/umaos/{logo.png,dot.png} | boot splash | local artwork | UmaOS Project | CC0 (intended) | pending | yes | public mirror allowed (pending confirm) | TBD | TBD | BLOCKED | Confirm provenance |
| archiso/airootfs/usr/share/grub/themes/umaos/logo.png | boot menu logo | local artwork | UmaOS Project | CC0 (intended) | pending | yes | public mirror allowed (pending confirm) | TBD | TBD | BLOCKED | The rest of the GRUB theme assets (background/menu_*/select_*/\*.pf2) are generated at build time and are not tracked |
| archiso/airootfs/usr/share/plasma/desktoptheme/umaos/**/panel-background.svg | plasma theme element | local artwork | UmaOS Project | CC0 (intended) | pending | yes | public mirror allowed (pending confirm) | TBD | TBD | BLOCKED | Panel background for the umaos Plasma desktop theme |
| archiso/airootfs/usr/share/icons/hicolor/scalable/apps/umaos-launcher.svg | launcher icon | local artwork | UmaOS Project | CC0 (intended) | pending | yes | public mirror allowed (pending confirm) | TBD | TBD | BLOCKED | Confirm the glyph contains no franchise-derived elements |
| archiso/airootfs/etc/calamares/umaos-defaults/branding/umaos/*.svg | installer branding (defaults copy) | local artwork | UmaOS Project | CC0 (intended) | pending | yes | public mirror allowed (pending confirm) | TBD | TBD | BLOCKED | Mirror of the live branding SVGs re-applied by umao-sync-calamares-config |
