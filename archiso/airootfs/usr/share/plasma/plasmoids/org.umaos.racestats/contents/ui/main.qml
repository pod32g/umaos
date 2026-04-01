import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation

    property int refreshInterval: 2000

    Timer {
        id: refreshTimer
        interval: root.refreshInterval
        running: true
        repeat: true
        onTriggered: sysInfo.update()
    }

    QtObject {
        id: sysInfo

        property real cpuUsage: 0
        property real memUsage: 0
        property real diskUsage: 0
        property string netUp: "0 B/s"
        property string netDown: "0 B/s"
        property string gpuTemp: "--"
        property string uptime: "0:00"

        function update() {
            // Read CPU usage
            var cpuProc = readFile("/proc/stat")
            if (cpuProc) {
                parseCpu(cpuProc)
            }

            // Read memory
            var memProc = readFile("/proc/meminfo")
            if (memProc) {
                parseMem(memProc)
            }

            // Read uptime
            var uptimeProc = readFile("/proc/uptime")
            if (uptimeProc) {
                parseUptime(uptimeProc)
            }
        }

        property var lastCpuIdle: 0
        property var lastCpuTotal: 0

        function parseCpu(data) {
            var lines = data.split("\n")
            for (var i = 0; i < lines.length; i++) {
                if (lines[i].indexOf("cpu ") === 0) {
                    var parts = lines[i].split(/\s+/)
                    var idle = parseInt(parts[4])
                    var total = 0
                    for (var j = 1; j < parts.length && j < 8; j++) {
                        total += parseInt(parts[j])
                    }
                    if (lastCpuTotal > 0) {
                        var diffIdle = idle - lastCpuIdle
                        var diffTotal = total - lastCpuTotal
                        cpuUsage = diffTotal > 0 ? (1.0 - diffIdle / diffTotal) : 0
                    }
                    lastCpuIdle = idle
                    lastCpuTotal = total
                    break
                }
            }
        }

        function parseMem(data) {
            var total = 0
            var available = 0
            var lines = data.split("\n")
            for (var i = 0; i < lines.length; i++) {
                if (lines[i].indexOf("MemTotal:") === 0) {
                    total = parseInt(lines[i].split(/\s+/)[1])
                } else if (lines[i].indexOf("MemAvailable:") === 0) {
                    available = parseInt(lines[i].split(/\s+/)[1])
                }
            }
            memUsage = total > 0 ? (total - available) / total : 0
        }

        function parseUptime(data) {
            var secs = parseInt(data.split(".")[0])
            var hours = Math.floor(secs / 3600)
            var mins = Math.floor((secs % 3600) / 60)
            uptime = hours + ":" + (mins < 10 ? "0" : "") + mins
        }

        function readFile(path) {
            // Use XMLHttpRequest to read local files
            var xhr = new XMLHttpRequest()
            try {
                xhr.open("GET", "file://" + path, false)
                xhr.send()
                if (xhr.status === 0 || xhr.status === 200) {
                    return xhr.responseText
                }
            } catch(e) {}
            return ""
        }
    }

    Component.onCompleted: {
        sysInfo.update()
    }

    fullRepresentation: Rectangle {
        Layout.minimumWidth: 200
        Layout.minimumHeight: 280
        Layout.preferredWidth: 220
        Layout.preferredHeight: 300
        radius: 12
        color: "#0e1f14"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Title
            Text {
                text: "Race Stats"
                color: "#f0f9f2"
                font.pixelSize: 16
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#12301a" }

            // Speed (CPU)
            StatBar {
                Layout.fillWidth: true
                label: "Speed"
                value: sysInfo.cpuUsage
                suffix: Math.round(sysInfo.cpuUsage * 100) + "%"
            }

            // Stamina (RAM)
            StatBar {
                Layout.fillWidth: true
                label: "Stamina"
                value: sysInfo.memUsage
                suffix: Math.round(sysInfo.memUsage * 100) + "%"
            }

            // Race Time (Uptime)
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Race Time"
                    color: "#3a5a3a"
                    font.pixelSize: 11
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: sysInfo.uptime
                    color: "#f0f9f2"
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
