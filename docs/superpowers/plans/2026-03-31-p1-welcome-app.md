# P1: UmaOS Welcome App Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `umao-welcome`, a PyQt6/QML welcome wizard and settings app that launches on first login and serves as the hub for theme management, setup profiles, and system info.

**Architecture:** Python entry point loads a QML UI with a StackView for page navigation. First-run mode shows a linear wizard; subsequent launches show a tabbed settings app. The app calls existing `umao-*` scripts for theme application and system queries, and reads YAML profile manifests for the setup profiles page (profile engine is P2 — this plan only builds the UI shell and static profile display).

**Tech Stack:** Python 3, PyQt6, QML (Qt 6), YAML (PyYAML), existing `umao-*` shell scripts

**Spec:** `docs/superpowers/specs/2026-03-31-umaos-v2-master-plan-design.md` (P1 section)

---

## File Structure

All source lives in the repo root (matching `umao-dev-setup` / `umao-cursor-switcher` pattern). The PKGBUILD in `custom-pkgs/` fetches from GitHub releases.

### Application source files (new — created in repo root)

```
umao-welcome                    # Python entry point (executable script)
qml/
  Main.qml                     # Root window + page router (wizard vs tabs)
  WelcomePage.qml               # "Welcome, Trainer!" splash
  ProfilesPage.qml             # Setup profile selection (UI shell only)
  ThemeManagerPage.qml          # Theme settings (wallpaper, sounds, cursor)
  SystemInfoPage.qml            # Hardware summary + quick actions
  AboutPage.qml                 # Credits + legal
  components/
    NavBar.qml                 # Side navigation for tabbed mode
    WizardBar.qml              # Bottom bar with Back/Next for wizard mode
    ProfileCard.qml            # Reusable card for a single profile
    StatRow.qml                # Reusable row for system info display
    qmldir                     # QML module registration for components
profiles/
  gaming.yaml                  # Profile manifest (read-only display in P1)
  creator.yaml
  laptop.yaml
  developer.yaml
welcome.desktop                # Desktop entry for app menu
```

### ISO integration files (modified in this repo)

```
custom-pkgs/umao-welcome/PKGBUILD                              # New package build
archiso/airootfs/etc/skel/.config/autostart/umaos-welcome.desktop  # First-login autostart
scripts/build-iso.sh                                            # Add umao-welcome to REQUIRED_REPO_PKGS
archiso/airootfs/usr/local/bin/umao-finalize-installed-customization  # Add welcome.desktop to sync list + remove old first-login entries
archiso/airootfs/etc/skel/.config/autostart/umaos-first-login.desktop  # Remove (replaced by welcome app)
archiso/packages.x86_64                                         # Add umao-welcome + python-pyyaml
```

---

## Chunk 1: Project Skeleton + Entry Point

### Task 1: Create Python entry point

**Files:**
- Create: `umao-welcome`

- [ ] **Step 1: Write the entry point script**

