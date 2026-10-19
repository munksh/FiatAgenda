import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../Pantry.js" as U
import "../Shelf.js" as Shelf

// Every household you belong to, and who is in the one shown.
Page {
    id: page

    property var houses: []
    property int currentId: 0
    property var members: []

    signal chosen(var house)
    signal created(var house)

    function paint() { FiatAgendaTheme.applyPalette(page) }
    Component.onCompleted: {
        paint()
        if (currentId > 0) {
            var path = "/houses/" + currentId + "/members"
            var c = Shelf.cached(path, { "limit": 100 })
            if (c !== undefined)
                members = U.asArray(c)
            Shelf.get(path, { "limit": 100 }, function (ok, data) { if (ok) page.members = U.asArray(data) })
        }
    }
    Connections { target: FiatAgendaTheme; onAmbientChanged: page.paint() }

    function create() {
        var d = pageStack.push(Qt.resolvedUrl("HouseholdDialog.qml"))
        d.accepted.connect(function () {
            var body = { "name": d.name }
            if (d.description !== "") body.description = d.description
            Shelf.send("POST", "/houses", body, function (ok, data) {
                if (ok) {
                    page.created(data)
                    if (pageStack.currentPage === page)
                        pageStack.pop()
                }
            })
        })
    }

    FiatBackground { }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        PullDownMenu {
            highlightColor: FiatAgendaTheme.accent
            MenuItem {
                text: qsTr("New household")
                color: FiatAgendaTheme.primaryText
                onClicked: page.create()
            }
        }

        Column {
            id: content
            width: parent.width

            PageHead { title: qsTr("households") }
            ErrorLine { }

            Repeater {
                model: page.houses
                delegate: BackgroundItem {
                    id: row
                    readonly property bool current: modelData.id === page.currentId
                    width: content.width
                    height: Math.max(Theme.itemSizeMedium, col.height + 2 * Theme.paddingMedium)
                    highlightedColor: FiatAgendaTheme.highlightWash
                    onClicked: {
                        page.chosen(modelData)
                        pageStack.pop()
                    }
                    Column {
                        id: col
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        Label {
                            width: parent.width
                            text: U.str(modelData.name)
                            truncationMode: TruncationMode.Fade
                            color: row.current ? FiatAgendaTheme.accent : FiatAgendaTheme.primaryText
                            font.bold: row.current
                            font.pixelSize: Theme.fontSizeMedium
                            font.family: FiatAgendaTheme.serif
                        }
                        Label {
                            width: parent.width
                            text: [U.str(modelData.role), U.str(modelData.description)].filter(function (s) { return s !== "" }).join(" · ")
                            visible: text !== ""
                            truncationMode: TruncationMode.Fade
                            color: FiatAgendaTheme.secondaryText
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }
            }

            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                text: qsTr("Add a household")
                onClicked: page.create()
            }

            Item { width: 1; height: Theme.paddingLarge * 1.5; visible: page.members.length > 0 }
            SectionLabel {
                x: Theme.horizontalPageMargin
                visible: page.members.length > 0
                text: qsTr("In this household")
            }
            Item { width: 1; height: Theme.paddingSmall; visible: page.members.length > 0 }

            Repeater {
                model: page.members
                delegate: Item {
                    width: content.width
                    height: Theme.itemSizeSmall
                    Label {
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 2 * Theme.horizontalPageMargin - roleLabel.width - Theme.paddingMedium
                        text: U.str(modelData.displayName) !== "" ? modelData.displayName : U.str(modelData.userId)
                        truncationMode: TruncationMode.Fade
                        color: FiatAgendaTheme.primaryText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    Label {
                        id: roleLabel
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        text: U.str(modelData.role)
                        color: FiatAgendaTheme.secondaryText
                        font.pixelSize: Theme.fontSizeExtraSmall
                    }
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("People are added to a household in Pantry in the browser.")
                color: FiatAgendaTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }
        }

        VerticalScrollDecorator { }
    }

    ActivityLine { }
}
