import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

// The wordmark. Lowercase, serif, italic, top-left, always -- and on the same
// line as the system's own indicators. It takes NO notch inset on purpose: it
// lives in the left corner, and a centred cutout never reaches it.
//
// It does need room, though. "fiat agenda" is three characters longer than
// "fiat mos" and sits noticeably wider and taller in the corner, which is why
// statusRowCenter is itemSizeLarge / 2 and not one of the smaller numbers the
// family tried first. Change it there, not here.

Item {
    id: mark

    width: parent ? parent.width : 0
    height: FiatAgendaTheme.statusRowCenter + word.height / 2 + Theme.paddingMedium

    Text {
        id: word
        anchors.left: parent.left
        anchors.leftMargin: Theme.horizontalPageMargin
        anchors.top: parent.top
        anchors.topMargin: Math.max(0, FiatAgendaTheme.statusRowCenter - height / 2)
        text: "fiat agenda"
        color: FiatAgendaTheme.primaryText
        font.pixelSize: Theme.fontSizeLarge
        font.family: FiatAgendaTheme.serif
        font.italic: true
    }
}
