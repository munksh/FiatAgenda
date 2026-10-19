import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../Storage.js" as Storage

// Nextcloud: the account, and the two things it is for. Tasks sync with
// Nextcloud Tasks, all of them, from every list there. Lists can come from
// Pantry. Neither is needed;
// without them everything stays on this phone.
Page {
    id: page

    readonly property var app: FiatAgendaTheme.appWindow
    property string message: ""
    property var remote: []
    property var localLists: []
    property bool looking: false
    property string lookError: ""

    allowedOrientations: defaultAllowedOrientations

    function paint() { FiatAgendaTheme.applyPalette(page) }
    Component.onCompleted: {
        paint()
        readLists()
        if (app !== null && app.tasksSync) lookUp()
    }
    Connections { target: FiatAgendaTheme; onAmbientChanged: page.paint() }

    Connections {
        target: account
        onLoginUrlReady: Qt.openUrlExternally(url)
        onLoginFailed: page.message = message
        onSignedInNow: {
            page.message = ""
            if (page.app !== null && page.app.tasksSync) page.lookUp()
        }
    }
    Connections {
        target: page.app
        ignoreUnknownSignals: true
        onSynced: page.readLists()
        onSyncingChanged: if (!page.app.syncing) page.readLists()
    }

    function readLists() {
        remote = Storage.remoteLists()
        localLists = Storage.lists()
    }

    // Ask the server which task lists there are, and remember them.
    function lookUp() {
        looking = true
        lookError = ""
        dav.discover(function (ok, found, msg) {
            page.looking = false
            if (!ok) { page.lookError = msg; return }
            Storage.updateRemoteLists(found)
            page.readLists()
        })
    }

    function setSync(on) {
        if (app === null) return
        app.setTasksSync(on)
        if (on) lookUp()
    }

    function changed() {
        readLists()
        if (app !== null) app.syncNow()
    }

    readonly property var syncedNames: {
        var out = []
        for (var i = 0; i < remote.length; i++)
            if (remote[i].enabled && !remote[i].isDefault) out.push(remote[i].listName)
        return out
    }
    readonly property string defaultHref: {
        for (var i = 0; i < remote.length; i++)
            if (remote[i].enabled && remote[i].isDefault) return remote[i].href
        return ""
    }

    function lastSyncText() {
        if (app === null) return ""
        if (app.syncing) return qsTr("Syncing…")
        if (app.syncError !== "") return qsTr("Not synced: %1").arg(app.syncError)
        if (app.lastSync <= 0) return qsTr("Not synced yet.")
        var d = new Date(app.lastSync)
        var today = new Date()
        var sameDay = d.toDateString() === today.toDateString()
        return qsTr("Synced %1.").arg(sameDay ? Qt.formatTime(d, "HH:mm") : Qt.formatDateTime(d, "d MMM HH:mm"))
    }

    RemorsePopup { id: remorse }

    FiatBackground { }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge * 2

        PullDownMenu {
            visible: account.signedIn
            highlightColor: FiatAgendaTheme.accent
            MenuItem {
                text: qsTr("Sign out")
                color: FiatAgendaTheme.wrong
                onClicked: remorse.execute(qsTr("Signing out"), function () {
                    if (page.app !== null) page.app.signOut()
                    page.readLists()
                })
            }
            MenuItem {
                visible: page.app !== null && page.app.tasksSync
                text: qsTr("Sync now")
                color: FiatAgendaTheme.primaryText
                onClicked: { page.lookUp(); page.app.syncNow() }
            }
        }

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingMedium

            PageHead {
                title: qsTr("nextcloud")
                subtitle: "fiat agenda"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                text: qsTr("Your tasks can sync with Nextcloud Tasks, and Lists shows the household's shopping lists from Pantry. Both live on your own Nextcloud. Neither is needed: without them, everything stays on this phone.")
                color: FiatAgendaTheme.primaryText
                font.pixelSize: Theme.fontSizeSmall
                font.family: FiatAgendaTheme.serif
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                visible: page.app !== null && page.app.nextcloudNotice !== ""
                wrapMode: Text.WordWrap
                text: page.app !== null ? page.app.nextcloudNotice : ""
                color: FiatAgendaTheme.wrong
                font.pixelSize: Theme.fontSizeSmall
            }

            // ---- connecting ----
            Column {
                width: parent.width
                spacing: Theme.paddingMedium
                visible: !account.signedIn

                TextField {
                    id: serverField
                    width: parent.width
                    label: qsTr("Nextcloud address")
                    placeholderText: qsTr("cloud.example.com")
                    color: FiatAgendaTheme.primaryText
                    inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    enabled: !account.waiting && !account.starting
                    EnterKey.enabled: text.trim() !== ""
                    EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                    EnterKey.onClicked: { focus = false; page.message = ""; account.startLogin(text) }
                }

                FiatButton {
                    visible: !account.waiting
                    text: qsTr("connect")
                    enabled: serverField.text.trim() !== "" && !account.starting
                    onClicked: { serverField.focus = false; page.message = ""; account.startLogin(serverField.text) }
                }

                BusyIndicator {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: BusyIndicatorSize.Medium
                    running: account.starting || account.waiting
                    visible: running
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - Theme.horizontalPageMargin * 2
                    visible: account.waiting
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Sign in and allow access in the browser, then come back here. The phone gets an app password of its own.")
                    color: FiatAgendaTheme.primaryText
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: FiatAgendaTheme.serif
                    font.italic: true
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingLarge
                    visible: account.waiting
                    LinkText {
                        text: qsTr("Open the page again")
                        onClicked: Qt.openUrlExternally(account.loginUrl)
                    }
                    LinkText {
                        text: qsTr("Cancel")
                        color: FiatAgendaTheme.secondaryText
                        onClicked: account.cancelLogin()
                    }
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - Theme.horizontalPageMargin * 2
                    visible: page.message !== ""
                    wrapMode: Text.WordWrap
                    text: page.message
                    color: FiatAgendaTheme.wrong
                    font.pixelSize: Theme.fontSizeSmall
                }

                LinkText {
                    x: Theme.horizontalPageMargin - Theme.paddingSmall
                    visible: !account.waiting
                    text: qsTr("Use an app password instead")
                    onClicked: {
                        var d = pageStack.push(Qt.resolvedUrl("AppPasswordDialog.qml"), { "server": serverField.text })
                        d.accepted.connect(function () {
                            page.message = ""
                            serverField.text = d.server
                            account.loginWithAppPassword(d.server, d.loginName, d.appPassword)
                        })
                    }
                }
                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - Theme.horizontalPageMargin * 2
                    visible: !account.waiting
                    wrapMode: Text.WordWrap
                    text: qsTr("For a server the browser cannot reach, or a certificate it refuses.")
                    color: FiatAgendaTheme.secondaryText
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
            }

            // ---- connected ----
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                visible: account.signedIn
                wrapMode: Text.WordWrap
                text: qsTr("Connected as %1 on %2.").arg(account.displayName).arg(account.server.replace(/^https?:\/\//, ""))
                color: FiatAgendaTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            // ---- tasks ----
            Item { width: 1; height: Theme.paddingMedium; visible: account.signedIn }
            SectionLabel {
                x: Theme.horizontalPageMargin
                visible: account.signedIn
                text: qsTr("Tasks · Nextcloud Tasks")
            }

            SwitchRow {
                visible: account.signedIn
                text: qsTr("Sync tasks")
                description: qsTr("Both ways. A task changed in two places at once keeps the newer change.")
                checked: page.app !== null && page.app.tasksSync
                onClicked: page.setSync(!(page.app !== null && page.app.tasksSync))
            }

            Column {
                width: parent.width
                spacing: Theme.paddingMedium
                visible: account.signedIn && page.app !== null && page.app.tasksSync

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - Theme.horizontalPageMargin * 2
                    wrapMode: Text.WordWrap
                    text: page.looking ? qsTr("Asking the server for its task lists…")
                          : page.lookError !== "" ? page.lookError
                          : page.lastSyncText()
                    color: page.lookError !== "" || (page.app !== null && page.app.syncError !== "")
                           ? FiatAgendaTheme.wrong : FiatAgendaTheme.secondaryText
                    font.pixelSize: Theme.fontSizeExtraSmall
                }

                SectionLabel {
                    x: Theme.horizontalPageMargin
                    visible: page.remote.length > 0
                    text: qsTr("New tasks go to")
                }
                Flow {
                    x: Theme.horizontalPageMargin
                    width: parent.width - Theme.horizontalPageMargin * 2
                    spacing: Theme.paddingSmall
                    visible: page.remote.length > 0

                    Repeater {
                        model: page.remote
                        Pill {
                            text: modelData.name
                            selected: modelData.isDefault && modelData.enabled
                            onClicked: if (!selected) { Storage.setHome(modelData.href); page.changed() }
                        }
                    }
                }

                SectionLabel {
                    x: Theme.horizontalPageMargin
                    visible: page.syncedNames.length > 0
                    text: qsTr("Lists on the server")
                }
                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - Theme.horizontalPageMargin * 2
                    visible: page.syncedNames.length > 0
                    wrapMode: Text.WordWrap
                    text: page.syncedNames.join(" · ")
                    color: FiatAgendaTheme.primaryText
                    font.pixelSize: Theme.fontSizeSmall
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - Theme.horizontalPageMargin * 2
                    wrapMode: Text.WordWrap
                    text: qsTr("Every task on this phone is synced, and every task on the server comes here, whichever of its lists it is in. A task stays in the list it came from; a new one goes to the list chosen above. Switching sync off lets go of the server; nothing is deleted there. Reminders stay on this phone.")
                    color: FiatAgendaTheme.secondaryText
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
            }

            // ---- lists ----
            Item { width: 1; height: Theme.paddingMedium; visible: account.signedIn }
            SectionLabel {
                x: Theme.horizontalPageMargin
                visible: account.signedIn
                text: qsTr("Lists · Pantry")
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                visible: account.signedIn
                wrapMode: Text.WordWrap
                color: account.pantryState === "missing" || account.pantryState === "unreachable"
                       ? FiatAgendaTheme.wrong : FiatAgendaTheme.secondaryText
                font.pixelSize: Theme.fontSizeSmall
                text: {
                    switch (account.pantryState) {
                    case "present":
                        return qsTr("Pantry %1 is on the server. The household's lists are under Lists on the front page.").arg(account.pantryVersion)
                    case "missing":
                        return qsTr("Pantry is not installed on this server. Someone with admin rights can add it from the Nextcloud app store.")
                    case "unreachable":
                        return qsTr("The server cannot be reached right now.")
                    default:
                        return qsTr("Looking for Pantry on the server…")
                    }
                }
            }
            LinkText {
                x: Theme.horizontalPageMargin - Theme.paddingSmall
                visible: account.signedIn && account.pantryState !== "present" && account.pantryState !== "checking"
                text: qsTr("Look again")
                onClicked: account.checkPantry()
            }

            Item { width: 1; height: Theme.paddingLarge; visible: account.signedIn }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                visible: account.signedIn
                wrapMode: Text.WordWrap
                text: qsTr("Signing out, in the pull-down menu, withdraws this phone's app password on the server. Every task stays on the phone.")
                color: FiatAgendaTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }
        }

        VerticalScrollDecorator { }
    }

    ActivityLine {
        running: api.busy > 0 || dav.busy || page.looking
    }
}
