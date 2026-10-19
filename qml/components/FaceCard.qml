import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// The card at the top of both sides of the front page: one big figure, what
// it counts, a line under that, and the ring for how much is done.
Item {
    id: root

    property string figure: ""
    property string title: ""
    // The line under the title, in parts: "October", "week 43". When it has
    // to wrap it wraps between parts, never inside one.
    property var details: []
    readonly property string subtitle: {
        var out = []
        for (var i = 0; i < details.length; i++)
            if (details[i] !== "") out.push(String(details[i]).replace(/ /g, "\u00A0"))
        return out.join("\u00A0· ")
    }
    property int done: 0
    property int total: 0
    property bool showRing: true

    x: Theme.paddingLarge
    width: (parent ? parent.width : Screen.width) - 2 * Theme.paddingLarge
    // The ring counts towards the height whether it shows or not, so the card
    // keeps its size when you move between views.
    height: Math.max(figureLabel.height, ring.height, words.height) + 2 * Theme.paddingLarge

    Rectangle {
        anchors.fill: parent
        color: FiatAgendaTheme.card
        border.color: FiatAgendaTheme.cardBorder
        border.width: FiatAgendaTheme.cardBorderWidth
        radius: FiatAgendaTheme.cardRadius
    }

    Label {
        id: figureLabel
        anchors.left: parent.left
        anchors.leftMargin: Theme.paddingLarge + Theme.paddingSmall
        anchors.verticalCenter: parent.verticalCenter
        text: root.figure
        color: FiatAgendaTheme.accent
        font.family: FiatAgendaTheme.serif
        font.pixelSize: Theme.fontSizeHuge * 1.2
    }

    Column {
        id: words
        anchors.left: figureLabel.right
        anchors.leftMargin: Theme.paddingMedium
        anchors.right: ring.visible ? ring.left : parent.right
        anchors.rightMargin: Theme.paddingMedium
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Label {
            width: parent.width
            text: root.title
            truncationMode: TruncationMode.Fade
            color: FiatAgendaTheme.primaryText
            font.family: FiatAgendaTheme.serif
            font.italic: true
            font.pixelSize: Theme.fontSizeLarge
        }
        Label {
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            wrapMode: Text.WordWrap
            color: FiatAgendaTheme.secondaryText
            font.pixelSize: Theme.fontSizeExtraSmall
        }
    }

    Ring {
        id: ring
        width: Theme.itemSizeMedium
        visible: root.showRing
        anchors.right: parent.right
        anchors.rightMargin: Theme.paddingLarge
        anchors.verticalCenter: parent.verticalCenter
        done: root.done
        total: root.total
    }
}
