import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

// A new household. Members are added from Pantry on the web.
Dialog {
    id: dialog

    property string name: ""
    property string description: ""

    canAccept: nameField.text.trim() !== ""

    onAccepted: {
        name = nameField.text.trim()
        description = descriptionField.text.trim()
    }

    function paint() { FiatAgendaTheme.applyPalette(dialog) }
    Component.onCompleted: paint()

    FiatBackground { }

    Column {
        width: parent.width
        spacing: Theme.paddingSmall

        DialogHead {
            owner: dialog
            title: qsTr("New household")
        }
        TextField {
            id: nameField
            // Predictive text holds a word back until a space; the button
            // beside it would wait for it. The same as the Tasks capture field.
            inputMethodHints: Qt.ImhNoPredictiveText
            width: parent.width
            label: qsTr("Name")
            placeholderText: qsTr("Name")
            EnterKey.iconSource: "image://theme/icon-m-enter-next"
            EnterKey.onClicked: descriptionField.focus = true
        }
        TextField {
            id: descriptionField
            width: parent.width
            label: qsTr("A line about it")
            placeholderText: qsTr("A line about it")
            EnterKey.enabled: dialog.canAccept
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: dialog.accept()
        }
        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            wrapMode: Text.WordWrap
            text: qsTr("You will be its owner. Add the others from Pantry in the browser.")
            color: FiatAgendaTheme.secondaryText
            font.pixelSize: Theme.fontSizeExtraSmall
        }
    }
}
