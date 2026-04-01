# P2: Setup Profiles Engine Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `umao-profile`, a CLI tool that applies declarative YAML profile manifests (install packages, deploy configs, enable services, run post-install hooks). Integrate it with the Welcome App so users can apply profiles from the GUI.

**Architecture:** A standalone Python script (`umao-profile`) reads YAML manifests and orchestrates pacman/flatpak/yay for package installation, file deployment for configs, systemctl for services, and shell execution for post-install hooks. The Welcome App calls this CLI via subprocess with a `--json-progress` flag for real-time status updates.

**Tech Stack:** Python 3, PyYAML, subprocess (pacman/flatpak/yay/systemctl)

**Spec:** `docs/superpowers/specs/2026-03-31-umaos-v2-master-plan-design.md` (P2 section)

---

## File Structure

```
umao-profile                    # CLI tool (executable Python script)
```

Modified files:
```
umao-welcome                    # Add applyProfiles() backend method
qml/ProfilesPage.qml           # Add "Apply" button + progress display
custom-pkgs/umao-welcome/PKGBUILD  # Include umao-profile in package
```

---

## Chunk 1: CLI Tool

### Task 1: Create umao-profile CLI

**Files:**
- Create: `umao-profile`

- [ ] **Step 1: Write the CLI tool**