```python
#!/usr/bin/env python3
"""UmaOS Welcome App — first-login wizard and settings hub."""

import os
import sys
import json
import subprocess

from PyQt6.QtWidgets import QApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import QObject, pyqtSlot, pyqtProperty, pyqtSignal, QUrl


class WelcomeBackend(QObject):
    """Bridge between QML UI and system operations."""

    modeChanged = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._first_run = not os.path.exists(self._state_path())

    def _state_path(self):
        return os.path.expanduser("~/.config/umaos/welcome-done")

    @pyqtProperty(bool, notify=modeChanged)
    def firstRun(self):
        return self._first_run

    @pyqtSlot()
    def markFirstRunDone(self):
        state_dir = os.path.dirname(self._state_path())
        os.makedirs(state_dir, exist_ok=True)
        with open(self._state_path(), "w") as f:
            f.write("1")
        self._first_run = False
        self.modeChanged.emit()

    @pyqtSlot(result=str)
    def getVersion(self):
        """Return UmaOS version string."""
        for path in ["/etc/umaos-release", "/usr/share/umaos/version"]:
            if os.path.isfile(path):
                with open(path) as f:
                    return f.read().strip()
        return "dev"

    @pyqtSlot(result=str)
    def getSystemInfo(self):
        """Return basic system info as JSON for the SystemInfo page."""
        info = {}
        try:
            result = subprocess.run(
                ["fastfetch", "--json"],
                capture_output=True, text=True, timeout=5,
            )
            if result.returncode == 0:
                info["fastfetch"] = json.loads(result.stdout)
        except (FileNotFoundError, subprocess.TimeoutExpired, json.JSONDecodeError):
            info["fastfetch"] = None

        try:
            result = subprocess.run(
                ["lspci", "-nn"],
                capture_output=True, text=True, timeout=5,
            )
            gpu_lines = [
                line for line in result.stdout.splitlines()
                if "VGA" in line or "3D" in line or "Display" in line
            ]
            info["gpu"] = gpu_lines[0] if gpu_lines else "Unknown"
        except (FileNotFoundError, subprocess.TimeoutExpired):
            info["gpu"] = "Unknown"

        return json.dumps(info)

    @pyqtSlot(result=str)
    def loadProfiles(self):
        """Load all YAML profile manifests, searching known paths."""
        import yaml

        search_paths = [
            os.path.join(os.path.dirname(os.path.abspath(__file__)), "profiles"),
            "/usr/share/umaos/welcome/profiles",
            os.path.expanduser("~/.config/umao/profiles"),
        ]

        profiles = []
        seen = set()

        for profiles_dir in search_paths:
            if not os.path.isdir(profiles_dir):
                continue
            for fname in sorted(os.listdir(profiles_dir)):
                if not fname.endswith(".yaml") or fname in seen:
                    continue
                seen.add(fname)
                path = os.path.join(profiles_dir, fname)
                try:
                    with open(path) as f:
                        data = yaml.safe_load(f)
                    if isinstance(data, dict) and "name" in data:
                        data["_filename"] = fname
                        profiles.append(data)
                except Exception:
                    continue

        return json.dumps(profiles)

    @pyqtSlot(str)
    def runCommand(self, cmd):
        """Run a shell command async (fire-and-forget for quick actions)."""
        # Split into args to avoid shell injection
        import shlex
        try:
            args = shlex.split(cmd)
            subprocess.Popen(args)
        except Exception:
            pass


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("UmaOS Welcome")
    app.setOrganizationName("UmaOS")

    engine = QQmlApplicationEngine()

    backend = WelcomeBackend()
    engine.rootContext().setContextProperty("backend", backend)

    qml_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "qml")
    # Fallback: check system install path
    if not os.path.isdir(qml_dir):
        qml_dir = "/usr/share/umaos/welcome"

    engine.load(QUrl.fromLocalFile(os.path.join(qml_dir, "Main.qml")))

    if not engine.rootObjects():
        print("ERROR: Failed to load QML", file=sys.stderr)
        sys.exit(1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Make it executable and test import**

Run: `chmod +x umao-welcome && python3 -c "import PyQt6; print('PyQt6 OK')"`
Expected: `PyQt6 OK` (or install `python-pyqt6` if missing)

- [ ] **Step 3: Commit**

```bash
git add umao-welcome
git commit -m "feat(welcome): add Python entry point with QML backend bridge"
```

---

### Task 2: Create root QML window with page router

**Files:**
- Create: `qml/Main.qml`
- Create: `qml/components/NavBar.qml`
- Create: `qml/components/WizardBar.qml`

- [ ] **Step 1: Write Main.qml with wizard/tab mode switching**

```qml
// qml/Main.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

