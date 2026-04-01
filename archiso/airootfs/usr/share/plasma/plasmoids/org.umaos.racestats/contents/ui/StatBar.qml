import QtQuick
import QtQuick.Layouts

Item {
    id: statBar
    height: 40

    property string label: ""
    property real value: 0.0  // 0.0 to 1.0
    property string suffix: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: statBar.label
                color: "#3a5a3a"
                font.pixelSize: 11
            }
            Item { Layout.fillWidth: true }
            Text {
                text: statBar.suffix
                color: "#f0f9f2"
                font.pixelSize: 11
                font.bold: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 8
            radius: 4
            color: "#12301a"

            Rectangle {
                width: parent.width * Math.min(statBar.value, 1.0)
                height: parent.height
                radius: 4

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#42a54b" }
                    GradientStop { position: 1.0; color: statBar.value > 0.8 ? "#FF91C0" : "#42a54b" }
                }

                Behavior on width {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