```python
#!/usr/bin/env python3
"""umao-profile — Apply UmaOS setup profiles."""

import argparse
import json
import os
import subprocess
import sys

import yaml


def load_profile(path):
    """Load and validate a profile YAML file."""
    with open(path) as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict) or "name" not in data:
        raise ValueError(f"Invalid profile: {path}")
    return data


def find_profile(name):
    """Find a profile YAML by name across search paths."""
    search_paths = [
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "profiles"),
        "/usr/share/umaos/welcome/profiles",
        os.path.expanduser("~/.config/umao/profiles"),
    ]
    fname = f"{name.lower()}.yaml"
    for d in search_paths:
        path = os.path.join(d, fname)
        if os.path.isfile(path):
            return path
    return None


def emit(msg, json_mode=False):
    """Print a status message."""
    if json_mode:
        print(json.dumps(msg), flush=True)
    else:
        status = msg.get("status", "info")
        text = msg.get("message", "")
        if status == "error":
            print(f"ERROR: {text}", file=sys.stderr)
        else:
            print(text)


def install_pacman(packages, dry_run=False, json_mode=False):
    """Install packages via pacman."""
    if not packages:
        return []
    emit({"status": "progress", "phase": "pacman", "message": f"Installing {len(packages)} pacman packages..."}, json_mode)
    if dry_run:
        emit({"status": "info", "message": f"  [dry-run] pacman -S --needed {' '.join(packages)}"}, json_mode)
        return []

    cmd = ["sudo", "pacman", "-S", "--needed", "--noconfirm"] + packages
    result = subprocess.run(cmd, capture_output=True, text=True)
    failures = []
    if result.returncode != 0:
        emit({"status": "warning", "message": f"  pacman had errors: {result.stderr.strip()}"}, json_mode)
        # Try packages individually to find which ones failed
        for pkg in packages:
            r = subprocess.run(
                ["sudo", "pacman", "-S", "--needed", "--noconfirm", pkg],
                capture_output=True, text=True,
            )
            if r.returncode != 0:
                failures.append(pkg)
                emit({"status": "error", "message": f"  Failed to install: {pkg}"}, json_mode)
    return failures


def install_aur(packages, dry_run=False, json_mode=False):
    """Install packages via yay (AUR helper)."""
    if not packages:
        return []
    emit({"status": "progress", "phase": "aur", "message": f"Installing {len(packages)} AUR packages..."}, json_mode)
    if dry_run:
        emit({"status": "info", "message": f"  [dry-run] yay -S --needed {' '.join(packages)}"}, json_mode)
        return []

    failures = []
    for pkg in packages:
        cmd = ["yay", "-S", "--needed", "--noconfirm", pkg]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            failures.append(pkg)
            emit({"status": "error", "message": f"  Failed to install AUR package: {pkg}"}, json_mode)
    return failures


def install_flatpak(packages, dry_run=False, json_mode=False):
    """Install packages via flatpak."""
    if not packages:
        return []
    emit({"status": "progress", "phase": "flatpak", "message": f"Installing {len(packages)} flatpak packages..."}, json_mode)
    if dry_run:
        for pkg in packages:
            emit({"status": "info", "message": f"  [dry-run] flatpak install -y {pkg}"}, json_mode)
        return []

    failures = []
    for pkg in packages:
        result = subprocess.run(
            ["flatpak", "install", "-y", pkg],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            failures.append(pkg)
            emit({"status": "error", "message": f"  Failed to install flatpak: {pkg}"}, json_mode)
    return failures


def deploy_configs(configs, profile_dir, dry_run=False, json_mode=False):
    """Deploy configuration files."""
    if not configs:
        return
    emit({"status": "progress", "phase": "configs", "message": f"Deploying {len(configs)} config files..."}, json_mode)

    for cfg in configs:
        source = os.path.join(profile_dir, cfg.get("source", ""))
        dest = os.path.expanduser(cfg.get("dest", ""))
        conflict = cfg.get("conflict", "skip")

        if not dest:
            continue

        if dry_run:
            emit({"status": "info", "message": f"  [dry-run] {source} -> {dest} (conflict={conflict})"}, json_mode)
            continue

        if not os.path.isfile(source):
            emit({"status": "warning", "message": f"  Config source not found: {source}"}, json_mode)
            continue

        if os.path.exists(dest):
            if conflict == "skip":
                emit({"status": "info", "message": f"  Skipping (exists): {dest}"}, json_mode)
                continue
            elif conflict == "merge":
                # Append non-duplicate lines
                with open(source) as f:
                    new_lines = f.readlines()
                with open(dest) as f:
                    existing = set(f.readlines())
                with open(dest, "a") as f:
                    for line in new_lines:
                        if line not in existing:
                            f.write(line)
                emit({"status": "info", "message": f"  Merged: {dest}"}, json_mode)
                continue

        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(source) as sf, open(dest, "w") as df:
            df.write(sf.read())
        emit({"status": "info", "message": f"  Deployed: {dest}"}, json_mode)


def enable_services(services, dry_run=False, json_mode=False):
    """Enable systemd services."""
    if not services:
        return
    emit({"status": "progress", "phase": "services", "message": f"Enabling {len(services)} services..."}, json_mode)

    for svc in services:
        if dry_run:
            emit({"status": "info", "message": f"  [dry-run] systemctl enable --now {svc}"}, json_mode)
            continue
        result = subprocess.run(
            ["sudo", "systemctl", "enable", "--now", svc],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            emit({"status": "warning", "message": f"  Failed to enable service: {svc}"}, json_mode)


def run_post_install(commands, dry_run=False, json_mode=False):
    """Run post-install hook commands."""
    if not commands:
        return
    emit({"status": "progress", "phase": "post_install", "message": f"Running {len(commands)} post-install hooks..."}, json_mode)

    for cmd in commands:
        if dry_run:
            emit({"status": "info", "message": f"  [dry-run] {cmd}"}, json_mode)
            continue
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0:
            emit({"status": "warning", "message": f"  Post-install hook failed: {cmd}"}, json_mode)


def apply_profile(profile_path, dry_run=False, json_mode=False):
    """Apply a single profile."""
    profile = load_profile(profile_path)
    profile_dir = os.path.dirname(profile_path)
    name = profile["name"]

    emit({"status": "start", "profile": name, "message": f"Applying profile: {name}"}, json_mode)

    pkgs = profile.get("packages", {})
    all_failures = []

    all_failures.extend(install_pacman(pkgs.get("pacman", []), dry_run, json_mode))
    all_failures.extend(install_aur(pkgs.get("aur", []), dry_run, json_mode))
    all_failures.extend(install_flatpak(pkgs.get("flatpak", []), dry_run, json_mode))

    deploy_configs(profile.get("configs", []), profile_dir, dry_run, json_mode)
    enable_services(profile.get("services", {}).get("enable", []), dry_run, json_mode)
    run_post_install(profile.get("post_install", []), dry_run, json_mode)

    if all_failures:
        emit({"status": "done", "profile": name, "failures": all_failures,
              "message": f"Profile {name} applied with {len(all_failures)} package failures: {', '.join(all_failures)}"}, json_mode)
    else:
        emit({"status": "done", "profile": name, "failures": [],
              "message": f"Profile {name} applied successfully!"}, json_mode)

    return all_failures


def cmd_apply(args):
    """Handle 'apply' subcommand."""
    all_failures = []
    for name in args.profiles:
        path = find_profile(name)
        if not path:
            emit({"status": "error", "message": f"Profile not found: {name}"}, args.json)
            all_failures.append(name)
            continue
        failures = apply_profile(path, dry_run=args.dry_run, json_mode=args.json)
        all_failures.extend(failures)

    if all_failures:
        emit({"status": "complete", "failures": all_failures,
              "message": f"Completed with {len(all_failures)} failures."}, args.json)
        sys.exit(1)
    else:
        emit({"status": "complete", "failures": [],
              "message": "All profiles applied successfully!"}, args.json)


def cmd_list(args):
    """Handle 'list' subcommand."""
    search_paths = [
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "profiles"),
        "/usr/share/umaos/welcome/profiles",
        os.path.expanduser("~/.config/umao/profiles"),
    ]
    seen = set()
    profiles = []
    for d in search_paths:
        if not os.path.isdir(d):
            continue
        for fname in sorted(os.listdir(d)):
            if not fname.endswith(".yaml") or fname in seen:
                continue
            seen.add(fname)
            try:
                p = load_profile(os.path.join(d, fname))
                profiles.append(p)
            except Exception:
                continue

    if args.json:
        print(json.dumps(profiles, indent=2))
    else:
        for p in profiles:
            desc = p.get("description", "")
            print(f"  {p['name']:12s} — {desc}")


def main():
    parser = argparse.ArgumentParser(
        prog="umao-profile",
        description="Apply UmaOS setup profiles",
    )
    sub = parser.add_subparsers(dest="command")

    apply_p = sub.add_parser("apply", help="Apply one or more profiles")
    apply_p.add_argument("profiles", nargs="+", help="Profile names to apply")
    apply_p.add_argument("--dry-run", action="store_true", help="Show what would be done without doing it")
    apply_p.add_argument("--json", action="store_true", help="Output JSON progress messages")

    list_p = sub.add_parser("list", help="List available profiles")
    list_p.add_argument("--json", action="store_true", help="Output as JSON")

    args = parser.parse_args()
    if args.command == "apply":
        cmd_apply(args)
    elif args.command == "list":
        cmd_list(args)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Make executable and verify syntax**

Run: `chmod +x umao-profile && python3 -m py_compile umao-profile && echo "OK"`

- [ ] **Step 3: Test list command**

Run: `python3 umao-profile list`
Expected: Lists 4 profiles (Gaming, Creator, Laptop, Developer)

- [ ] **Step 4: Test dry-run**

Run: `python3 umao-profile apply --dry-run gaming`
Expected: Shows what would be installed without doing anything

- [ ] **Step 5: Commit**

```bash
git add umao-profile
git commit -m "feat(profiles): add umao-profile CLI tool for profile application"
```

---

## Chunk 2: Welcome App Integration

### Task 2: Add profile application to Welcome App backend

**Files:**
- Modify: `umao-welcome` (add `applyProfiles` method to WelcomeBackend)

- [ ] **Step 1: Add applyProfiles method to WelcomeBackend**

Add this method to the `WelcomeBackend` class in `umao-welcome`, after the `runCommand` method:

```python
    @pyqtSlot(str, result=str)
    def applyProfiles(self, profile_names_json):
        """Apply selected profiles via umao-profile CLI. Returns JSON result."""
        names = json.loads(profile_names_json)
        if not names:
            return json.dumps({"status": "complete", "failures": [], "message": "No profiles selected."})

        umao_profile = os.path.join(os.path.dirname(os.path.abspath(__file__)), "umao-profile")
        if not os.path.isfile(umao_profile):
            umao_profile = "/usr/local/bin/umao-profile"

        cmd = [sys.executable, umao_profile, "apply", "--json"] + names
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            # Parse the last JSON line (the completion message)
            lines = [l for l in result.stdout.strip().splitlines() if l.strip()]
            if lines:
                return lines[-1]
            return json.dumps({"status": "error", "message": "No output from umao-profile"})
        except subprocess.TimeoutExpired:
            return json.dumps({"status": "error", "message": "Profile application timed out"})
        except Exception as e:
            return json.dumps({"status": "error", "message": str(e)})