ApplicationWindow {
    id: root
    visible: true
    width: 860
    height: 580
    minimumWidth: 700
    minimumHeight: 480
    title: "UmaOS Welcome"
    color: "#F8FBFF"

    property bool wizardMode: backend.firstRun
    property int currentPage: 0
    // In wizard mode, only pages 0-2 are shown (welcome, profiles, theme)
    // then the wizard completes. SystemInfo and About are settings-only.
    property var pageNames: ["welcome", "profiles", "theme", "systeminfo", "about"]
    property int wizardPageCount: 3  // welcome, profiles, theme

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Side nav (only in tabbed mode)
        NavBar {
            id: navBar
            visible: !root.wizardMode
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            currentIndex: root.currentPage
            onPageSelected: function(index) {
                root.currentPage = index
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            StackLayout {
                id: pageStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentPage

                WelcomePage {}
                ProfilesPage {}
                ThemeManagerPage {}
                SystemInfoPage {}
                AboutPage {}
            }

            // Wizard bar (only in wizard mode)
            WizardBar {
                visible: root.wizardMode
                Layout.fillWidth: true
                currentPage: root.currentPage
                pageCount: root.wizardPageCount
                onNext: {
                    if (root.currentPage < root.wizardPageCount - 1) {
                        root.currentPage++
                    } else {
                        // Wizard complete — mark done, switch to tabbed mode
                        backend.markFirstRunDone()
                        root.wizardMode = false
                        root.currentPage = 0
                    }
                }
                onBack: {
                    if (root.currentPage > 0)
                        root.currentPage--
                }
            }
        }
    }
}
```

- [ ] **Step 2: Write NavBar component**

```qml
// qml/components/NavBar.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: navRoot
    color: "#1F4F90"

    property int currentIndex: 0
    signal pageSelected(int index)

    property var items: [
        { label: "Welcome", icon: "\u{1F3E0}" },
        { label: "Profiles", icon: "\u{26A1}" },
        { label: "Theme", icon: "\u{1F3A8}" },
        { label: "System", icon: "\u{1F4BB}" },
        { label: "About", icon: "\u{2139}" }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 20
        spacing: 4

        Label {
            text: "UmaOS"
            color: "#F8FBFF"
            font.pixelSize: 22
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 16
        }

        Repeater {
            model: navRoot.items
            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                radius: 8
                color: navRoot.currentIndex === index
                    ? "#2F74CC"
                    : mouseArea.containsMouse ? "#264a7a" : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    spacing: 10

                    Label {
                        text: modelData.icon
                        font.pixelSize: 16
                    }
                    Label {
                        text: modelData.label
                        color: "#F8FBFF"
                        font.pixelSize: 14
                        font.bold: navRoot.currentIndex === index
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: navRoot.pageSelected(index)
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
```

- [ ] **Step 3: Write WizardBar component**

```qml
// qml/components/WizardBar.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: wizardBar
    height: 64
    color: "#FFFFFF"

    property int currentPage: 0
    property int pageCount: 5
    signal next()
    signal back()

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: "#E0E0E0"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20

        Button {
            text: "Back"
            visible: wizardBar.currentPage > 0
            flat: true
            onClicked: wizardBar.back()
        }

        Item { Layout.fillWidth: true }

        // Step indicator
        Row {
            spacing: 8
            Repeater {
                model: wizardBar.pageCount
                delegate: Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: index <= wizardBar.currentPage ? "#2F74CC" : "#D0D0D0"
                }
            }
        }

        Item { Layout.fillWidth: true }

        Button {
            text: wizardBar.currentPage === wizardBar.pageCount - 1
                ? "Get Started!"
                : "Next"
            highlighted: true
            palette.button: "#2F74CC"
            palette.buttonText: "#FFFFFF"
            onClicked: wizardBar.next()
        }
    }
}
```

- [ ] **Step 4: Write qml/components/qmldir**

QML needs this file to resolve component types from the `import "components"` directive in Main.qml.

```
NavBar 1.0 NavBar.qml
WizardBar 1.0 WizardBar.qml
ProfileCard 1.0 ProfileCard.qml
StatRow 1.0 StatRow.qml
```

Note: ProfileCard and StatRow don't exist yet — QML won't error on qmldir entries for missing files, it only errors when you try to instantiate them. They'll be created in Tasks 4 and 6.

- [ ] **Step 5: Test note**

Main.qml references page types (WelcomePage, etc.) that don't exist yet. QML will show warnings but the window will still open with empty StackLayout children. The pages are created in Tasks 3-7. Skip visual testing until Task 7.

- [ ] **Step 6: Commit**

```bash
git add qml/Main.qml qml/components/NavBar.qml qml/components/WizardBar.qml qml/components/qmldir
git commit -m "feat(welcome): add root QML window with wizard/tab mode router"
```

---

### Task 3: Create Welcome page

**Files:**
- Create: `qml/WelcomePage.qml`

- [ ] **Step 1: Write WelcomePage.qml**

```qml
// qml/WelcomePage.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: welcomeRoot

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24
        width: Math.min(parent.width - 80, 500)

        Label {
            text: "Welcome, Trainer!"
            font.pixelSize: 32
            font.bold: true
            color: "#132B4F"
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "Version " + backend.getVersion()
            font.pixelSize: 14
            color: "#4A6A8A"
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "UmaOS is ready for you."
            font.pixelSize: 16
            color: "#4A6A8A"
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#E8EEF4"
            Layout.topMargin: 8
            Layout.bottomMargin: 8
        }

        Label {
            text: "Quick Links"
            font.pixelSize: 14
            font.bold: true
            color: "#132B4F"
        }

        GridLayout {
            columns: 2
            rowSpacing: 12
            columnSpacing: 16
            Layout.fillWidth: true

            Repeater {
                model: [
                    { label: "Documentation", cmd: "xdg-open https://github.com/pod32g/umaos" },
                    { label: "Report a Bug", cmd: "xdg-open https://github.com/pod32g/umaos/issues" },
                    { label: "Open Terminal", cmd: "konsole" },
                    { label: "System Settings", cmd: "systemsettings" }
                ]

                delegate: Button {
                    text: modelData.label
                    Layout.fillWidth: true
                    flat: true
                    palette.buttonText: "#2F74CC"
                    onClicked: backend.runCommand(modelData.cmd)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add qml/WelcomePage.qml
git commit -m "feat(welcome): add Welcome page with quick links"
```

---

### Task 4: Create Profiles page (display-only shell)

**Files:**
- Create: `qml/ProfilesPage.qml`
- Create: `qml/components/ProfileCard.qml`
- Create: `profiles/gaming.yaml`
- Create: `profiles/creator.yaml`
- Create: `profiles/laptop.yaml`
- Create: `profiles/developer.yaml`

- [ ] **Step 1: Write ProfileCard component**

```qml
// qml/components/ProfileCard.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: card
    radius: 12
    color: selected ? "#EBF2FF" : "#FFFFFF"
    border.color: selected ? "#2F74CC" : "#E0E8F0"
    border.width: selected ? 2 : 1

    property string profileName: ""
    property string profileDesc: ""
    property string profileIcon: ""
    property bool selected: false
    signal toggled()

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.toggled()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        Label {
            text: card.profileIcon
            font.pixelSize: 28
        }

        Label {
            text: card.profileName
            font.pixelSize: 16
            font.bold: true
            color: "#132B4F"
        }

        Label {
            text: card.profileDesc
            font.pixelSize: 12
            color: "#4A6A8A"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: card.selected ? "#2F74CC" : "transparent"
            border.color: card.selected ? "#2F74CC" : "#C0C8D0"
            border.width: 2
            Layout.alignment: Qt.AlignRight

            Label {
                anchors.centerIn: parent
                text: "\u2713"
                color: "#FFFFFF"
                font.pixelSize: 14
                visible: card.selected
            }
        }
    }
}
```

- [ ] **Step 2: Write ProfilesPage.qml**

```qml
// qml/ProfilesPage.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: profilesRoot

    property var selectedProfiles: ({})
    property var profiles: []

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
                    onToggled: {
                        var s = profilesRoot.selectedProfiles
                        if (s[modelData.name]) {
                            delete s[modelData.name]
                        } else {
                            s[modelData.name] = true
                        }
                        profilesRoot.selectedProfiles = s
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Write profile YAML manifests**

`profiles/gaming.yaml`:
```yaml
name: Gaming
version: 1
icon: uma-gaming
description: "Steam, Proton, and everything you need to race."
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
    conflict: skip
services:
  enable: []
post_install:
  - umao-ensure-proton-ge
```

`profiles/creator.yaml`:
```yaml
name: Creator
version: 1
icon: uma-creator
description: "OBS, GIMP, Kdenlive, and creative tools for content creation."
packages:
  pacman:
    - obs-studio
    - gimp
    - kdenlive
    - audacity
    - inkscape
  flatpak: []
  aur: []
configs: []
services:
  enable: []
post_install: []
```

`profiles/laptop.yaml`:
```yaml
name: Laptop
version: 1
icon: uma-laptop
description: "Battery optimization and power management for portable use."
packages:
  pacman:
    - auto-cpufreq
    - power-profiles-daemon
  flatpak: []
  aur: []
configs: []
services:
  enable:
    - auto-cpufreq.service
post_install: []
```

`profiles/developer.yaml`:
```yaml
name: Developer
version: 1
icon: uma-developer
description: "Editors, containers, and AI tools for software development."
packages:
  pacman:
    - neovim
    - podman
    - distrobox
    - python-pip
    - nodejs
    - npm
  flatpak: []
  aur:
    - visual-studio-code-bin
configs: []
services:
  enable: []
post_install: []
```

- [ ] **Step 4: Commit**

```bash
git add qml/ProfilesPage.qml qml/components/ProfileCard.qml profiles/
git commit -m "feat(welcome): add Profiles page with YAML manifest display"
```

---

### Task 5: Create Theme Manager page (shell)

**Files:**
- Create: `qml/ThemeManagerPage.qml`

- [ ] **Step 1: Write ThemeManagerPage.qml**

```qml
// qml/ThemeManagerPage.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: themeRoot

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            anchors.margins: 32
            anchors.leftMargin: 32
            anchors.rightMargin: 32
            anchors.topMargin: 32
            spacing: 24

            Label {
                text: "Theme Manager"
                font.pixelSize: 24
                font.bold: true
                color: "#132B4F"
            }

            // Video wallpaper toggle
            Rectangle {
                Layout.fillWidth: true
                height: 72
                radius: 12
                color: "#FFFFFF"
                border.color: "#E0E8F0"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    ColumnLayout {
                        spacing: 4
                        Label {
                            text: "Video Wallpaper"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#132B4F"
                        }
                        Label {
                            text: "Use animated video as desktop background"
                            font.pixelSize: 12
                            color: "#4A6A8A"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Switch {
                        id: videoToggle
                        checked: true
                        onCheckedChanged: {
                            if (checked) {
                                backend.runCommand("umao-apply-theme --video")
                            } else {
                                backend.runCommand("umao-apply-theme --no-video")
                            }
                        }
                    }
                }
            }

            // Sound theme toggle
            Rectangle {
                Layout.fillWidth: true
                height: 72
                radius: 12
                color: "#FFFFFF"
                border.color: "#E0E8F0"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    ColumnLayout {
                        spacing: 4
                        Label {
                            text: "UmaOS Sounds"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#132B4F"
                        }
                        Label {
                            text: "Custom notification and system sounds"
                            font.pixelSize: 12
                            color: "#4A6A8A"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Switch {
                        id: soundToggle
                        checked: false
                        enabled: false  // P3a not yet implemented
                    }
                }
            }

            // Cursor theme button
            Rectangle {
                Layout.fillWidth: true
                height: 72
                radius: 12
                color: "#FFFFFF"
                border.color: "#E0E8F0"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    ColumnLayout {
                        spacing: 4
                        Label {
                            text: "Cursor Theme"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#132B4F"
                        }
                        Label {
                            text: "Change your mouse cursor style"
                            font.pixelSize: 12
                            color: "#4A6A8A"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Change"
                        onClicked: backend.runCommand("umao-cursor-switcher")
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add qml/ThemeManagerPage.qml
git commit -m "feat(welcome): add Theme Manager page shell"
```

---

### Task 6: Create System Info page

**Files:**
- Create: `qml/SystemInfoPage.qml`
- Create: `qml/components/StatRow.qml`

- [ ] **Step 1: Write StatRow component**

```qml
// qml/components/StatRow.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: statRow
    height: 48
    radius: 8
    color: "transparent"

    property string label: ""
    property string value: ""

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        Label {
            text: statRow.label
            font.pixelSize: 13
            font.bold: true
            color: "#132B4F"
            Layout.preferredWidth: 140
        }

        Label {
            text: statRow.value
            font.pixelSize: 13
            color: "#4A6A8A"
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
```

- [ ] **Step 2: Write SystemInfoPage.qml**

```qml
// qml/SystemInfoPage.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: sysRoot

    property var sysInfo: ({})

    Component.onCompleted: {
        var raw = backend.getSystemInfo()
        sysInfo = JSON.parse(raw)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 16

        Label {
            text: "System Info"
            font.pixelSize: 24
            font.bold: true
            color: "#132B4F"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: "#FFFFFF"
            border.color: "#E0E8F0"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 4

                StatRow {
                    Layout.fillWidth: true
                    label: "GPU"
                    value: sysRoot.sysInfo.gpu || "Detecting..."
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#F0F4F8" }

                StatRow {
                    Layout.fillWidth: true
                    label: "Kernel"
                    value: {
                        var ff = sysRoot.sysInfo.fastfetch
                        if (ff && Array.isArray(ff)) {
                            var k = ff.find(function(m) { return m.type === "Kernel" })
                            return k ? k.result : "Unknown"
                        }
                        return "Unknown"
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#F0F4F8" }

                StatRow {
                    Layout.fillWidth: true
                    label: "Desktop"
                    value: "KDE Plasma 6"
                }

                Item { Layout.fillHeight: true }
            }
        }

        // Quick actions
        RowLayout {
            spacing: 12
            Layout.fillWidth: true

            Button {
                text: "Update System"
                onClicked: backend.runCommand("konsole -e sudo pacman -Syu")
            }
            Button {
                text: "Driver Setup"
                onClicked: backend.runCommand("umao-driver-setup")
            }
            Button {
                text: "Audio Doctor"
                onClicked: backend.runCommand("umao-audio-doctor")
            }
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add qml/SystemInfoPage.qml qml/components/StatRow.qml
git commit -m "feat(welcome): add System Info page with hardware detection"
```

---

### Task 7: Create About page

**Files:**
- Create: `qml/AboutPage.qml`

- [ ] **Step 1: Write AboutPage.qml**

```qml
// qml/AboutPage.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: aboutRoot

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20
        width: Math.min(parent.width - 80, 480)

        Label {
            text: "UmaOS"
            font.pixelSize: 28
            font.bold: true
            color: "#132B4F"
            Layout.alignment: Qt.AlignHCenter
        }

        Label {
            text: "An Arch Linux derivative with Uma Musume spirit."
            font.pixelSize: 14
            color: "#4A6A8A"
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#E8EEF4"
        }

        Label {
            text: "Legal Notice"
            font.pixelSize: 14
            font.bold: true
            color: "#132B4F"
        }

        Label {
            text: "Uma Musume: Pretty Derby and related names, characters, logos, " +
                  "and media are owned by Cygames, Inc. and their respective " +
                  "rights holders.\n\n" +
                  "UmaOS is a fan project and is not affiliated with or endorsed " +
                  "by Cygames."
            font.pixelSize: 12
            color: "#4A6A8A"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            spacing: 12
            Layout.alignment: Qt.AlignHCenter

            Button {
                text: "GitHub"
                flat: true
                palette.buttonText: "#2F74CC"
                onClicked: backend.runCommand("xdg-open https://github.com/pod32g/umaos")
            }
            Button {
                text: "Report Issue"
                flat: true
                palette.buttonText: "#2F74CC"
                onClicked: backend.runCommand("xdg-open https://github.com/pod32g/umaos/issues")
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add qml/AboutPage.qml
git commit -m "feat(welcome): add About page with legal notice"
```

---

## Chunk 2: ISO Integration

### Task 8: Create PKGBUILD

**Files:**
- Create: `custom-pkgs/umao-welcome/PKGBUILD`

- [ ] **Step 1: Write PKGBUILD following existing pattern**

```bash
# Maintainer: pod32g
pkgname=umao-welcome
pkgver=1.0.0
pkgrel=1
pkgdesc="UmaOS welcome wizard and settings hub"
arch=('any')
url="https://github.com/pod32g/$pkgname"
license=('MIT')
depends=('python' 'python-pyqt6' 'python-pyyaml' 'qt6-declarative')
optdepends=(
    'fastfetch: hardware detection on System Info page'
    'konsole: terminal quick action'
)
source=("$pkgname-$pkgver.tar.gz::https://github.com/pod32g/$pkgname/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

package() {
    cd "$pkgname-$pkgver"

    # Main executable
    install -Dm755 umao-welcome "$pkgdir/usr/local/bin/umao-welcome"

    # QML files
    install -dm755 "$pkgdir/usr/share/umaos/welcome"
    install -Dm644 qml/*.qml "$pkgdir/usr/share/umaos/welcome/"

    # QML components + qmldir
    install -dm755 "$pkgdir/usr/share/umaos/welcome/components"
    install -Dm644 qml/components/*.qml "$pkgdir/usr/share/umaos/welcome/components/"
    install -Dm644 qml/components/qmldir "$pkgdir/usr/share/umaos/welcome/components/qmldir"

    # Profile manifests
    install -dm755 "$pkgdir/usr/share/umaos/welcome/profiles"
    install -Dm644 profiles/*.yaml "$pkgdir/usr/share/umaos/welcome/profiles/"

    # Desktop entry (app menu)
    install -Dm644 welcome.desktop "$pkgdir/usr/share/applications/umaos-welcome.desktop"
}
```

- [ ] **Step 2: Commit**

```bash
git add custom-pkgs/umao-welcome/PKGBUILD
git commit -m "feat(welcome): add PKGBUILD for umao-welcome package"
```

---

### Task 9: Create desktop entries

**Files:**
- Create: `welcome.desktop`
- Create: `archiso/airootfs/etc/skel/.config/autostart/umaos-welcome.desktop`

- [ ] **Step 1: Write app menu desktop entry**

`welcome.desktop`:
```desktop
[Desktop Entry]
Type=Application
Version=1.0
Name=UmaOS Welcome
Comment=UmaOS welcome wizard and settings
Exec=/usr/local/bin/umao-welcome
Icon=umaos-launcher
Terminal=false
Categories=Settings;System;
Keywords=welcome;setup;settings;umaos;
```

- [ ] **Step 2: Write autostart desktop entry for first login**

`archiso/airootfs/etc/skel/.config/autostart/umaos-welcome.desktop`:
```desktop
[Desktop Entry]
Type=Application
Version=1.0
Name=UmaOS Welcome (First Login)
Comment=Launch UmaOS welcome wizard on first login
Exec=/usr/local/bin/umao-welcome
Terminal=false
OnlyShowIn=KDE;
X-KDE-autostart-phase=2
```

- [ ] **Step 3: Commit**

```bash
git add welcome.desktop archiso/airootfs/etc/skel/.config/autostart/umaos-welcome.desktop
git commit -m "feat(welcome): add desktop entries for app menu and autostart"
```

---

### Task 10: Integrate into ISO build

**Files:**
- Modify: `scripts/build-iso.sh` (add `umao-welcome` to REQUIRED_REPO_PKGS)
- Modify: `archiso/packages.x86_64` (add `umao-welcome` and `python-pyyaml`)
- Modify: `archiso/airootfs/usr/local/bin/umao-finalize-installed-customization` (verify welcome desktop entry in sync list)

- [ ] **Step 1: Add umao-welcome to REQUIRED_REPO_PKGS in build-iso.sh**

Find the `REQUIRED_REPO_PKGS` array (around line 17) and add `umao-welcome`:

```bash
REQUIRED_REPO_PKGS=(
  calamares
  helium
  xorg-xkbcomp
  plasma6-wallpapers-smart-video-wallpaper-reborn
  yay
  helium-browser-bin
  umao-dev-setup
  umao-cursor-switcher
  umao-welcome
)
```

- [ ] **Step 2: Add packages to packages.x86_64**

Append to `archiso/packages.x86_64`:
```
umao-welcome
python-pyyaml
```

- [ ] **Step 3: Verify welcome desktop is in finalize-installed-customization sync list**

In `archiso/airootfs/usr/local/bin/umao-finalize-installed-customization`, check the autostart sync loop (around line 268). It should already include `umaos-welcome.desktop` based on current code. If not, add it to the for loop list.

- [ ] **Step 4: Commit**

```bash
git add scripts/build-iso.sh archiso/packages.x86_64 archiso/airootfs/usr/local/bin/umao-finalize-installed-customization
git commit -m "feat(welcome): integrate umao-welcome into ISO build pipeline"
```

---

## Chunk 3: Old Entry Removal + Final Verification

### Task 11: Remove old first-login autostart entries

The Welcome App replaces the old `umaos-first-login.desktop` hook that ran `umao-apply-theme --once`. The welcome app now handles first-login setup.

**Files:**
- Remove: `archiso/airootfs/etc/skel/.config/autostart/umaos-first-login.desktop`
- Remove: `archiso/airootfs/etc/skel/.config/autostart/umao-umamusume-first-login.desktop`
- Modify: `archiso/airootfs/usr/local/bin/umao-finalize-installed-customization` (remove old entries from autostart sync loop)

- [ ] **Step 1: Delete old autostart entries**

Run:
```bash
git rm -f archiso/airootfs/etc/skel/.config/autostart/umaos-first-login.desktop
git rm -f archiso/airootfs/etc/skel/.config/autostart/umao-umamusume-first-login.desktop
```

Note: If either file doesn't exist (already removed), the `-f` flag prevents errors.

- [ ] **Step 2: Remove from finalize-installed-customization sync loop**

In `archiso/airootfs/usr/local/bin/umao-finalize-installed-customization`, find the autostart sync loop (around line 268) and remove `umaos-first-login.desktop` and `umao-umamusume-first-login.desktop` from the for loop list. Keep `umaos-welcome.desktop` in the list.

- [ ] **Step 3: Commit**

```bash
git add -u archiso/airootfs/etc/skel/.config/autostart/ archiso/airootfs/usr/local/bin/umao-finalize-installed-customization
git commit -m "feat(welcome): replace old first-login hooks with welcome app autostart"
```

---

### Task 12: Final verification

- [ ] **Step 1: Verify all files exist**

Run: `find . -name '*.qml' -o -name '*.yaml' -o -name 'PKGBUILD' -o -name '*.desktop' -o -name 'umao-welcome' -o -name 'qmldir' | grep -v node_modules | grep -v .git | sort`

Expected: All files from the file structure section are listed.

- [ ] **Step 2: Verify Python entry point syntax**

Run: `python3 -m py_compile umao-welcome && echo "OK"`
Expected: `OK`

- [ ] **Step 3: Run QML lint if available**

Run: `which qmllint >/dev/null 2>&1 && find qml -name '*.qml' -exec qmllint {} + || echo "qmllint not available, skip"`

- [ ] **Step 4: Final commit if any uncommitted changes**

Run: `git status --short`
If any unstaged files related to umao-welcome exist, stage them explicitly and commit:
```bash
git add <specific-files> && git commit -m "chore(welcome): final cleanup and verification"
```
