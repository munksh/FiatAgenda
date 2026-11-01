import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import ".."
import "../components"
import "../Storage.js" as Storage

// The lists Agenda 2.0 kept on this phone, saved as one file in Documents for
// fiat penus to bring in. Nothing is taken out of Agenda: the lists stay in
// its database, and saving again writes a fresh file.
Page {
    id: page

    readonly property string fileName: "fiat-agenda-lists.json"
    property var counts: ({ lists: 0, items: 0 })
    property string savedPath: ""
    property bool failed: false

    ConfigurationValue {
        id: listsNoticeConfig
        key: "/apps/harbour-fiatagenda/listsNotice"
        defaultValue: ""
    }

    allowedOrientations: defaultAllowedOrientations

    function paint() { FiatAgendaTheme.applyPalette(page) }
    Component.onCompleted: {
        paint()
        var all = Storage.shelfExport()
        counts = { lists: all.lists.length, items: all.items.length }
    }
    Connections { target: FiatAgendaTheme; onAmbientChanged: page.paint() }

    function save() {
        failed = false
        var path = files.saveDocument(fileName, JSON.stringify(Storage.shelfExport(), null, 1))
        if (path === "") {
            failed = true
            return
        }
        savedPath = path
        listsNoticeConfig.value = "moved"
    }

    FiatBackground { }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge * 2

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingMedium

            PageHead {
                title: qsTr("lists to fiat penus")
                subtitle: "fiat agenda"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                text: qsTr("Lists live in fiat penus now, beside the household's notes and photos. Agenda keeps to tasks.")
                color: FiatAgendaTheme.primaryText
                font.pixelSize: Theme.fontSizeSmall
                font.family: FiatAgendaTheme.serif
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                text: qsTr("On this phone: %1 and %2.")
                      .arg(page.counts.lists === 1 ? qsTr("1 list") : qsTr("%1 lists").arg(page.counts.lists))
                      .arg(page.counts.items === 1 ? qsTr("1 item") : qsTr("%1 items").arg(page.counts.items))
                color: FiatAgendaTheme.secondaryText
                font.pixelSize: Theme.fontSizeSmall
            }

            Item { width: 1; height: Theme.paddingMedium }

            FiatButton {
                text: page.savedPath === "" ? qsTr("save for fiat penus") : qsTr("save again")
                enabled: page.counts.lists > 0
                onClicked: page.save()
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                visible: page.savedPath !== ""
                wrapMode: Text.WordWrap
                text: qsTr("Saved as %1 in Documents. In fiat penus, pull down on Lists and choose Bring in lists from fiat agenda.").arg(page.fileName)
                color: FiatAgendaTheme.primaryText
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                visible: page.failed
                wrapMode: Text.WordWrap
                text: qsTr("The file could not be written to Documents.")
                color: FiatAgendaTheme.wrong
                font.pixelSize: Theme.fontSizeSmall
            }

            Item { width: 1; height: Theme.paddingLarge }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                text: qsTr("The lists stay in Agenda as well; nothing is deleted here. Shared lists from Pantry need no moving: sign in to the same Nextcloud in fiat penus and they are there.")
                color: FiatAgendaTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }
        }

        VerticalScrollDecorator { }
    }
}
