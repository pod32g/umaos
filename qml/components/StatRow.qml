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
            color: "#0e1f14"
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
