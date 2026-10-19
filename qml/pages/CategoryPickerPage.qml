import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../Pantry.js" as U
import "../Shelf.js" as Shelf

// The household's categories, and the ones made for this list. Choosing one
// goes back; holding one gives rename and delete.
Page {
    id: page

    property var house
    property int listId: 0
    property int selectedId: 0
    property var categories: []

    signal picked(int id, string name)

    // What a dialog asked for, done once this page is back in front. While
    // the dialog is still sliding away the page stack takes no pop, and the
    // list read under it would not show.
    property var pending: null
    onStatusChanged: {
        if (status === PageStatus.Active && pending !== null) {
            var f = pending
            pending = null
            f()
        }
    }

    readonly property string path: "/houses/" + (house ? house.id : 0) + "/categories"
    readonly property bool canEdit: U.can(house, "canEditLists")

    function paint() { FiatAgendaTheme.applyPalette(page) }
    Component.onCompleted: {
        paint()
        var c = Shelf.cached(path, { "limit": 500 })
        if (c !== undefined)
            show(c)
        load()
    }
    Connections { target: FiatAgendaTheme; onAmbientChanged: page.paint() }

    function show(data) {
        var all = U.asArray(data)
        var out = []
        for (var i = 0; i < all.length; ++i)
            if (!all[i].listId || all[i].listId === listId)
                out.push(all[i])
        out.sort(function (a, b) { return U.num(a.sortOrder) - U.num(b.sortOrder) })
        categories = out
    }

    function load() {
        Shelf.get(path, { "limit": 500 }, function (ok, data) { if (ok) page.show(data) })
    }

    function choose(id, name) {
        picked(id, name)
        pageStack.pop()
    }

    function edit(category) {
        var d = pageStack.push(Qt.resolvedUrl("CategoryDialog.qml"), category ? {
            "categoryId": category.id, "name": U.str(category.name), "colour": U.str(category.color) } : {})
        d.accepted.connect(function () {
            var body = { "name": d.name, "color": d.colour !== "" ? d.colour : U.categoryColours[0] }
            page.pending = function () {
                if (category) {
                    Shelf.send("PATCH", page.path + "/" + category.id, body, function (ok) { if (ok) page.load() })
                } else {
                    body.icon = "tag"
                    Shelf.send("POST", page.path, body, function (ok, data) {
                        if (ok && data && data.id) {
                            page.categories = page.categories.concat([data])
                            page.choose(data.id, U.str(data.name))
                        } else {
                            page.load()
                        }
                    })
                }
            }
        })
    }

    function remove(id) {
        categories = U.removeById(categories, id)
        if (selectedId === id)
            picked(0, "")
        Shelf.send("DELETE", path + "/" + id, undefined, function () { page.load() })
    }

    FiatBackground { }

    SilicaListView {
        id: view
        anchors.fill: parent
        model: [{ "id": 0, "name": qsTr("None"), "color": "" }].concat(page.categories)

        header: Column {
            width: view.width
            PageHead { title: qsTr("category") }
            ErrorLine { }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: page.canEdit
                text: qsTr("Add a category")
                onClicked: page.edit(null)
            }
            Item { width: 1; height: Theme.paddingSmall }
        }

        delegate: ListItem {
            id: row
            readonly property bool current: modelData.id === page.selectedId
            contentHeight: Theme.itemSizeSmall
            onClicked: page.choose(modelData.id, modelData.id > 0 ? U.str(modelData.name) : "")
            menu: modelData.id > 0 && page.canEdit ? menuComponent : null

            Component {
                id: menuComponent
                ContextMenu {
                    backgroundColor: FiatAgendaTheme.highlightWash
                    highlightColor: FiatAgendaTheme.accent
                    MenuItem {
                        text: qsTr("Edit")
                        color: FiatAgendaTheme.primaryText
                        onClicked: page.edit(modelData)
                    }
                    MenuItem {
                        text: qsTr("Delete")
                        color: FiatAgendaTheme.wrong
                        onClicked: {
                            var id = modelData.id
                            row.remorseDelete(function () { page.remove(id) })
                        }
                    }
                }
            }

            Rectangle {
                id: dot
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.paddingMedium * 1.4
                height: width
                radius: width / 2
                color: U.str(modelData.color) !== "" ? modelData.color : "transparent"
                border.width: U.str(modelData.color) !== "" ? 0 : 2
                border.color: FiatAgendaTheme.secondaryText
            }
            Label {
                anchors {
                    left: dot.right; leftMargin: Theme.paddingLarge
                    right: parent.right; rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                text: U.str(modelData.name)
                truncationMode: TruncationMode.Fade
                color: row.current || row.highlighted ? FiatAgendaTheme.accent : FiatAgendaTheme.primaryText
                font.bold: row.current
                font.italic: modelData.id === 0
                font.family: modelData.id === 0 ? FiatAgendaTheme.serif : Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
            }
        }

        VerticalScrollDecorator { }
    }

    ActivityLine { }
}
