# UmaOS v2 Master Plan — Design Spec

## Overview

UmaOS v2 transforms the distro from a "branded Arch ISO" into a cohesive, immersive experience across five priority areas: a Welcome App hub, setup profiles, visual depth, developer tools, and a system monitor widget. The goal is to make UmaOS feel polished for new users, deeply themed for fans, and productive for developers.

**Target audiences:** Personal use, Uma Musume fans, Arch newcomers, developers.

## Architecture

All user-facing features funnel through the Welcome App as the central hub. The system monitor widget is independent and can be developed in parallel.

```
                    +---------------------+
                    |   Welcome App       |  <- First-login entry point
                    |   (PyQt6/QML)       |
                    +----------+----------+
                               |
            +------------------+------------------+
            |                  |                  |
     +------v------+   +------v------+   +-------v------+
     | Setup       |   | Theme       |   | Dev Tools    |
     | Profiles    |   | Manager     |   | Setup        |
     | (gaming,    |   | (wallpaper, |   | (IDE, AI,    |
     |  creator,   |   |  sounds,    |   |  containers, |
     |  laptop,    |   |  terminal,  |   |  SDK)        |
     |  dev)       |   |  colors)    |   |              |
     +-------------+   +-------------+   +--------------+
            |                  |                  |
            +------------------+------------------+
                               |
                    +----------v----------+
                    | System Monitor      |
                    | Widget              |
                    | (independent)       |
                    +---------------------+
```

**Priority order:**

| Priority | Item | Why this order |
|----------|------|----------------|
| P1 | Welcome App shell | Hub for everything; delivers immediate value |
| P2 | Setup Profiles | First feature inside Welcome App; most practical for new users |
| P3 | Visual Depth Pack (sounds, terminal, dynamic wallpapers, KWin) | Fills out theming; makes UmaOS feel complete |
| P4 | Dev Tools (IDE, AI tools, containers, SDK) | "Developer" profile + dedicated wizard page |
| P5 | System Monitor Widget | Independent; can be built anytime in parallel |

---

## P1: Welcome App (`umao-welcome`)

### Purpose

A branded PyQt6/QML application that launches on first login and serves as the front door to UmaOS — part welcome mat, part control center.

### Pages

1. **Welcome** — "Welcome, Trainer!" splash with UmaOS version, quick links (docs, GitHub, community). Random Uma Musume character illustration as hero image.

2. **Setup Profile** — Choose base profile(s): Gaming, Creator, Laptop, Developer. Profiles are additive (pick multiple). Each is a declarative YAML manifest. Links to P2.

3. **Theme Manager** — Pick wallpaper pack, toggle video wallpaper, preview/apply sound themes, switch cursor theme (absorbs `umao-cursor-switcher` functionality from its separate repo), toggle dynamic wallpaper mode.

4. **System Info** — Fastfetch-style hardware summary, driver status (GPU detected + recommended driver), disk usage, quick actions (update system, open terminal).

5. **About** — UmaOS credits, links, legal notice (fan project disclaimer).

### Technical Details

- **UI framework**: PyQt6 with QML for the UI layer, Python for business logic (consistent with existing `umao-dev-setup` pattern but using QML for richer visuals)
- Packaged as an Arch package in its own repo (`umao-welcome`)
- Autostart desktop entry replaces the current `umaos-first-login.desktop` / `umaos-theme-first-login.desktop` first-login hooks
- After first-run wizard completes, becomes a normal settings app accessible from app menu
- Profile manifests stored as YAML in `/usr/share/umao-welcome/profiles/`

### First-Run Wizard Flow

Linear wizard with back/next navigation:
1. Welcome splash (non-skippable, shows version + hero image)
2. Setup Profiles (checkboxes for each profile, descriptions + package counts)
3. Theme preferences (wallpaper pack, video wallpaper toggle, sound theme)
4. Confirmation (summary of selections, "Apply" button)
5. Progress (package installation with progress bar, then "Done!")

