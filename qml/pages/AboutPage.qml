import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"

// Who made this, what it does with your data, and where it came from.
//
// Same four questions in the same order as Fiat Mos, and nothing else. No
// changelog -- that belongs in the store listing and the repository, where it
// can be corrected. No donation button. Two links.
//
// The lead is three examples rather than a summary. "A task list where the
// date is optional" is accurate and says nothing; milk, the dentist and the
// plants say the same thing and can be pictured. They are also chosen to be
// the three shapes a task can have here: no date, a deadline, a repeat.
//
// The privacy paragraph is the only place in the app that makes a claim about
// itself, and it is written flat on purpose. It also says the OPPOSITE of the
// same paragraph in Fiat Mos -- there nothing is ever deleted, here delete
// means delete. Both are true, and each app should say which one it is.

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

    // Fiat colours paint their own paper. Under an ambience there is no
    // background at all -- the wallpaper is the background.
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
                text: qsTr("Most task apps want to know the project, the tag and the priority before they will let you write anything down. Fiat Agenda asks for the words. A date is optional, a time is optional, and no date at all is a proper answer rather than an unfinished one. Today and Upcoming are not lists you file things into — they are what the dates already say.")
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

            // -- The motto -------------------------------------------------
            //
            // Age quod agis is a real proverb and it shares a root with the
            // app's own name -- agere gives both agenda and agis. That is
            // stated up under "the name", where it is an etymology. Down here
            // the line is left to stand on its own; a motto that explains
            // itself is not a motto.

            Item { width: 1; height: Theme.paddingMedium }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: content.width - Theme.horizontalPageMargin * 2
                height: mottoColumn.height + Theme.paddingLarge * 2
                radius: FiatAgendaTheme.cardRadius
                color: FiatAgendaTheme.card
                border.color: FiatAgendaTheme.cardBorder
                border.width: FiatAgendaTheme.cardBorderWidth

                Column {
                    id: mottoColumn
                    anchors.centerIn: parent
                    width: parent.width - Theme.paddingLarge * 2
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
                text: qsTr("Fiat Agenda asks for one permission: your calendar. It is used only when you turn a task's own calendar switch on, and then only to write that one task's event into your default calendar, and to remove it again when the task changes or goes. A reminder rides on that event, which is why reminders still arrive when the app is closed. A task with the switch off never touches the calendar at all.")
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
            //
            // Every name translates itself, and the translation explains the
            // app. That is worth more than a tagline.

            SectionLabel {
                x: Theme.horizontalPageMargin
                text: qsTr("The Fiat family")
            }

            Repeater {
                model: [
                    { name: "fiat lux", what: qsTr("let there be light — a light meter for film") },
                    { name: "fiat vox", what: qsTr("let there be voice — a chromatic tuner") },
                    { name: "fiat cor", what: qsTr("let there be heart — a metronome, after the first one anybody owns") },
                    { name: "fiat mos", what: qsTr("let there be habit — a habit tracker where every habit is its own size") },
                    { name: "fiat margo", what: qsTr("let there be a margin — a picture given room before it becomes an ambience") },
                    { name: "fiat agenda", what: qsTr("let there be things to be done — this one") }
                ]

                Column {
                    x: Theme.horizontalPageMargin
                    width: content.width - Theme.horizontalPageMargin * 2

                    Label {
                        width: parent.width
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: FiatAgendaTheme.serif
                        color: FiatAgendaTheme.primaryText
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

            Item { width: 1; height: Theme.paddingMedium }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin * 2
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeTiny
                color: FiatAgendaTheme.secondaryText
                text: qsTr("Small instruments that each do one thing and leave the rest alone. They share a look, a palette and a stubbornness about staying on your own phone.")
            }

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
            //
            // A printer's mark at the end of a book: a short rule, the mark,
            // the wordmark. Nothing here is tappable -- the links are up under
            // "made by". This is the signature, not a button.

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
