import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// The tick mark at the start of a list row: an open ring, or the accent filled
// with a tick. Drawn from two bars rather than a glyph, so it is round and the
// same in every font.
Item {
    id: root

    property bool checked: false
    property color color: FiatAgendaTheme.accent

    width: FiatAgendaTheme.markSize
    height: width

    readonly property real bar: Math.max(2, Math.round(width * 0.09))

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.checked ? root.color : "transparent"
        border.width: root.checked ? 0 : Math.max(2, Math.round(root.width * 0.07))
        border.color: FiatAgendaTheme.secondaryText
        antialiasing: true
    }

    Rectangle {
        visible: root.checked
        x: root.width * 0.27
        y: root.width * 0.53 - root.bar / 2
        width: root.width * 0.21
        height: root.bar
        radius: root.bar / 2
        color: FiatAgendaTheme.markOn(root.color)
        transformOrigin: Item.Left
        rotation: 45
        antialiasing: true
    }

    Rectangle {
        visible: root.checked
        x: root.width * 0.41
        y: root.width * 0.68 - root.bar / 2
        width: root.width * 0.42
        height: root.bar
        radius: root.bar / 2
        color: FiatAgendaTheme.markOn(root.color)
        transformOrigin: Item.Left
        rotation: -45
        antialiasing: true
    }
}