After first run, the app opens to the Welcome page as a tabbed settings app (non-wizard mode).

---

## P2: Setup Profiles System

### Profile Manifest Format (YAML)

```yaml
# /usr/share/umao-welcome/profiles/gaming.yaml
name: Gaming
version: 1
icon: uma-gaming
description: "Steam, Proton, and everything you need to race"
packages:
  pacman:
    - steam
    - gamemode
    - lib32-gamemode
    - mangohud
    - lib32-mangohud
  flatpak:
    - net.lutris.Lutris
  aur:
    - protonup-qt
configs:
  - source: gaming/gamemode.ini
    dest: ~/.config/gamemode.ini
    conflict: skip  # skip | overwrite | merge
services:
  enable:
    - steam-web.service
post_install:
  - umao-ensure-proton-ge
```

### Design Decisions

- **Additive, not exclusive** — Users can combine Gaming + Creator + Dev. Profiles only add packages/configs, never remove.
- **Config conflict resolution** — Each config entry has a `conflict` strategy: `skip` (default: apply only if file does not exist), `overwrite` (always replace), or `merge` (append non-duplicate lines). For dotfiles like `.bashrc`, profiles should use a sourced drop-in file pattern (e.g., `~/.config/umao/profile.d/gaming.sh` sourced from `.bashrc`) rather than modifying the dotfile directly.
- **Idempotent** — Running a profile twice is safe. Packages already installed get skipped.
- **Failure behavior** — Skip-and-continue: if a package fails to install, log the failure, continue with remaining packages, and report all failures at the end. The user can retry failed packages individually. Follows the existing `--best-effort` pattern from `build-iso.sh` driver installs.
- **No removal path (by design)** — Profiles install packages and configs. "Uninstalling" a profile would risk removing packages that other profiles or the user also depend on. Instead, users use standard `pacman -R` for individual packages. This is the Arch way.
- **Versioning** — Manifests include a `version:` field. When re-applying a profile whose version has changed, the CLI shows a diff of what changed and asks for confirmation before proceeding.
- **Two modes** — Wizard mode (inside Welcome App first-run) walks through profiles with descriptions and previews. CLI mode (`umao-profile apply gaming`) for headless/scripting use.
- **Dry run** — `umao-profile apply --dry-run gaming` shows what would be installed without doing it.
- **Custom profiles** — Users can drop their own YAML in `~/.config/umao/profiles/` and they appear in the Welcome App.

### Bundled Profiles

| Profile | Key Packages | Purpose |
|---------|-------------|---------|
| Gaming | Steam, Proton GE, Lutris, MangoHud, GameMode | Race-ready gaming |
| Creator | OBS, GIMP, Kdenlive, Audacity, Inkscape | Content creation |
| Laptop | auto-cpufreq, power-profiles-daemon | Battery life |
| Developer | See P4 section | Full dev environment |

---

## P3: Visual Depth Pack

### P3a: Sound Theme (`umao-sounds`)

A KDE-compatible FreeDesktop sound theme:

| Event | Sound | Style |
|-------|-------|-------|
| Login | Upbeat fanfare | ~2 sec, horse racing gate-open vibe |
| Logout | Wind-down chime | Gentle, brief |
| Notification | Soft bell | Not annoying for repeated notifications |
| Error | Comical stumble | Brief, distinctive |
| Trash | Thud | Satisfying weight |
| Volume change | Subtle click | Minimal |

- Packaged in `/usr/share/sounds/umao/`
- Applied via Welcome App's Theme Manager
- All sounds must be original or CC-licensed (not ripped from the game — legal compliance)

### P3b: Konsole Profile (`UmaOS-Terminal`)

