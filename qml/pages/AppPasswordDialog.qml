import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

// Signing in without the browser: an app password made by hand in Nextcloud.
Dialog {
    id: dialog

    property string server: ""
    property string loginName: ""
    property string appPassword: ""

    canAccept: serverField.text.trim() !== "" && nameField.text.trim() !== "" && passwordField.text.trim() !== ""

    function paint() { FiatAgendaTheme.applyPalette(dialog) }
    Component.onCompleted: paint()

    onAccepted: {
        server = serverField.text.trim()
        loginName = nameField.text.trim()
        appPassword = passwordField.text.trim()
    }

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
                title: qsTr("App password")
                acceptText: qsTr("Sign in")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: qsTr("Make one in Nextcloud under Personal settings → Security → Devices & sessions, then write it here with your login name.")
                color: FiatAgendaTheme.secondaryText
                font.pixelSize: Theme.fontSizeExtraSmall
            }

            Item { width: 1; height: Theme.paddingMedium }

            TextField {
                id: serverField
                width: parent.width
                text: dialog.server
                label: qsTr("Nextcloud address")
                placeholderText: qsTr("cloud.example.com")
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: nameField.focus = true
            }
            TextField {
                id: nameField
                width: parent.width
                label: qsTr("Login name")
                placeholderText: qsTr("Login name")
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: passwordField.focus = true
            }
            PasswordField {
                id: passwordField
                width: parent.width
                label: qsTr("App password")
                placeholderText: qsTr("App password")
                EnterKey.enabled: dialog.canAccept
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: dialog.accept()
            }
        }
    }
}
