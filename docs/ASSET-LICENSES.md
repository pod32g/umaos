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
| assets/cursors/*.tar.gz | cursor theme archives | https://ko-fi.com/N4N8U8SL2 | pixloen (cursor artist) | TBD | pending | no | private build only | TBD | TBD | BLOCKED | Imported at build time into `/usr/share/icons`; artist credit: https://ko-fi.com/N4N8U8SL2 ; verify redistribution rights |
| assets/wallpapers/wallhaven/images/* | wallpaper images | https://wallhaven.cc/search?q=uma%20musume | individual Wallhaven uploaders | varies/unknown | pending | no | private build only | TBD | TBD | BLOCKED | Synced via `scripts/sync-wallhaven-wallpapers.py`; do not publicly redistribute until rights verified per image |
| steam://install/3224770 launcher script | software install helper | Steam app ID protocol | Valve / Cygames and related rights holders | N/A (runtime URL) | pending | yes | private build only | TBD | TBD | BLOCKED | First-login helper can trigger Steam install URL; game/software rights remain with their owners |
| archiso/airootfs/usr/share/wallpapers/UmaOS/contents/images/1920x1080.svg | wallpaper | local placeholder | UmaOS Project | CC0 (intended) | pending | yes | private build only | TBD | TBD | BLOCKED | Validate license annotation before release |
| archiso/airootfs/usr/share/wallpapers/UmaBoot/contents/images/1920x1080.png | wallpaper | derived from assets/boot/uma1.png | TBD | TBD | pending | yes | private build only | TBD | TBD | BLOCKED | Used for KDE wallpaper option and boot-art variant |
| archiso/airootfs/usr/share/wallpapers/UmaOS/contents/videos/qloo.mp4 | wallpaper video | provided media file | TBD | TBD | pending | no | private build only | TBD | TBD | BLOCKED | Confirm source rights before any public redistribution |
| archiso/airootfs/usr/share/sddm/themes/umaos-race/background.svg | sddm background | local placeholder | UmaOS Project | CC0 (intended) | pending | yes | private build only | TBD | TBD | BLOCKED | Validate license annotation before release |