- Color scheme matching `UmaSkyPink.colors`: sky-blue accents, pink selections, dark ink background (`uma.ink.900` / `#132B4F`), cloud-white text (`uma.cloud.050` / `#F8FBFF`)
- Custom PS1 prompt: `[uma] user@host ~/path $` with sky-blue brackets and pink `$`
- Shell startup: displays existing ASCII splash art + UmaOS version
- Font: JetBrains Mono Nerd (already bundled in packages.x86_64; overrides THEME-SPEC.md's `Noto Sans Mono` recommendation for terminal use — JetBrains Mono Nerd provides better ligature and icon support for developer workflows)
- Set as default Konsole profile during `umao-apply-theme`

### P3c: Dynamic Wallpaper System

Uses a lightweight systemd user timer + `plasma-apply-wallpaperimage` to switch wallpapers based on time of day (Plasma's built-in slideshow only supports interval-based rotation, not time-of-day scheduling):

- **Time-based wallpaper sets** — 4 wallpapers per pack (morning 6am / afternoon 12pm / evening 6pm / night 10pm)
- A systemd user timer (`umao-wallpaper.timer`) fires at each transition time and runs a small script that reads the current pack's `metadata.json` and applies the correct variant via `plasma-apply-wallpaperimage`
- **Wallpaper packs** as a concept: each pack is a directory with `metadata.json` describing the 4 variants + transition times
- **Default pack**: Abstract Uma-themed gradients (sky-blue morning, golden afternoon, pink sunset, deep ink night) — no character art to avoid IP issues for initial release
- Controllable from Welcome App's Theme Manager page
- Timer is only enabled when dynamic wallpaper mode is active (toggled in Theme Manager)

### P3d: KWin Animation Tweaks (`umao-kwin-effects`)

Subtle branded touches using existing KWin effect parameters (no custom C++):

- **Window open**: Slightly faster scale-up with a directional "dash" feel (tweak KWin scale effect parameters)
- **Desktop switch**: Horizontal slide (racing track direction feel)
- Packaged as a KWin script that sets parameters on built-in effects

---

## P4: Developer Tools Setup

### P4a: IDE/Editor Setup

**NeoVim (`umao-nvim-config`)**:
- Pre-configured NeoVim with curated plugins (LSP, treesitter, telescope, git integration)
- UmaOS color scheme matching UmaSkyPink palette tokens
- Installed to `/usr/share/umao/nvim/`, symlinked on profile activation
- Not forced — only applied if user selects Developer profile

**VS Code / Cursor (`umao-vscode-theme`)**:
- `umao-vscode-extensions` package installs a recommended extensions list (`.json` manifest)
- Hand-authored UmaOS color theme for VS Code (static JSON, based on UmaSkyPink palette)
- Applied via `code --install-extension` on profile activation

### P4b: AI Coding Tools

- Claude Code CLI pre-installed via npm or official installer, configured in PATH
- Pre-configured `.claude/` directory template with UmaOS project context (useful for contributors)
- Surfaced in Welcome App: "AI-assisted development is ready"

### P4c: Container/VM Tooling

- **Podman** (rootless, no daemon — better fit for Arch than Docker)
- **Distrobox** (run other distros' tools inside containers)
- **QEMU/KVM + virt-manager** (VM testing with GUI)
- All added via Developer profile's package list

### P4d: UmaOS SDK (`umao-sdk`) — Deferred to Post-V2

A CLI toolkit for contributors and theme creators. Deferred because there are no community contributors yet — build this when there is demand.

**Initial scope (v2):** Ship only `umao-sdk build-package` as part of the Developer profile. This wraps `makepkg` with UmaOS conventions and is immediately useful for maintainers.

**Future scope (when community exists):**

| Command | Purpose |
|---------|---------|
| `umao-sdk new-theme <name>` | Scaffold a new theme pack with correct directory structure and metadata |
| `umao-sdk new-widget <name>` | Scaffold a Plasma widget/plasmoid project |
| `umao-sdk lint` | Validate theme metadata, asset dimensions, color compliance with THEME-SPEC.md |
| `umao-sdk preview-theme` | Preview a theme in an isolated session (requires Xephyr + nested compositor — complex, build when needed) |

---

## P5: System Monitor Widget (`umao-race-stats`)

### Concept

A Plasma 6 plasmoid that displays system stats styled as Uma Musume race attributes.

### Stats Mapping

| System Metric | Uma Musume Equivalent | Visual |
|--------------|----------------------|--------|
| CPU usage | **Speed** | Horizontal bar, gradient blue-to-pink at high load |
| RAM usage | **Stamina** | Same bar style |
| Disk usage | **Power** | Same bar style |
| Network up/down | **Intelligence** | Numeric with up/down arrows |
| GPU temp | **Guts** | Color-coded number (green/yellow/red) |
| Uptime | **Race Time** | Clock format, resets daily |

### Technical Details

- Standard Plasma 6 plasmoid (QML + JavaScript)
- Reads from `/proc` and `sysfs` (standard Linux interfaces, no external dependencies)
- **Graceful degradation**: Stats that can't be read (e.g., GPU temp on systems without hwmon/nvidia-smi) are hidden rather than showing errors. The widget auto-detects available metrics at startup.
- Packaged as `umao-race-stats` Arch package
- Two sizes: compact (sidebar widget, 3-4 stats) and full (desktop widget, all stats)
- Refresh rate configurable (default: 2 seconds)
- Animations: bars pulse gently when values change, subtle "galloping" animation at high CPU
- Sky-blue background panel with pink accent bars, matching UmaSkyPink palette
- Opt-in via Welcome App's Theme Manager or manual widget add

---

## Package Summary

| Priority | Package Name | Type | Complexity |
|----------|-------------|------|------------|
| P1 | `umao-welcome` | PyQt6 app | Medium |
| P2 | `umao-profile` (CLI) | Bash/Python CLI | Medium |
| P3a | `umao-sounds` | FreeDesktop sound theme | Low |
| P3b | (part of `umao-apply-theme`) | Konsole profile + shell config | Low |
| P3c | (wallpaper packs) | Asset packages | Low-Medium |
| P3d | `umao-kwin-effects` | KWin script | Low |
| P4a | `umao-nvim-config` | NeoVim config package | Medium |
| P4a | `umao-vscode-theme` | VS Code extension | Medium |
| P4d | `umao-sdk build-package` only (rest deferred) | CLI wrapper | Low |
| P5 | `umao-race-stats` | Plasma 6 plasmoid | Medium |

## Dependencies Between Items

- P2 (Profiles) depends on P1 (Welcome App) for GUI mode, but CLI mode is independent
- P3 (Visual Depth) items are surfaced through P1's Theme Manager page
- P4 (Dev Tools) is a specialized profile within P2's system
- P5 (Widget) is fully independent

## Roadmap Reconciliation

This spec expands on ROADMAP.md phases 3-5:

| Roadmap Item | V2 Coverage |
|-------------|-------------|
| Phase 3: Full visual identity | P3 (Visual Depth Pack) completes the skeleton |
| Phase 5: One-command post-install setup profiles | P2 (Setup Profiles) — adds "Developer" profile beyond roadmap's gaming/creator/laptop |
| Phase 5: Troubleshooting wizard | Not in v2 scope — can be added as a Welcome App page later |
| Phase 5: Official docs site | Not in v2 scope — separate initiative |
| New: Welcome App | Not in original roadmap — added as the hub for all user-facing features |
| New: Dev Tools | Not in original roadmap — added based on developer audience needs |
| New: System Monitor Widget | Not in original roadmap — added for desktop personality |

ROADMAP.md should be updated when implementation begins to reflect the v2 plan.

## Legal Considerations

- All sound assets must be original or CC-licensed (no game rips)
- Default dynamic wallpaper pack should use abstract gradients, not character art
- Fan project disclaimer must appear in Welcome App's About page
- Same ASSET-LICENSES.md clearance process applies to all new visual assets
