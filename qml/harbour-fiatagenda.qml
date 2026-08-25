/*
 * Fiat Agenda -- a fast, minimal task list.
 *
 * Part of the Munkstolen Fiat family. The Fiat colours standard lives in
 * FiatAgendaTheme; this file's one real job is to hand Silica's own chrome
 * the palette, once, at the top of the tree.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import "."          // qmldir lives here: this is what resolves FiatAgendaTheme
import "pages"
import "Storage.js" as Storage

ApplicationWindow {
    id: app

    initialPage: Component { MainPage { } }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    /*
     * Fiat colours reach only what the app draws itself. Menus, pull-down
     * drawers, TextField labels and underlines, sliders and selection all
     * read Theme.* directly, and most of them expose no colour property to
     * set. `palette` is the way in: assigned once here, every Silica control
     * on every page below inherits it.
     *
     * Re-applied rather than reverted when the switch is thrown -- under an
     * ambience applyPalette feeds Silica back its own Theme.* values, so the
     * toggle round-trips cleanly with nothing to remember.
     */
    Component.onCompleted: {
        Storage.init()
        // Same line Fiat Mos prints. If this never appears in
        //     journalctl -f | grep -i agenda
        // then the root QML itself never loaded, and the problem is the
        // package, not the pages.
        console.log("harbour-fiatagenda: started")
        // The theme re-applies the palette itself when the switch is thrown;
        // it needs to know what to apply it to.
        FiatAgendaTheme.appWindow = app
        // Once, here: palette is inherited, so every Silica control in every
        // page below picks it up.
        FiatAgendaTheme.applyPalette(app)
    }

    Connections {
        target: FiatAgendaTheme
        onAmbientChanged: FiatAgendaTheme.applyPalette(app)
    }
}
