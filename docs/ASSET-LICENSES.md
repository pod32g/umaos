# Asset License Register

Track each shipped image, icon, font, audio clip, and animation before release.

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
| assets/wallpapers/.gitkeep | placeholder | N/A | N/A | N/A | N/A | no | N/A | TBD | TBD | BLOCKED | Replace with licensed wallpaper assets |
| assets/icons/.gitkeep | placeholder | N/A | N/A | N/A | N/A | no | N/A | TBD | TBD | BLOCKED | Replace with licensed icon assets |
| archiso/airootfs/usr/share/wallpapers/UmaOS/contents/images/1920x1080.svg | wallpaper | local placeholder | UmaOS Project | CC0 (intended) | pending | yes | private build only | TBD | TBD | BLOCKED | Validate license annotation before release |
| archiso/airootfs/usr/share/wallpapers/UmaOS/contents/videos/qloo.mp4 | wallpaper video | provided media file | TBD | TBD | pending | no | private build only | TBD | TBD | BLOCKED | Confirm source rights before any public redistribution |
| archiso/airootfs/usr/share/sddm/themes/umaos-race/background.svg | sddm background | local placeholder | UmaOS Project | CC0 (intended) | pending | yes | private build only | TBD | TBD | BLOCKED | Validate license annotation before release |
