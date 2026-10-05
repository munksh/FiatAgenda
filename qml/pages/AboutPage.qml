import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

Page {
    id: page

    allowedOrientations: defaultAllowedOrientations

    // Every page paints itself, on creation and on every later switch --
    // a page built before the toggle was thrown carries the old palette.
    Component.onCompleted: paint()
    function paint() { FiatAgendaTheme.applyPalette(page) }

    Connections {
        target: FiatAgendaTheme
        onAmbientChanged: page.paint()
    }

    FiatBackground { }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        Column {
            id: content
            width: parent.width
            spacing: Theme.paddingMedium

            PageHead {
                title: qsTr("about")
                subtitle: "fiat agenda"
            }

            // -- What it is -----------------------------------------------

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeMedium
                font.family: FiatAgendaTheme.serif
                color: FiatAgendaTheme.primaryText
                text: qsTr("Buy milk. Call the dentist before Friday. Water the plants every Sunday, for as long as there are plants.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatAgendaTheme.secondaryText
                text: qsTr("Most task apps want to know the project, the tag and the priority before they will let you write anything down. fiat agenda asks for the words. A date is optional, a time is optional, and no date at all is a proper answer rather than an unfinished one. Today and Upcoming are not lists you file things into — they are what the dates already say.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatAgendaTheme.secondaryText
                text: qsTr("It is not a project manager. If a feature would only matter to someone running work across a team, it is not here, and that is the whole design.")
            }

            // -- The name --------------------------------------------------

            SectionLabel {
                x: Theme.horizontalPageMargin
                text: qsTr("The name")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatAgendaTheme.secondaryText
                textFormat: Text.StyledText
                linkColor: FiatAgendaTheme.accent
                text: qsTr("<b>fiat</b> — Latin, <i>let there be</i>. From <i>fiat lux</i> in the Vulgate: let there be light, and there was light. The first app took the phrase. The rest of the family kept the verb.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatAgendaTheme.secondaryText
                textFormat: Text.StyledText
                text: qsTr("<b>agenda</b> — Latin, <i>the things that must be done</i>. Not a list and not a plan: a plural, from <i>agere</i>, to do. English borrowed it and made it singular, which is a shame. Every entry here is one of the things.")
            }

            Item { width: 1; height: Theme.paddingLarge }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.itemSizeSmall
                height: 1
                color: FiatAgendaTheme.innerBorder
            }

            Item { width: 1; height: Theme.paddingMedium }

            Column {
                x: Theme.horizontalPageMargin
                width: content.width - Theme.horizontalPageMargin * 2
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: FiatAgendaTheme.serif
                    font.italic: true
                    color: FiatAgendaTheme.primaryText
                    text: "Age quod agis"
                }

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: FiatAgendaTheme.secondaryText
                    text: qsTr("Do the thing you are doing.")
                }
            }

            Item { width: 1; height: Theme.paddingMedium }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.itemSizeSmall
                height: 1
                color: FiatAgendaTheme.innerBorder
            }

            // -- Privacy ---------------------------------------------------

            SectionLabel {
                x: Theme.horizontalPageMargin
                text: qsTr("Your data")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatAgendaTheme.secondaryText
                text: qsTr("Everything stays on this phone, in one file. There is no account, no network access, and nothing is measured or reported.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatAgendaTheme.secondaryText
                text: qsTr("fiat agenda asks for one permission: your calendar. It is used only when you turn a task's own calendar switch on, and then only to write that one task's event into your default calendar, and to remove it again when the task changes or goes. A reminder rides on that event, which is why reminders still arrive when the app is closed. A task with the switch off never touches the calendar at all.")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatAgendaTheme.secondaryText
                text: qsTr("Delete means delete. There is no archive, no hidden copy and no bin to empty later. Completed tasks are kept, because a done task is still something you did, but a deleted one is gone.")
            }

            // -- Who ---------------------------------------------------------

            SectionLabel {
                x: Theme.horizontalPageMargin
                text: qsTr("Made by")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                font.pixelSize: Theme.fontSizeMedium
                font.family: FiatAgendaTheme.serif
                color: FiatAgendaTheme.primaryText
                text: "Munkstolen"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                font.pixelSize: Theme.fontSizeExtraSmall
                color: FiatAgendaTheme.secondaryText
                text: "Caesar Prometheus Ivarsson"
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                highlightedColor: FiatAgendaTheme.highlightWash
                onClicked: Qt.openUrlExternally("https://munkstolen.se")

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.horizontalPageMargin
                    width: parent.width - Theme.horizontalPageMargin * 2

                    Label {
                        width: parent.width
                        truncationMode: TruncationMode.Fade
                        color: FiatAgendaTheme.accent
                        font.pixelSize: Theme.fontSizeSmall
                        text: "munkstolen.se"
                    }

                    Label {
                        width: parent.width
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: FiatAgendaTheme.secondaryText
                        text: qsTr("Everything else I make")
                    }
                }
            }

            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeSmall
                highlightedColor: FiatAgendaTheme.highlightWash
                onClicked: Qt.openUrlExternally("https://github.com/munksh/FiatAgenda")

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.horizontalPageMargin
                    width: parent.width - Theme.horizontalPageMargin * 2

                    Label {
                        width: parent.width
                        truncationMode: TruncationMode.Fade
                        color: FiatAgendaTheme.accent
                        font.pixelSize: Theme.fontSizeSmall
                        text: "github.com/munksh/FiatAgenda"
                    }

                    Label {
                        width: parent.width
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: FiatAgendaTheme.secondaryText
                        text: qsTr("Source and issues · MIT licence")
                    }
                }
            }

            // -- The family ---------------------------------------------------

            SectionLabel {
                x: Theme.horizontalPageMargin
                text: qsTr("The fiat family")
            }

            Repeater {
                model: [
                    { name: "fiat agenda", what: qsTr("let there be doing — this one"), icon: "images/family/harbour-fiatagenda.png", url: "" },
                    { name: "fiat margo", what: qsTr("let there be edge — keeps edges"), icon: "images/family/harbour-fiatmargo.png", url: "https://openrepos.net/content/munkstolen/fiat-margo-keeps-edges" },
                    { name: "fiat glossa", what: qsTr("let there be tongue — a translator"), icon: "images/family/harbour-fiatglossa.png", url: "https://openrepos.net/content/munkstolen/fiat-glossa-a-deepl-translator" },
                    { name: "fiat vox", what: qsTr("let there be voice — a chromatic tuner"), icon: "images/family/harbour-fiatvox.png", url: "https://openrepos.net/content/munkstolen/fiat-vox-chromatic-tuner" },
                    { name: "fiat pons", what: qsTr("let there be bridge — a native Qobuz client"), icon: "images/family/harbour-fiatpons.png", url: "https://openrepos.net/content/munkstolen/fiat-pons-native-qobuz-client" },
                    { name: "fiat lux", what: qsTr("let there be light — a light meter for film"), icon: "images/family/harbour-fiatlux.png", url: "https://openrepos.net/content/munkstolen/fiat-lux-lightmeter-film-photography" },
                    { name: "fiat cor", what: qsTr("let there be heart — a metronome"), icon: "images/family/harbour-fiatcor.png", url: "https://openrepos.net/content/munkstolen/fiat-cor-a-metronome" },
                    { name: "fiat passus", what: qsTr("let there be step — a step counter - Coming soon"), icon: "images/family/harbour-fiatpassus.png", url: "" },
                    { name: "fiat mos", what: qsTr("let there be habit — a habit tracker"), icon: "images/family/harbour-fiatmos.png", url: "https://openrepos.net/content/munkstolen/fiat-mos-habit-tracker" },
                    { name: "fiat imago", what: qsTr("let there be image — a raw editor"), icon: "images/family/harbour-fiatimago.png", url: "https://openrepos.net/content/munkstolen/fiat-imago-raw-editor" },
                    { name: "fiat ratio", what: qsTr("let there be reckoning — a budget tool"), icon: "images/family/harbour-fiatratio.png", url: "https://openrepos.net/content/munkstolen/fiat-ratio-budget-tool" }
                ]

                // A full-size icon in a row of its own height, rather than an
                // icon shrunk to the height of two lines of text. The icon is
                // the app's face; it should be readable.
                delegate: BackgroundItem {
                    width: content.width
                    height: Theme.itemSizeMedium
                    enabled: modelData.url !== ""
                    highlightedColor: FiatAgendaTheme.highlightWash
                    onClicked: Qt.openUrlExternally(modelData.url)

                    Image {
                        id: familyIcon
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.itemSizeSmall
                        height: Theme.itemSizeSmall
                        sourceSize.width: Theme.itemSizeSmall
                        sourceSize.height: Theme.itemSizeSmall
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: Qt.resolvedUrl(modelData.icon)
                    }

                    Column {
                        anchors.left: familyIcon.right
                        anchors.leftMargin: Theme.paddingLarge
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            width: parent.width
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: FiatAgendaTheme.serif
                            color: modelData.url !== "" ? FiatAgendaTheme.accent : FiatAgendaTheme.primaryText
                            text: modelData.name
                        }

                        Label {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: FiatAgendaTheme.secondaryText
                            text: modelData.what
                        }
                    }
                }
            }

            Item { width: 1; height: Theme.paddingMedium }

            // -- Version ---------------------------------------------------
            //
            // Last, because it is support and not identity. The number comes
            // from the rpm spec by way of qmake, so it is the one the package
            // was actually built with rather than one written down twice.

            SectionLabel {
                x: Theme.horizontalPageMargin
                text: qsTr("Version")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                font.pixelSize: Theme.fontSizeSmall
                color: FiatAgendaTheme.primaryText
                text: typeof appVersion !== "undefined" ? appVersion : qsTr("unknown")
            }

            // -- Colophon --------------------------------------------------

            Item { width: 1; height: Theme.itemSizeExtraSmall }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.itemSizeSmall
                height: 1
                color: FiatAgendaTheme.innerBorder
            }

            Item { width: 1; height: Theme.paddingLarge }

            MunkstolenMark {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.itemSizeMedium
                frame: "ring"
                color: FiatAgendaTheme.makerMark
            }

            Item { width: 1; height: Theme.paddingSmall }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "munkstolen"
                font.pixelSize: Theme.fontSizeSmall
                font.family: FiatAgendaTheme.serif
                font.italic: true
                color: FiatAgendaTheme.makerMark
            }
        }

        VerticalScrollDecorator { }
    }
}