```

- [ ] **Step 2: Commit**

```bash
git add umao-welcome
git commit -m "feat(profiles): add applyProfiles backend method to welcome app"
```

---

### Task 3: Update ProfilesPage with Apply button

**Files:**
- Modify: `qml/ProfilesPage.qml` (add Apply button and result display)

- [ ] **Step 1: Update ProfilesPage.qml**

Replace the entire content of `qml/ProfilesPage.qml` with:

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: profilesRoot

    property var selectedProfiles: ({})
    property var profiles: []
    property bool applying: false
    property string resultMessage: ""

    Component.onCompleted: {
        var data = backend.loadProfiles()
        profiles = JSON.parse(data)
    }

    property var iconMap: ({
        "Gaming": "\u{1F3AE}",
        "Creator": "\u{1F3AC}",
        "Laptop": "\u{1F4BB}",
        "Developer": "\u{1F6E0}"
    })

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 16

        Label {
            text: "Choose Your Setup"
            font.pixelSize: 24
            font.bold: true
            color: "#132B4F"
        }

        Label {
            text: "Select one or more profiles. You can always change this later."
            font.pixelSize: 14
            color: "#4A6A8A"
        }

        GridLayout {
            columns: 2
            rowSpacing: 16
            columnSpacing: 16
            Layout.fillWidth: true
            Layout.fillHeight: true

            Repeater {
                model: profilesRoot.profiles
                delegate: ProfileCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    profileName: modelData.name || ""
                    profileDesc: modelData.description || ""
                    profileIcon: profilesRoot.iconMap[modelData.name] || "\u{1F4E6}"
                    selected: !!profilesRoot.selectedProfiles[modelData.name]
                    enabled: !profilesRoot.applying
                    onToggled: {
                        var s = profilesRoot.selectedProfiles
                        if (s[modelData.name]) {
                            delete s[modelData.name]
                        } else {
                            s[modelData.name] = true
                        }
                        profilesRoot.selectedProfiles = s
                        profilesRoot.resultMessage = ""
                    }
                }
            }
        }

        // Result message
        Label {
            visible: profilesRoot.resultMessage !== ""
            text: profilesRoot.resultMessage
            font.pixelSize: 13
            color: profilesRoot.resultMessage.indexOf("success") >= 0 ? "#2E7D32" : "#C62828"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // Apply button
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item { Layout.fillWidth: true }

            BusyIndicator {
                visible: profilesRoot.applying
                running: profilesRoot.applying
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
            }

            Button {
                text: profilesRoot.applying ? "Applying..." : "Apply Selected Profiles"
                enabled: !profilesRoot.applying && Object.keys(profilesRoot.selectedProfiles).length > 0
                highlighted: true
                palette.button: "#2F74CC"
                palette.buttonText: "#FFFFFF"
                onClicked: {
                    var names = Object.keys(profilesRoot.selectedProfiles)
                    profilesRoot.applying = true
                    profilesRoot.resultMessage = ""
                    var result = backend.applyProfiles(JSON.stringify(names))
                    var parsed = JSON.parse(result)
                    profilesRoot.resultMessage = parsed.message || "Done"
                    profilesRoot.applying = false
                }
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add qml/ProfilesPage.qml
git commit -m "feat(profiles): add Apply button and result display to ProfilesPage"
```

---

### Task 4: Update PKGBUILD to include umao-profile

**Files:**
- Modify: `custom-pkgs/umao-welcome/PKGBUILD`

- [ ] **Step 1: Add umao-profile to PKGBUILD**

In the `package()` function, after the line that installs `umao-welcome`, add:

```bash
    install -Dm755 umao-profile "$pkgdir/usr/local/bin/umao-profile"
```

- [ ] **Step 2: Commit**

```bash
git add custom-pkgs/umao-welcome/PKGBUILD
git commit -m "feat(profiles): include umao-profile CLI in welcome package"
```

---

### Task 5: Final verification

- [ ] **Step 1: Verify CLI syntax**

Run: `python3 -m py_compile umao-profile && echo "OK"`

- [ ] **Step 2: Verify list command works**

Run: `python3 umao-profile list`

- [ ] **Step 3: Verify dry-run**

Run: `python3 umao-profile apply --dry-run gaming creator`

- [ ] **Step 4: Check git log**

Run: `git log --oneline -5`
