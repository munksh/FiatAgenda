import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import ".."
import "../components"
import "../Pantry.js" as U
import "../Shelf.js" as Shelf

// One list, grouped by category, with what is done at the bottom. A tap ticks
// a row off; holding it gives edit and delete. Written for one hand in a shop.
Page {
    id: page

    property var house
    property var list

    property var items: []
    property var categories: []
    property bool loaded: false
    property bool seenOnce: false

    readonly property int houseId: house ? house.id : 0
    readonly property int listId: list ? list.id : 0
    readonly property string base: "/houses/" + houseId + "/lists/" + listId
    readonly property bool canAdd: U.can(house, "canAddItems") && (!list || list.canEdit !== false)
    readonly property bool canCheck: U.can(house, "canCheckItems")
    readonly property bool canDelete: U.can(house, "canDeleteItems")

    property int openCount: 0
    property int doneCount: 0
    property string draft: ""
    signal draftTaken()

    function paint() { FiatAgendaTheme.applyPalette(page) }
    Component.onCompleted: {
        paint()
        load(true)
    }
    Connections { target: FiatAgendaTheme; onAmbientChanged: page.paint() }

    onStatusChanged: {
        if (status !== PageStatus.Active)
            return
        if (seenOnce)
            load(false)
        seenOnce = true
    }

    ConfigurationValue {
        id: showDoneConfig
        key: "/apps/harbour-fiatagenda/showDone"
        defaultValue: true
    }
    readonly property bool showDone: showDoneConfig.value === true || showDoneConfig.value === "true"

    // Someone else in the household may be ticking off the same list.
    Timer {
        interval: 15000
        repeat: true
        running: page.status === PageStatus.Active && Qt.application.state === Qt.ApplicationActive
                 && !(page.house && page.house.local === true)
        onTriggered: page.load(false)
    }
    Connections {
        target: Qt.application
        onStateChanged: if (Qt.application.state === Qt.ApplicationActive && page.status === PageStatus.Active) page.load(false)
    }

    // ---- loading ----

    function load(withCache) {
        var itemsQuery = { "limit": 500 }
        var catPath = "/houses/" + houseId + "/categories"
        var catQuery = { "limit": 500 }
        if (withCache) {
            var ci = Shelf.cached(base + "/items", itemsQuery)
            var cc = Shelf.cached(catPath, catQuery)
            if (cc !== undefined) categories = U.asArray(cc)
            if (ci !== undefined) { items = U.asArray(ci); rebuild() }
        }
        Shelf.get(catPath, catQuery, function (ok, data) {
            if (ok) { page.categories = U.asArray(data); page.rebuild() }
        })
        Shelf.get(base + "/items", itemsQuery, function (ok, data) {
            page.loaded = true
            if (ok) { page.items = U.asArray(data); page.rebuild() }
        })
    }

    // ---- rows ----

    function categoryFor(id) {
        return id ? U.byId(categories, id) : null
    }

    function rankOf(categoryId) {
        var c = categoryFor(categoryId)
        return c ? U.num(c.sortOrder) : -1000000
    }

    function sectionName(key) {
        if (key === "~done")
            return qsTr("Done")
        if (key.indexOf("c:") === 0) {
            var c = categoryFor(Number(key.substring(2)))
            return c ? U.str(c.name) : ""
        }
        return ""
    }

    function sectionColour(key) {
        if (key.indexOf("c:") === 0) {
            var c = categoryFor(Number(key.substring(2)))
            if (c && U.str(c.color) !== "")
                return c.color
        }
        return ""
    }

    function rowOf(it) {
        var cat = categoryFor(it.categoryId)
        return {
            "itemId": it.id,
            "name": U.str(it.name),
            "quantity": U.str(it.quantity),
            "description": U.str(it.description),
            "done": it.done === true,
            "section": it.done ? "~done" : (cat ? "c:" + cat.id : ""),
            "rule": U.str(it.rrule),
            "nextDueAt": U.num(it.nextDueAt),
            "imageFileId": U.num(it.imageFileId),
            "imageOwner": U.str(it.imageUploadedBy) !== "" ? it.imageUploadedBy : U.str(it.addedBy)
        }
    }

    function sortedRows() {
        var open = []
        var done = []
        for (var i = 0; i < items.length; ++i)
            (items[i].done ? done : open).push(items[i])
        open.sort(function (a, b) {
            var ra = page.rankOf(a.categoryId), rb = page.rankOf(b.categoryId)
            if (ra !== rb) return ra - rb
            var ca = U.num(a.categoryId), cb = U.num(b.categoryId)
            if (ca !== cb) return ca - cb
            var sa = U.num(a.sortOrder), sb = U.num(b.sortOrder)
            if (sa !== sb) return sa - sb
            return a.id - b.id
        })
        done.sort(function (a, b) { return U.num(b.doneAt) - U.num(a.doneAt) })
        openCount = open.length
        doneCount = done.length
        var rows = []
        for (var j = 0; j < open.length; ++j) rows.push(rowOf(open[j]))
        if (showDone)
            for (var k = 0; k < done.length; ++k) rows.push(rowOf(done[k]))
        return rows
    }

    // Bring the model in line with the rows without clearing it, so a refresh
    // from the server neither flickers nor throws the view back to the top.
    function rebuild() {
        var rows = sortedRows()
        var wanted = {}
        for (var i = 0; i < rows.length; ++i)
            wanted[rows[i].itemId] = true
        for (var r = rowsModel.count - 1; r >= 0; --r)
            if (!wanted[rowsModel.get(r).itemId])
                rowsModel.remove(r)
        for (var n = 0; n < rows.length; ++n) {
            if (n < rowsModel.count && rowsModel.get(n).itemId === rows[n].itemId) {
                rowsModel.set(n, rows[n])
                continue
            }
            var at = -1
            for (var m = n + 1; m < rowsModel.count; ++m)
                if (rowsModel.get(m).itemId === rows[n].itemId) { at = m; break }
            if (at >= 0) {
                rowsModel.move(at, n, 1)
                rowsModel.set(n, rows[n])
            } else {
                rowsModel.insert(n, rows[n])
            }
        }
        while (rowsModel.count > rows.length)
            rowsModel.remove(rowsModel.count - 1)
    }


    ListModel { id: rowsModel }

    // ---- changes ----

    function itemPath(id) { return base + "/items/" + id }

    function toggle(itemId) {
        if (!canCheck)
            return
        var it = U.byId(items, itemId)
        if (!it)
            return
        var flipped = JSON.parse(JSON.stringify(it))
        flipped.done = !it.done
        flipped.doneAt = flipped.done ? Math.floor(Date.now() / 1000) : null
        items = U.replaceById(items, flipped)
        rebuild()
        Shelf.send("POST", itemPath(itemId) + "/toggle", undefined, function (ok, data) {
            if (!ok) { page.load(false); return }
            if (data && data.deletedAt)
                page.items = U.removeById(page.items, itemId)
            else if (data && data.id)
                page.items = U.replaceById(page.items, data)
            page.rebuild()
        })
    }

    function quickAdd(name) {
        name = name.trim()
        if (name === "")
            return
        Shelf.send("POST", base + "/items", { "name": name }, function (ok, data) {
            if (ok && data && data.id) {
                page.items = U.replaceById(page.items, data)
                page.rebuild()
            }
        })
    }

    function saveItem(itemId, fields, imageUrl, removeImage) {
        var afterSave = function (ok, data) {
            if (!ok || !data || !data.id)
                return
            page.items = U.replaceById(page.items, data)
            page.rebuild()
            // A category made from the item dialog is not in this page's copy yet.
            if (data.categoryId && !page.categoryFor(data.categoryId))
                Shelf.get("/houses/" + page.houseId + "/categories", { "limit": 500 }, function (ok4, cats) {
                    if (ok4) { page.categories = U.asArray(cats); page.rebuild() }
                })
            var id = data.id
            if (removeImage && !imageUrl) {
                Shelf.send("DELETE", page.itemPath(id) + "/image", undefined, function (ok2, data2) {
                    if (ok2 && data2 && data2.id) { page.items = U.replaceById(page.items, data2); page.rebuild() }
                })
            }
            if (imageUrl) {
                Shelf.upload(page.itemPath(id) + "/image", imageUrl, {}, function (ok3, data3) {
                    if (ok3 && data3 && data3.id) { page.items = U.replaceById(page.items, data3); page.rebuild() }
                })
            }
        }
        if (itemId > 0)
            Shelf.send("PATCH", itemPath(itemId), fields, afterSave)
        else
            Shelf.send("POST", base + "/items", fields, afterSave)
    }

    function deleteItem(itemId) {
        items = U.removeById(items, itemId)
        rebuild()
        Shelf.send("DELETE", itemPath(itemId), undefined, function (ok) {
            if (!ok) page.load(false)
        })
    }

    function doneIds() {
        var ids = []
        for (var i = 0; i < items.length; ++i)
            if (items[i].done) ids.push(items[i].id)
        return ids
    }

    function uncheckAll() {
        var ids = doneIds()
        if (ids.length === 0)
            return
        Shelf.send("POST", "/houses/" + houseId + "/items/batch/uncheck", { "itemIds": ids }, function () { page.load(false) })
    }

    function clearDone() {
        var ids = doneIds()
        if (ids.length === 0)
            return
        var keep = []
        for (var i = 0; i < items.length; ++i)
            if (!items[i].done) keep.push(items[i])
        items = keep
        rebuild()
        Shelf.send("POST", "/houses/" + houseId + "/items/batch/delete", { "itemIds": ids }, function () { page.load(false) })
    }

    function openItem(itemId, presetName) {
        var it = itemId > 0 ? U.byId(items, itemId) : null
        var d = pageStack.push(Qt.resolvedUrl("PantryItemDialog.qml"), {
            "house": page.house, "listId": page.listId, "item": it, "presetName": presetName || "" })
        d.accepted.connect(function () {
            page.saveItem(it ? it.id : 0, d.fields(), d.newImage, d.removeImage)
            if (!it)
                page.draftTaken()
        })
    }

    function editList() {
        var d = pageStack.push(Qt.resolvedUrl("PantryListDialog.qml"), {
            "listId": list.id, "name": U.str(list.name), "description": U.str(list.description), "colour": U.str(list.color) })
        d.accepted.connect(function () {
            Shelf.send("PATCH", page.base, d.fields(), function (ok, data) {
                if (ok && data && data.id) page.list = data
            })
        })
    }

    RemorsePopup { id: remorse }

    // ---- paper ----

    FiatBackground { }

    SilicaListView {
        id: view
        anchors.fill: parent
        model: rowsModel

        PullDownMenu {
            highlightColor: FiatAgendaTheme.accent

            MenuItem {
                visible: page.list && page.list.canEdit !== false && U.can(page.house, "canEditLists")
                text: qsTr("Edit list")
                color: FiatAgendaTheme.primaryText
                onClicked: page.editList()
            }
            MenuItem {
                text: qsTr("Refresh")
                color: FiatAgendaTheme.primaryText
                onClicked: page.load(false)
            }
            MenuItem {
                visible: page.doneCount > 0 && page.canCheck
                text: qsTr("Untick all")
                color: FiatAgendaTheme.primaryText
                onClicked: page.uncheckAll()
            }
            MenuItem {
                visible: page.doneCount > 0 && page.canDelete
                text: qsTr("Clear what is done")
                color: FiatAgendaTheme.primaryText
                onClicked: remorse.execute(qsTr("Clearing %n done", "", page.doneCount), function () { page.clearDone() })
            }
            MenuItem {
                visible: page.canAdd
                text: qsTr("Add with details")
                color: FiatAgendaTheme.primaryText
                onClicked: page.openItem(0, page.draft)
            }
        }

        header: Column {
            width: view.width

            PageHead {
                title: page.list ? U.str(page.list.name) : ""
                subtitle: page.loaded || page.items.length > 0
                          ? (page.openCount > 0 ? qsTr("%n left", "", page.openCount) : qsTr("nothing left"))
                            + (page.doneCount > 0 ? " · " + qsTr("%n done", "", page.doneCount) : "")
                          : ""
            }
            ErrorLine { }

            TextField {
                id: addField
                // Predictive text holds a word back until a space; the button
                // beside it would wait for it. The same as the Tasks capture field.
                inputMethodHints: Qt.ImhNoPredictiveText
                width: parent.width
                visible: page.canAdd
                placeholderText: qsTr("Add to the list")
                label: qsTr("Add to the list")
                onTextChanged: page.draft = text
                Connections { target: page; onDraftTaken: addField.text = "" }
                EnterKey.enabled: text.trim() !== ""
                EnterKey.iconSource: "image://theme/icon-m-add"
                EnterKey.onClicked: {
                    page.quickAdd(text)
                    text = ""
                }
            }
        }

        section.property: "section"
        section.criteria: ViewSection.FullString
        section.delegate: Item {
            width: view.width
            height: section === "" ? 0 : Theme.itemSizeExtraSmall
            visible: section !== ""
            Row {
                x: Theme.horizontalPageMargin
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.paddingSmall
                spacing: Theme.paddingSmall
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.paddingMedium
                    height: width
                    radius: width / 2
                    color: page.sectionColour(section) !== "" ? page.sectionColour(section) : "transparent"
                    visible: page.sectionColour(section) !== ""
                }
                SectionLabel {
                    text: page.sectionName(section)
                }
            }
        }

        delegate: ListItem {
            id: row
            contentHeight: Math.max(Theme.itemSizeSmall, textCol.height + 2 * Theme.paddingMedium)
            onClicked: page.toggle(model.itemId)
            highlightedColor: FiatAgendaTheme.highlightWash
            menu: Component {
                ContextMenu {
                    backgroundColor: FiatAgendaTheme.highlightWash
                    highlightColor: FiatAgendaTheme.accent
                    MenuItem {
                        visible: page.canAdd
                        text: qsTr("Edit")
                        color: FiatAgendaTheme.primaryText
                        onClicked: page.openItem(model.itemId, "")
                    }
                    MenuItem {
                        visible: page.canDelete
                        text: qsTr("Delete")
                        color: FiatAgendaTheme.wrong
                        onClicked: {
                            var id = model.itemId
                            row.remorseDelete(function () { page.deleteItem(id) })
                        }
                    }
                }
            }

            readonly property bool isDone: model.done === true
            readonly property string repeatText: U.describeRule(model.rule)

            Mark {
                id: mark
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                checked: row.isDone
            }

            Column {
                id: textCol
                anchors {
                    left: mark.right; leftMargin: Theme.paddingLarge
                    right: side.left; rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                Label {
                    width: parent.width
                    text: model.name === undefined ? "" : model.name
                    wrapMode: Text.WordWrap
                    color: row.isDone ? FiatAgendaTheme.secondaryText
                                      : (row.highlighted ? FiatAgendaTheme.accent : FiatAgendaTheme.primaryText)
                    font.strikeout: row.isDone
                    font.pixelSize: Theme.fontSizeMedium
                }
                Label {
                    width: parent.width
                    visible: text !== ""
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    color: FiatAgendaTheme.secondaryText
                    font.pixelSize: Theme.fontSizeExtraSmall
                    text: {
                        var parts = []
                        if (model.description) parts.push(model.description)
                        if (row.repeatText !== "") parts.push("↻ " + row.repeatText)
                        if (row.isDone && model.nextDueAt > 0)
                            parts.push(qsTr("back on %1").arg(U.shortDate(model.nextDueAt)))
                        return parts.join(" · ")
                    }
                }
            }

            Row {
                id: side
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingMedium

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    text: model.quantity === undefined ? "" : model.quantity
                    color: row.isDone ? FiatAgendaTheme.secondaryText : FiatAgendaTheme.primaryText
                    font.pixelSize: Theme.fontSizeSmall
                    width: Math.min(implicitWidth, view.width / 4)
                    truncationMode: TruncationMode.Fade
                }
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: model.imageFileId > 0
                    width: Theme.itemSizeExtraSmall
                    height: width
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: width
                    sourceSize.height: height
                    asynchronous: true
                    opacity: row.isDone ? 0.5 : 1.0
                    source: model.imageFileId > 0
                            ? Shelf.imageUrl("/houses/" + page.houseId + "/image-preview",
                                           { "fileId": model.imageFileId, "owner": model.imageOwner, "size": 128 })
                            : ""
                }
            }
        }

        footer: Item {
            width: view.width
            height: page.doneCount > 0 ? Theme.itemSizeMedium : Theme.paddingLarge
            LinkText {
                anchors.centerIn: parent
                visible: page.doneCount > 0
                text: page.showDone ? qsTr("Hide what is done") : qsTr("Show %n done", "", page.doneCount)
                color: FiatAgendaTheme.secondaryText
                onClicked: {
                    showDoneConfig.value = !page.showDone
                    page.rebuild()
                }
            }
        }

        VerticalScrollDecorator { }
    }

    EmptyNote {
        enabled: page.loaded && page.items.length === 0
        text: qsTr("Nothing on this list")
        hintText: page.canAdd ? qsTr("Write above to add something") : ""
    }

    ActivityLine { }
}
