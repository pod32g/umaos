// UmaOS default panel layout
// Overrides the Breeze default to create a translucent bottom panel
// with custom Kickoff icon and pinned UmaOS apps.

var panel = new Panel
var panelScreen = panel.screen

panel.location = "bottom"

// Fixed 44px height to match UmaOS design
panel.height = 44

// Restrict horizontal panel to a maximum size of a 21:9 monitor
var maximumAspectRatio = 21 / 9;
if (panel.formFactor === "horizontal") {
    var geo = screenGeometry(panelScreen);
    var maximumWidth = Math.ceil(geo.height * maximumAspectRatio);
    if (geo.width > maximumWidth) {
        panel.alignment = "center";
        panel.minimumLength = maximumWidth;
        panel.maximumLength = maximumWidth;
    }
}

// ── Kickoff launcher with UmaOS green "U" icon ──
var kickoff = panel.addWidget("org.kde.plasma.kickoff")
kickoff.currentConfigGroup = ["Configuration", "General"]
kickoff.writeConfig("icon", "umaos-launcher")
kickoff.writeConfig("favoritesPortedToKAstats", true)

// ── Pinned application launchers ──
var tasks = panel.addWidget("org.kde.plasma.taskmanager")
tasks.currentConfigGroup = ["Configuration", "General"]
tasks.writeConfig("launchers", [
    "applications:systemsettings.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:helium-browser.desktop"
].join(","))

// Separator
panel.addWidget("org.kde.plasma.marginsseparator")

// ── IME support for CJK languages (needed for Japanese game) ──
var langIds = ["as", "bn", "bo", "brx", "doi", "gu", "hi", "ja",
               "kn", "ko", "kok", "ks", "lep", "mai", "ml", "mni",
               "mr", "ne", "or", "pa", "sa", "sat", "sd", "si",
               "ta", "te", "th", "ur", "vi", "zh_CN", "zh_TW"]
if (langIds.indexOf(languageId) != -1) {
    panel.addWidget("org.kde.plasma.kimpanel");
}

// ── System tray ──
panel.addWidget("org.kde.plasma.systemtray")

// ── Digital clock with date ──
var clock = panel.addWidget("org.kde.plasma.digitalclock")
clock.currentConfigGroup = ["Configuration", "Appearance"]
clock.writeConfig("showDate", true)
clock.writeConfig("dateFormat", "shortDate")

// ── Panel appearance: opaque dark green ──
// panelOpacity: 0 = adaptive, 1 = opaque, 2 = translucent
panel.currentConfigGroup = ["General"]
panel.writeConfig("panelOpacity", 1)
