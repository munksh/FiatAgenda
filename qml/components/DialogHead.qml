/*
 * The dialog header. Same reasoning as PageHead: Silica's DialogHeader draws
 * its text in Theme.highlightColor, so under Fiat colours it has to be
 * replaced -- and replacing it means inheriting the cutout.
 *
 * Cancel and Accept are short words in the corners. The cutout is centred, so
 * they take no inset at all; they are centred on the system indicator row so
 * they read as part of it. Only the title ducks.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."

Item {
    id: head

    property string title: ""
    property string acceptText: qsTr("Save")
    property string cancelText: qsTr("Cancel")
    // Named `owner`, not `dialog`: `DialogHead { dialog: dialog }` puts an id
    // and a property of the same name in one expression, and the resolution
    // order between them is not something worth betting a header on.
    property Page owner: null

    width: parent ? parent.width : 0
    height: titleText.y + titleText.height + Theme.paddingLarge

    Text {
        id: cancel
        anchors.left: parent.left
        anchors.leftMargin: Theme.horizontalPageMargin
        anchors.top: parent.top
        anchors.topMargin: Math.max(0, FiatAgendaTheme.statusRowCenter - height / 2)
        text: head.cancelText
        color: cancelArea.pressed ? FiatAgendaTheme.accent : FiatAgendaTheme.secondaryText
        font.pixelSize: Theme.fontSizeSmall
        MouseArea {
            id: cancelArea
            anchors.centerIn: parent
            width: parent.width + Theme.paddingLarge * 2
            height: Theme.itemSizeSmall
            onClicked: if (head.owner !== null) head.owner.reject()
        }
    }

    Text {
        id: accept
        anchors.right: parent.right
        anchors.rightMargin: Theme.horizontalPageMargin
        anchors.verticalCenter: cancel.verticalCenter
        text: head.acceptText
        color: acceptArea.pressed ? FiatAgendaTheme.accent : FiatAgendaTheme.primaryText
        font.pixelSize: Theme.fontSizeSmall
        MouseArea {
            id: acceptArea
            anchors.centerIn: parent
            width: parent.width + Theme.paddingLarge * 2
            height: Theme.itemSizeSmall
            onClicked: if (head.owner !== null) head.owner.accept()
        }
    }

    Text {
        id: titleText
        anchors.left: parent.left
        anchors.leftMargin: Theme.horizontalPageMargin
        y: Math.max(FiatAgendaTheme.headerTopInset, cancel.y + cancel.height + Theme.paddingMedium)
        width: Math.min(implicitWidth, parent.width - Theme.horizontalPageMargin * 2)
        text: head.title
        color: FiatAgendaTheme.primaryText
        font.pixelSize: Theme.fontSizeExtraLarge
        font.family: FiatAgendaTheme.serif
        elide: Text.ElideRight
    }
}
