import QtQuick 2.0
import Sailfish.Silica 1.0
import ".."
import "../components"
import "../Storage.js" as Storage

// What has been finished, newest first.
//
// This is not a history and not an archive -- there is no soft delete behind
// it and nothing here is kept for the record. It exists for the two minutes
// after you tick the wrong thing, and so that clearing out the week is one
// gesture rather than thirty.
//
// A recurring task never appears here: completing one moves it to its next
// occurrence instead of closing it.

Page {
    id: page

    allowedOrientations: defaultAllowedOrientations

    ListModel { id: doneModel }

    function reload() { Storage.loadCompleted(doneModel) }

    onStatusChanged: if (status === PageStatus.Active) reload()

    Component.onCompleted: paint()

    // Silica's own chrome -- the virtual keyboard, the menus, field labels and
    // underlines -- uses the palette it inherited when the page was BUILT.
    // Setting it on the ApplicationWindow alone is not enough: a page pushed
    // AFTER the switch was thrown carries the old one, which is why the main
    // page came out right and this one did not.
    //
    // So every page paints itself, on creation and on every later switch.
    function paint() { FiatAgendaTheme.applyPalette(page) }

    Connections {
        target: FiatAgendaTheme
        onAmbientChanged: page.paint()
    }


    FiatBackground { }

    RemorsePopup { id: remorse }

    SilicaListView {
        id: doneList

        anchors.fill: parent
        model: doneModel
        clip: true

        PullDownMenu {
            highlightColor: FiatAgendaTheme.accent

            MenuItem {
                text: qsTr("Clear all")
                color: FiatAgendaTheme.wrong
                enabled: doneModel.count > 0
                onClicked: remorse.execute(qsTr("Clearing"), function () {
                    Storage.clearCompleted()
                    page.reload()
                })
            }
        }

        header: Component {
            Column {
                width: page.width
                PageHead {
                    title: qsTr("completed")
                    subtitle: "fiat agenda"
                }
            }
        }

        delegate: ListItem {
            id: doneItem
            width: doneList.width
            contentHeight: Math.max(Theme.itemSizeSmall, FiatAgendaTheme.markSize + Theme.paddingLarge)
            highlightedColor: FiatAgendaTheme.highlightWash

            menu: Component {
                ContextMenu {
                    highlightColor: FiatAgendaTheme.accent

                    MenuItem {
                        text: qsTr("Not done")
                        color: FiatAgendaTheme.primaryText
                        onClicked: {
                            Storage.setDone(model.taskId, false)
                            page.reload()
                        }
                    }
                    MenuItem {
                        text: qsTr("Delete")
                        color: FiatAgendaTheme.wrong
                        onClicked: doneItem.remorseDelete(function () {
                            Storage.deleteTask(model.taskId)
                            doneModel.remove(index)
                        })
                    }
                }
            }

            Rectangle {
                id: mark
                anchors.left: parent.left
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                width: FiatAgendaTheme.markSize
                height: width
                radius: width / 2
                color: FiatAgendaTheme.accent
                border.width: 2
                border.color: FiatAgendaTheme.accent
            }

            Column {
                anchors.left: mark.right
                anchors.leftMargin: Theme.paddingMedium
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Label {
                    width: parent.width
                    text: model.title
                    color: FiatAgendaTheme.secondaryText
                    font.pixelSize: Theme.fontSizeMedium
                    truncationMode: TruncationMode.Fade
                }
                Label {
                    visible: model.listName !== ""
                    text: model.listName
                    color: FiatAgendaTheme.secondaryText
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
            }
        }

        VerticalScrollDecorator { }
    }

    // Outside the list view: a plain child of a ListView is parented to its
    // contentItem, which has no height when the model is empty.
    EmptyNote {
        enabled: doneModel.count === 0
        text: qsTr("Nothing finished yet")
    }
}
