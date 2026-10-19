import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../Pantry.js" as U

// A category's name and colour. The colour marks its heading on the list.
Dialog {
    id: dialog

    property int categoryId: 0
    property string name: ""
    property string colour: ""

    canAccept: nameField.text.trim() !== ""

    onAccepted: name = nameField.text.trim()

    function paint() { FiatAgendaTheme.applyPalette(dialog) }
    Component.onCompleted: {
        paint()
        if (colour === "")
            colour = U.categoryColours[Math.floor(Math.random() * U.categoryColours.length)]
    }

    FiatBackground { }

    Column {
        width: parent.width
        spacing: Theme.paddingSmall

        DialogHead {
            owner: dialog
            title: dialog.categoryId > 0 ? qsTr("Category") : qsTr("New category")
        }
        TextField {
            id: nameField
            // Predictive text holds a word back until a space; the button
            // beside it would wait for it. The same as the Tasks capture field.
            inputMethodHints: Qt.ImhNoPredictiveText
            width: parent.width
            text: dialog.name
            label: qsTr("Name")
            placeholderText: qsTr("Name: dairy, bakery, the chemist")
            EnterKey.enabled: dialog.canAccept
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: dialog.accept()
        }
        Item { width: 1; height: Theme.paddingMedium }
        SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("Colour") }
        ColourChoice {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            colours: U.categoryColours
            allowNone: false
            current: dialog.colour
            onChosen: dialog.colour = value
        }
    }
}
