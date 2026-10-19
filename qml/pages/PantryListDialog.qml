import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../Pantry.js" as U

// A new list, or a new name, line and colour for one.
Dialog {
    id: dialog

    property int listId: 0
    property string name: ""
    property string description: ""
    property string colour: ""

    canAccept: nameField.text.trim() !== ""

    // What the page sends. An empty description clears it on the server.
    function fields() {
        var f = { "name": nameField.text.trim(), "description": descriptionField.text.trim() }
        if (dialog.colour !== "" || dialog.listId > 0)
            f.color = dialog.colour
        if (dialog.listId === 0 && f.description === "")
            delete f.description
        if (dialog.listId === 0 && dialog.colour === "")
            delete f.color
        return f
    }

    function paint() { FiatAgendaTheme.applyPalette(dialog) }
    Component.onCompleted: paint()

    FiatBackground { }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingSmall

            DialogHead {
                owner: dialog
                title: dialog.listId > 0 ? qsTr("List") : qsTr("New list")
            }

            TextField {
                id: nameField
                // Predictive text holds a word back until a space; the button
                // beside it would wait for it. The same as the Tasks capture field.
                inputMethodHints: Qt.ImhNoPredictiveText
                width: parent.width
                text: dialog.name
                label: qsTr("Name")
                placeholderText: qsTr("Name")
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: descriptionField.focus = true
            }
            TextField {
                id: descriptionField
                width: parent.width
                text: dialog.description
                label: qsTr("A line about it")
                placeholderText: qsTr("A line about it")
                EnterKey.enabled: dialog.canAccept
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: dialog.accept()
            }

            Item { width: 1; height: Theme.paddingMedium }
            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("Colour") }
            ColourChoice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                colours: U.listColours
                current: dialog.colour
                onChosen: dialog.colour = value
            }
        }
    }
}
