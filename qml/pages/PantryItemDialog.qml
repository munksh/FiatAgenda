import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import ".."
import "../components"
import "../Pantry.js" as U
import "../Shelf.js" as Shelf

// Everything about one item: how much, a note, the category, whether it comes
// back, and a picture. The list page does the sending.
Dialog {
    id: dialog

    property var house
    property int listId: 0
    property var item: null
    property string presetName: ""

    readonly property bool editing: item !== null && item !== undefined
    // The phone's own household keeps no pictures: they live on the server.
    readonly property bool local: house !== null && house !== undefined && house.local === true

    property int categoryId: editing ? U.num(item.categoryId) : 0
    property string categoryName: ""

    readonly property var original: U.parseRule(editing ? item.rrule : "")
    property string freq: original.freq
    property int interval: original.interval
    property bool ruleTouched: false
    property bool fromCompletion: editing ? item.repeatFromCompletion === true : false
    property bool leaves: editing ? item.deleteOnDone === true : false

    property string newImage: ""
    property bool removeImage: false
    readonly property bool hasImage: newImage !== "" || (editing && U.num(item.imageFileId) > 0 && !removeImage)

    canAccept: nameField.text.trim() !== ""

    function fields() {
        var f = {
            "name": nameField.text.trim(),
            "quantity": quantityField.text.trim(),
            "description": noteField.text.trim(),
            "categoryId": dialog.categoryId,
            "deleteOnDone": dialog.leaves
        }
        // Sending the rule or its mode makes the server work out the next date
        // again, so they go only when they were changed here.
        if (!dialog.editing || dialog.ruleTouched)
            f.rrule = U.buildRule(dialog.freq, dialog.interval)
        if (!dialog.editing || dialog.fromCompletion !== (dialog.item.repeatFromCompletion === true))
            f.repeatFromCompletion = dialog.fromCompletion
        if (!dialog.editing) {
            if (f.quantity === "") delete f.quantity
            if (f.description === "") delete f.description
            if (f.categoryId === 0) delete f.categoryId
            if (f.rrule === "") delete f.rrule
        }
        return f
    }

    function unitText() {
        switch (freq) {
        case "DAILY": return interval === 1 ? qsTr("day") : qsTr("days")
        case "WEEKLY": return interval === 1 ? qsTr("week") : qsTr("weeks")
        case "MONTHLY": return interval === 1 ? qsTr("month") : qsTr("months")
        case "YEARLY": return interval === 1 ? qsTr("year") : qsTr("years")
        }
        return ""
    }

    function paint() { FiatAgendaTheme.applyPalette(dialog) }
    Component.onCompleted: {
        paint()
        if (categoryId > 0) {
            var path = "/houses/" + house.id + "/categories"
            var c = U.byId(U.asArray(Shelf.cached(path, { "limit": 500 })), categoryId)
            categoryName = c ? U.str(c.name) : ""
        }
    }

    Component {
        id: pickerComponent
        ImagePickerPage {
            onSelectedContentChanged: {
                dialog.newImage = String(selectedContent)
                dialog.removeImage = false
            }
        }
    }

    FiatBackground { }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge * 2

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingSmall

            DialogHead {
                owner: dialog
                title: dialog.editing ? qsTr("Item") : qsTr("New item")
            }

            TextField {
                id: nameField
                // Predictive text holds a word back until a space; the button
                // beside it would wait for it. The same as the Tasks capture field.
                inputMethodHints: Qt.ImhNoPredictiveText
                width: parent.width
                text: dialog.editing ? U.str(dialog.item.name) : dialog.presetName
                label: qsTr("What")
                placeholderText: qsTr("What")
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: quantityField.focus = true
            }
            TextField {
                id: quantityField
                width: parent.width
                text: dialog.editing ? U.str(dialog.item.quantity) : ""
                label: qsTr("How much")
                placeholderText: qsTr("How much: 2 kg, a pack, 6")
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: noteField.focus = true
            }
            TextArea {
                id: noteField
                width: parent.width
                text: dialog.editing ? U.str(dialog.item.description) : ""
                label: qsTr("Note")
                placeholderText: qsTr("A note: the brand, the shelf, who wants it")
            }

            ValueButton {
                label: qsTr("Category")
                value: dialog.categoryId > 0 ? (dialog.categoryName !== "" ? dialog.categoryName : qsTr("Chosen"))
                                             : qsTr("None")
                onClicked: {
                    var p = pageStack.push(Qt.resolvedUrl("CategoryPickerPage.qml"), {
                        "house": dialog.house, "listId": dialog.listId, "selectedId": dialog.categoryId })
                    p.picked.connect(function (id, name) {
                        dialog.categoryId = id
                        dialog.categoryName = name
                    })
                }
            }

            // ---- comes back ----
            Item { width: 1; height: Theme.paddingMedium }
            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("Repeat") }
            Choice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                choices: [
                    { "label": qsTr("Never"), "value": "" },
                    { "label": qsTr("Daily"), "value": "DAILY" },
                    { "label": qsTr("Weekly"), "value": "WEEKLY" },
                    { "label": qsTr("Monthly"), "value": "MONTHLY" },
                    { "label": qsTr("Yearly"), "value": "YEARLY" }
                ]
                current: dialog.freq
                onChosen: {
                    dialog.freq = value
                    dialog.ruleTouched = true
                }
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.editing && !dialog.original.plain && !dialog.ruleTouched
                wrapMode: Text.WordWrap
                text: qsTr("This item follows a rule made in Pantry on the web (%1). It stays as it is unless you choose here.")
                      .arg(U.str(dialog.item ? dialog.item.rrule : ""))
                color: FiatAgendaTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }
            Row {
                x: Theme.horizontalPageMargin
                height: Theme.itemSizeSmall
                spacing: Theme.paddingMedium
                visible: dialog.freq !== ""
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Every")
                    color: FiatAgendaTheme.secondaryText
                    font.pixelSize: Theme.fontSizeSmall
                }
                LinkText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "−"
                    underline: false
                    fontSize: Theme.fontSizeLarge
                    enabled: dialog.interval > 1
                    onClicked: { dialog.interval = dialog.interval - 1; dialog.ruleTouched = true }
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: dialog.interval
                    color: FiatAgendaTheme.accent
                    font.pixelSize: Theme.fontSizeLarge
                    font.family: FiatAgendaTheme.serif
                }
                LinkText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+"
                    underline: false
                    fontSize: Theme.fontSizeLarge
                    enabled: dialog.interval < 99
                    onClicked: { dialog.interval = dialog.interval + 1; dialog.ruleTouched = true }
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: dialog.unitText()
                    color: FiatAgendaTheme.secondaryText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
            Choice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: dialog.freq !== ""
                choices: [
                    { "label": qsTr("On schedule"), "value": false },
                    { "label": qsTr("From when it is done"), "value": true }
                ]
                current: dialog.fromCompletion
                onChosen: dialog.fromCompletion = value
            }

            // ---- when ticked off ----
            Item { width: 1; height: Theme.paddingMedium }
            SectionLabel { x: Theme.horizontalPageMargin; text: qsTr("When ticked off") }
            Choice {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                choices: [
                    { "label": qsTr("It stays, ticked"), "value": false },
                    { "label": qsTr("It leaves the list"), "value": true }
                ]
                current: dialog.leaves
                onChosen: dialog.leaves = value
            }

            // ---- picture ----
            Item { width: 1; height: Theme.paddingMedium; visible: !dialog.local }
            SectionLabel { x: Theme.horizontalPageMargin; visible: !dialog.local; text: qsTr("Picture") }
            Item { width: 1; height: Theme.paddingSmall; visible: !dialog.local }
            Image {
                x: Theme.horizontalPageMargin
                visible: dialog.hasImage && !dialog.local
                width: Theme.itemSizeHuge
                height: width
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width
                sourceSize.height: height
                asynchronous: true
                source: dialog.newImage !== "" ? dialog.newImage
                        : (dialog.hasImage ? Shelf.imageUrl("/houses/" + dialog.house.id + "/image-preview", {
                               "fileId": dialog.item.imageFileId,
                               "owner": U.str(dialog.item.imageUploadedBy) !== "" ? dialog.item.imageUploadedBy : U.str(dialog.item.addedBy),
                               "size": 512 }) : "")
            }
            Row {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: !dialog.local
                spacing: Theme.paddingLarge
                LinkText {
                    text: dialog.hasImage ? qsTr("Another picture") : qsTr("Add a picture")
                    onClicked: pageStack.push(pickerComponent)
                }
                LinkText {
                    visible: dialog.hasImage
                    text: qsTr("Remove it")
                    color: FiatAgendaTheme.secondaryText
                    onClicked: {
                        dialog.newImage = ""
                        dialog.removeImage = true
                    }
                }
            }
        }

        VerticalScrollDecorator { }
    }
}
