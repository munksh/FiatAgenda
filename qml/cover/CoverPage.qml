/*
 * The cover: how many things want you today, and which one is first.
 *
 * No cover actions. Adding a task needs the keyboard and completing one from
 * the cover would mean guessing which task was meant -- and a wrong guess on
 * a cover is a task quietly gone. The cover reports; the app acts.
 *
 * The figure is serif for the same reason the wordmark is: a grotesque
 * numeral under a serif wordmark reads as two unrelated typefaces.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../Storage.js" as Storage

CoverBackground {
    id: cover

    property var info: ({ today: 0, overdue: 0, next: "", nextDue: "" })

    function refresh() { info = Storage.summary() }

    Component.onCompleted: refresh()

    // The cover only matters while the app is not in front, so that is when
    // it is worth keeping fresh. A pair of COUNTs once a minute is nothing.
    Timer {
        interval: 60000
        repeat: true
        running: Qt.application.state !== Qt.ApplicationActive
        onTriggered: cover.refresh()
    }

    Connections {
        target: Qt.application
        onStateChanged: cover.refresh()
    }

    Rectangle {
        anchors.fill: parent
        visible: !FiatAgendaTheme.ambient
        gradient: Gradient {
            GradientStop { position: 0.0; color: FiatAgendaTheme.backgroundHigh }
            GradientStop { position: 1.0; color: FiatAgendaTheme.backgroundLow }
        }
    }

    // Centred, not left-aligned. A cover is a tile seen at a glance from
    // arm's length, not a page you read. Each label carries
    // horizontalAlignment as well as the Column's centring, because centring
    // a Label's BOX is not the same as centring the TEXT inside it, and the
    // difference shows the moment a task title wraps to two lines.
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.paddingMedium
        anchors.rightMargin: Theme.paddingMedium
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: cover.info.today
            color: cover.info.overdue > 0 ? FiatAgendaTheme.overdue
                 : cover.info.today > 0   ? FiatAgendaTheme.dueToday
                                          : FiatAgendaTheme.markIdle
            font.pixelSize: Theme.fontSizeHuge
            font.family: FiatAgendaTheme.serif
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: cover.info.today === 0 ? qsTr("clear")
                : cover.info.overdue > 0 ? qsTr("due · %1 late").arg(cover.info.overdue)
                                         : qsTr("due today")
            color: FiatAgendaTheme.secondaryText
            font.pixelSize: Theme.fontSizeExtraSmall
        }

        Item {
            width: 1
            height: Theme.paddingSmall
            visible: cover.info.next !== ""
        }

        Label {
            width: parent.width
            visible: cover.info.next !== ""
            text: cover.info.next
            horizontalAlignment: Text.AlignHCenter
            color: FiatAgendaTheme.primaryText
            font.pixelSize: Theme.fontSizeExtraSmall
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    // The wordmark sits at the FOOT of the cover, not above the figure. On a
    // page the wordmark is the first thing and the app's own corner; on a
    // cover it is the signature, and a signature goes at the bottom. The
    // number is what the cover is for.
    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.paddingLarge
        text: "fiat agenda"
        color: FiatAgendaTheme.secondaryText
        font.pixelSize: Theme.fontSizeExtraSmall
        font.family: FiatAgendaTheme.serif
        font.italic: true
    }
}
