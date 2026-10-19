import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// One colour out of Pantry's own set, or none. The chosen dot gets a ring.
// The colours are the household's, shared with the web app, so they are shown
// as they are rather than bent towards the Fiat palette.
Flow {
    id: root

    property var colours: []
    property string current: ""
    property bool allowNone: true
    signal chosen(string value)

    readonly property real dot: Theme.itemSizeExtraSmall * 0.62

    spacing: Theme.paddingMedium

    Repeater {
        model: root.allowNone ? [""].concat(root.colours) : root.colours
        delegate: MouseArea {
            id: cell
            readonly property bool on: String(modelData).toLowerCase() === String(root.current).toLowerCase()
            width: root.dot + Theme.paddingMedium
            height: width
            onClicked: root.chosen(modelData)

            Rectangle {
                anchors.centerIn: parent
                width: root.dot + Theme.paddingSmall * 2
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: FiatAgendaTheme.primaryText
                visible: cell.on
            }
            Rectangle {
                anchors.centerIn: parent
                width: root.dot
                height: width
                radius: width / 2
                color: modelData === "" ? "transparent" : modelData
                border.width: modelData === "" ? 2 : 0
                border.color: FiatAgendaTheme.secondaryText
                opacity: cell.pressed ? 0.6 : 1.0
            }
            Rectangle {
                visible: modelData === ""
                anchors.centerIn: parent
                width: root.dot * 0.9
                height: 2
                rotation: -45
                color: FiatAgendaTheme.secondaryText
                antialiasing: true
            }
        }
    }
}
