import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import ".."
import "../Pantry.js" as U
import "../Shelf.js" as Shelf

// The Lists side of the front page: one household's lists, each with what is
// still left on it. The first household is the phone's own and needs nothing;
// the others come from Pantry on Nextcloud, where everyone in the household
// sees the same list.
SilicaListView {
    id: view

    property bool active: false

    signal modeChosen(string mode)
    signal nextcloudWanted()

    property var houses: []
    property var house: null
    property var lists: []
    property var counts: ({})
    property int openTotal: 0
    property int doneTotal: 0
    property bool loaded: false
    // A refresh asked for from the pull-down, until both of its answers are in.
    property bool refreshAsked: false

    readonly property int houseId: house ? house.id : 0
    readonly property string base: "/houses/" + houseId
    // Pantry is there to talk to. Without it the phone's household is all.
    readonly property bool remote: account.signedIn && account.pantryState === "present"
    readonly property bool local: house !== null && house.local === true

    readonly property var phone: Shelf.localHouse(qsTr("This phone"), qsTr("Only on this phone, not shared."))

    model: lists
    clip: true

    onActiveChanged: if (active) refresh(false)
    onRemoteChanged: if (active) refresh(false)

    Connections {
        target: Qt.application
        onStateChanged: {
            if (Qt.application.state === Qt.ApplicationActive && view.active && view.houseId !== 0)
                view.loadHouse(false)
        }
    }

    ConfigurationValue {
        id: lastHouse
        key: "/apps/harbour-fiatagenda/house"
        defaultValue: 0
    }

    // ---- loading ----

    function fetch(path, query, apply, then) {
        var forHouse = houseId
        var c = Shelf.cached(path, query)
        if (c !== undefined)
            apply(c)
        Shelf.get(path, query, function (ok, data) {
            if (ok && forHouse === view.houseId)
                apply(data)
            if (then) then()
        })
    }

    function refreshFromMenu() {
        refreshAsked = true
        refresh(true, function () { view.refreshAsked = false })
    }

    // The household list first; the household's lists follow from it. One
    // that did not change is only read again when asked to. finished, when
    // given, is called once everything asked for has answered.
    function refresh(again, finished) {
        var done = finished || function () { }
        if (!remote) {
            loaded = true
            if (!showHouses([]) || again)
                loadHouse(false, done)
            else
                done()
            return
        }
        if (houses.length <= 1) {
            var c = Shelf.cached("/houses", {})
            showHouses(c !== undefined ? c : [])
        }
        Shelf.get("/houses", {}, function (ok, data) {
            view.loaded = true
            if (!ok) {
                if (view.houses.length === 0)
                    view.showHouses([])
                done()
                return
            }
            if (!view.showHouses(data) || again)
                view.loadHouse(false, done)
            else
                done()
        })
    }

    // The phone's household first, then the server's.
    function showHouses(data) {
        houses = [phone].concat(U.asArray(data))
        var want = Number(lastHouse.value) || 0
        var h = U.byId(houses, want)
        if (!h)
            h = houses.length > 1 && want === 0 ? houses[1] : phone
        return setHouse(h, false)
    }

    // Returns whether a different household is now shown. Only a choice
    // made by hand is remembered: falling back to the phone while signed out
    // must not forget which household you use.
    function setHouse(h, chosen) {
        var changed = (house === null) !== (h === null) || (house !== null && h !== null && house.id !== h.id)
        house = h
        if (!h)
            return changed
        if (chosen && Number(lastHouse.value) !== h.id)
            lastHouse.value = h.id
        if (changed) {
            lists = []
            counts = {}
            openTotal = 0
            doneTotal = 0
            loadHouse(true)
        }
        return changed
    }

    function loadHouse(withCache, finished) {
        var done = finished || function () { }
        if (houseId === 0 || !U.can(house, "canViewLists")) {
            done()
            return
        }
        var left = 2
        var answered = function () { if (--left === 0) done() }
        var apply = withCache ? fetch : function (path, query, fn, then) {
            var forHouse = view.houseId
            Shelf.get(path, query, function (ok, data) {
                if (ok && forHouse === view.houseId) fn(data)
                then()
            })
        }
        apply(base + "/lists", { "limit": 100 }, function (data) { view.lists = U.asArray(data) }, answered)
        apply(base + "/items", { "limit": 1000 }, function (data) { view.countItems(U.asArray(data)) }, answered)
    }

    function countItems(items) {
        var c = {}, open = 0, done = 0
        for (var i = 0; i < items.length; i++) {
            var it = items[i]
            if (!c[it.listId])
                c[it.listId] = { "open": 0, "done": 0 }
            if (it.done) {
                c[it.listId].done++
                done++
            } else {
                c[it.listId].open++
                open++
            }
        }
        counts = c
        openTotal = open
        doneTotal = done
    }

    // ---- changes ----

    function saveList(listId, fields) {
        var done = function (ok, data) {
            if (ok) {
                view.lists = U.replaceById(view.lists, data)
                view.loadHouse(false)
            }
        }
        if (listId > 0)
            Shelf.send("PATCH", base + "/lists/" + listId, fields, done)
        else
            Shelf.send("POST", base + "/lists", fields, done)
    }

    function deleteList(listId) {
        lists = U.removeById(lists, listId)
        Shelf.send("DELETE", base + "/lists/" + listId, undefined, function (ok) {
            if (!ok) view.loadHouse(false)
        })
    }

    function createHouse(name, description) {
        var body = { "name": name }
        if (description !== "") body.description = description
        Shelf.send("POST", "/houses", body, function (ok, data) {
            if (ok) {
                view.houses = view.houses.concat([data])
                view.setHouse(data, true)
            }
        })
    }

    function openListDialog(list) {
        var d = pageStack.push(Qt.resolvedUrl("../pages/PantryListDialog.qml"), list ? {
            "listId": list.id, "name": U.str(list.name), "description": U.str(list.description), "colour": U.str(list.color)
        } : {})
        d.accepted.connect(function () { view.saveList(d.listId, d.fields()) })
    }

    function openHouseDialog() {
        var d = pageStack.push(Qt.resolvedUrl("../pages/HouseholdDialog.qml"))
        d.accepted.connect(function () { view.createHouse(d.name, d.description) })
    }

    function openHouses() {
        var p = pageStack.push(Qt.resolvedUrl("../pages/HouseholdsPage.qml"), { "houses": view.houses, "currentId": view.houseId })
        p.chosen.connect(function (h) { view.setHouse(h, true) })
        p.created.connect(function (h) { view.houses = view.houses.concat([h]); view.setHouse(h, true) })
    }

    PullDownMenu {
        highlightColor: FiatAgendaTheme.accent
        busy: view.refreshAsked

        MenuItem {
            text: qsTr("About")
            color: FiatAgendaTheme.primaryText
            onClicked: pageStack.animatorPush(Qt.resolvedUrl("../pages/AboutPage.qml"))
        }
        MenuItem {
            text: FiatAgendaTheme.ambient ? qsTr("Fiat colours") : qsTr("Follow ambience")
            color: FiatAgendaTheme.primaryText
            onClicked: FiatAgendaTheme.setAmbient(!FiatAgendaTheme.ambient)
        }
        MenuItem {
            text: qsTr("Nextcloud")
            color: FiatAgendaTheme.primaryText
            onClicked: view.nextcloudWanted()
        }
        MenuItem {
            visible: view.remote
            text: qsTr("Households")
            color: FiatAgendaTheme.primaryText
            onClicked: view.openHouses()
        }
        MenuItem {
            visible: view.remote && !view.local
            text: qsTr("Refresh")
            color: FiatAgendaTheme.primaryText
            onClicked: view.refreshFromMenu()
        }
        MenuItem {
            visible: view.house !== null && U.can(view.house, "canCreateLists")
            text: qsTr("New list")
            color: FiatAgendaTheme.primaryText
            onClicked: view.openListDialog(null)
        }
    }

    header: Column {
        width: view.width
        spacing: Theme.paddingMedium

        ModeHead {
            mode: "lists"
            onChosen: view.modeChosen(mode)
        }

        SyncSpinner { running: view.refreshAsked }

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - Theme.horizontalPageMargin * 2
            visible: account.signedIn && account.pantryState !== "present" && account.pantryState !== "unknown"
            wrapMode: Text.WordWrap
            text: account.pantryState === "missing"
                  ? qsTr("Pantry is not installed on %1. Someone with admin rights can add it from the Nextcloud app store.").arg(account.server.replace(/^https?:\/\//, ""))
                  : account.pantryState === "checking" ? qsTr("Looking for Pantry on the server…")
                  : qsTr("The server cannot be reached right now.")
            color: account.pantryState === "checking" ? FiatAgendaTheme.secondaryText : FiatAgendaTheme.wrong
            font.pixelSize: Theme.fontSizeSmall
        }

        // What is left across the household's lists, and how much is done.
        FaceCard {
            visible: view.house !== null
            figure: String(view.openTotal)
            title: view.openTotal === 0 ? qsTr("nothing to fix")
                 : view.openTotal === 1 ? qsTr("thing to fix") : qsTr("things to fix")
            done: view.doneTotal
            total: view.doneTotal + view.openTotal
        }

        // ---- the household ----
        // In the place, and the size, of the views on the Tasks side: one
        // word per household, the one shown underlined.
        Column {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            visible: view.house !== null

            Flow {
                width: parent.width
                spacing: Theme.paddingSmall
                Repeater {
                    model: view.houses
                    Pill {
                        text: U.str(modelData.name)
                        pixelSize: FiatAgendaTheme.navFontSize
                        selected: modelData.id === view.houseId
                        onClicked: if (!selected) view.setHouse(modelData, true)
                    }
                }
            }
            Label {
                x: Theme.paddingMedium
                width: parent.width - Theme.paddingMedium
                visible: text !== ""
                text: view.house ? U.str(view.house.description) : ""
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                color: FiatAgendaTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }
        }

        ErrorLine { visible: view.remote && !view.local && (api.error !== "" || api.offline) }

    }

    delegate: ListItem {
        id: row
        readonly property var c: view.counts[modelData.id]
        readonly property int open: c ? c.open : -1
        readonly property int done: c ? c.done : 0
        width: view.width
        contentHeight: Math.max(Theme.itemSizeMedium, rowCol.height + 2 * Theme.paddingMedium)
        highlightedColor: FiatAgendaTheme.highlightWash
        onClicked: pageStack.animatorPush(Qt.resolvedUrl("../pages/PantryListPage.qml"),
                                          { "house": view.house, "list": modelData })
        menu: Component {
            ContextMenu {
                backgroundColor: FiatAgendaTheme.highlightWash
                highlightColor: FiatAgendaTheme.accent
                MenuItem {
                    visible: modelData.canEdit !== false && U.can(view.house, "canEditLists")
                    text: qsTr("Edit")
                    color: FiatAgendaTheme.primaryText
                    onClicked: view.openListDialog(modelData)
                }
                MenuItem {
                    visible: U.can(view.house, "canDeleteLists")
                    text: qsTr("Delete")
                    color: FiatAgendaTheme.wrong
                    onClicked: {
                        var id = modelData.id
                        row.remorseDelete(function () { view.deleteList(id) })
                    }
                }
            }
        }

        // The name and what is left, then a bar in the list's own colour for
        // how far it has got. The bar is the separation; no rule needed.
        Column {
            id: rowCol
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.paddingSmall

            Item {
                width: parent.width
                height: nameLabel.height
                Label {
                    id: nameLabel
                    anchors.left: parent.left
                    anchors.right: note.left
                    anchors.rightMargin: Theme.paddingMedium
                    text: U.str(modelData.name)
                    truncationMode: TruncationMode.Fade
                    color: row.highlighted ? FiatAgendaTheme.accent : FiatAgendaTheme.primaryText
                    font.family: FiatAgendaTheme.serif
                    font.pixelSize: Theme.fontSizeMedium
                }
                Label {
                    id: note
                    anchors.right: parent.right
                    anchors.baseline: nameLabel.baseline
                    visible: row.open >= 0
                    text: row.open > 0 ? qsTr("%1 of %2 left").arg(row.open).arg(row.open + row.done)
                        : row.done > 0 ? qsTr("all done") : qsTr("empty")
                    color: row.open > 0 ? FiatAgendaTheme.accent : FiatAgendaTheme.secondaryText
                    font.family: FiatAgendaTheme.serif
                    font.italic: row.open <= 0
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
            Label {
                width: parent.width
                visible: text !== ""
                text: U.str(modelData.description)
                truncationMode: TruncationMode.Fade
                color: FiatAgendaTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }
            Rectangle {
                width: parent.width
                height: Math.max(3, Math.round(Theme.paddingSmall * 0.7))
                radius: height / 2
                color: FiatAgendaTheme.hairline
                Rectangle {
                    readonly property int total: Math.max(0, row.open) + row.done
                    width: total > 0 ? parent.width * row.done / total : 0
                    height: parent.height
                    radius: parent.radius
                    color: U.str(modelData.color) !== "" ? modelData.color : FiatAgendaTheme.secondaryText
                }
            }
        }
    }

    footer: Column {
        width: view.width
        visible: view.house !== null

        Item { width: 1; height: Theme.paddingMedium }
        LinkText {
            x: Theme.horizontalPageMargin - Theme.paddingSmall
            visible: U.can(view.house, "canCreateLists")
            text: view.lists.length === 0 ? qsTr("No lists yet. Add one") : qsTr("Add a list")
            onClicked: view.openListDialog(null)
        }

        // Said once, quietly, where the phone's own lists end: sharing is
        // what Nextcloud adds.
        Item { width: 1; height: Theme.paddingLarge; visible: share.visible }
        Label {
            id: share
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * Theme.horizontalPageMargin
            visible: view.local && !account.signedIn
            wrapMode: Text.WordWrap
            text: qsTr("To share lists with your household, connect a Nextcloud with Pantry on it.")
            color: FiatAgendaTheme.secondaryText
            font.pixelSize: Theme.fontSizeExtraSmall
        }
        LinkText {
            x: Theme.horizontalPageMargin - Theme.paddingSmall
            visible: share.visible
            text: qsTr("Connect Nextcloud")
            onClicked: view.nextcloudWanted()
        }
        Item { width: 1; height: Theme.paddingLarge }
    }

    VerticalScrollDecorator { }
}
