pragma Singleton

import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0

// Fiat colours — the family standard. Two palettes behind one set of names,
// switched by a single boolean that is remembered between runs.
//
//   ambient = true   the user's ambience via Theme.*. No background is
//                    painted anywhere; the wallpaper is the background.
//   ambient = false  Fiat colours. The app paints its own light background
//                    and uses the family palette.
//
// Semantic colours ignore both. They mean something, so they only shift
// between a dark and a light variant to keep contrast.

QtObject {
    id: t

    // ---- the switch, remembered between runs ----
    property ConfigurationValue ambientConfig: ConfigurationValue {
        key: "/apps/harbour-fiatagenda/ambient"
        defaultValue: true
    }
    readonly property bool ambient: ambientConfig.value
    function setAmbient(on) { ambientConfig.value = on }

    // The ApplicationWindow, handed over at startup.
    //
    // The palette used to be re-applied from a Connections block in the root
    // QML. Under an ambience that change is invisible -- applyPalette feeds
    // Silica back its own Theme.* values -- so the first time anyone could
    // tell it had never fired was on switching TO Fiat colours, where the
    // keyboard and the placeholder text stayed ambience-coloured until the
    // app was restarted. Restarting worked because the palette IS applied at
    // startup, from Component.onCompleted.
    //
    // A singleton reacting to its own property does not depend on Connections
    // resolving a singleton target, which is the fragile part.
    property var appWindow: null

    onAmbientChanged: {
        applyPalette(appWindow)
        // And the page in front, in case an already-built page does not pick
        // up an inherited palette that changed under it.
        try {
            if (appWindow !== null && appWindow.pageStack !== null
                && appWindow.pageStack.currentPage !== null)
                applyPalette(appWindow.pageStack.currentPage)
        } catch (e) { }
    }

    // Fiat colours are a light scheme, so dark is false there.
    readonly property bool dark: ambient ? (Theme.colorScheme === Theme.LightOnDark) : false

    readonly property string serif: "Georgia"

    // ---- the notch ----
    //
    // Silica's own PageHeader clears the cutout. Ours do not, because they are
    // ours -- and on the Jolla Phone (2026) that puts the top of a capital
    // letter straight into the hole. So every header in this app starts this
    // far down.
    //
    // Read from the platform when the platform will say. Asking a QObject for a
    // property it does not have returns undefined rather than throwing, so the
    // probe is safe -- but the fallback has to be a real number, not a hope.
    function cutoutHeight() {
        if (typeof Screen === "undefined" || Screen === null) return -1
        var c = Screen.topCutout
        if (c === undefined || c === null) return -1
        if (typeof c === "number") return c
        if (c.height !== undefined) return c.height
        return -1
    }

    readonly property real headerTopInsetFallback: Theme.paddingLarge * 1.5

    readonly property real headerTopInset: {
        var c = cutoutHeight()
        return c >= 0 ? c + Theme.paddingMedium : headerTopInsetFallback
    }

    // Where the system's own indicators sit. Anything of ours that belongs on
    // that line -- the wordmark, Cancel, Save -- is centred on it rather than
    // given a top margin, so it reads as part of the same row instead of
    // nearly part of it.
    //
    // itemSizeLarge / 2, the number Fiat Mos arrived at the slow way: two
    // attempts at deriving it from the cutout (itemSizeExtraSmall / 2, then
    // headerTopInset / 2) both walked the wordmark up the screen for no
    // reason. Written down rather than derived. Bigger moves it down.
    //
    // "fiat agenda" is three characters longer than "fiat mos", so it is also
    // physically wider and taller in the corner -- which is exactly why it
    // cannot sit as high as a short one. This is the number that gives it room.
    readonly property real statusRowCenter: Theme.itemSizeLarge / 2

    // ---- text and accent ----
    readonly property color primaryText:   ambient ? Theme.primaryColor   : "#1A1A1A"
    readonly property color secondaryText: ambient ? Theme.secondaryColor : Qt.rgba(0.10, 0.10, 0.10, 0.55)

    // Fiat Agenda's accent: plum. It marks what is selected, what recurs and
    // what is interactive -- never a verdict. The verdicts are green, amber
    // and red below, and plum cannot be mistaken for any of them.
    readonly property color accent: ambient ? Theme.highlightColor : "#6E4A63"

    // ---- the shared paper ----
    readonly property color backgroundHigh: "#F2EFE8"
    readonly property color backgroundLow:  "#D8D2C6"

    readonly property color card: ambient
        ? (dark ? Qt.rgba(0.08, 0.08, 0.08, 1.0) : Qt.rgba(0.96, 0.96, 0.96, 1.0))
        : "#F5F5F5"
    readonly property color surface: card
    readonly property color cardBorder:   Theme.rgba(primaryText, 0.45)
    readonly property color innerBorder:  Theme.rgba(primaryText, 0.22)
    readonly property color recessFill:   Theme.rgba(primaryText, 0.05)
    readonly property color recessBorder: Theme.rgba(primaryText, 0.16)
    readonly property color hairline:     Theme.rgba(primaryText, 0.12)
    readonly property real cardRadius: Theme.paddingLarge * 2
    readonly property int cardBorderWidth: 2

    // ---- pills ----
    readonly property color pillFill:         Theme.rgba(primaryText, 0.15)
    readonly property color pillBorder:       Theme.rgba(primaryText, 0.55)
    readonly property color pillFillActive:   Theme.rgba(accent, 0.15)
    readonly property color pillBorderActive: Theme.rgba(accent, 0.45)

    // ---- meaning, never decoration ----
    //
    // ONE verdict. Like Fiat Mos, which also has exactly one.
    //
    // The app started with three colours here and lost two of them, both for
    // the same reason: they were not judgements.
    //
    //   done      finished is a state, not a verdict -- accent
    //   dueToday  today is a fact about the calendar, not about you -- accent
    //   overdue   you are late. That IS a verdict, and it stays red.
    //
    // So green went first and amber followed. What is left never follows the
    // ambience or the accent: an instrument that said different things in
    // different wallpapers would not be an instrument.
    readonly property color overdue: dark ? "#A0403A" : "#8A2B25"
    readonly property color wrong: overdue          // the name the family uses

    // The mark you tap to tick something off. Fiat Mos's habit indicator is
    // itemSizeSmall * 0.6 and that is the right size for a thumb -- the first
    // version of this app used itemSizeExtraSmall * 0.42, less than half the
    // area, and it was easier to miss than to hit.
    readonly property real markSize: Theme.itemSizeSmall * 0.6

    // Unfilled marks, empty rings, anything absent.
    readonly property color markIdle: Theme.rgba(primaryText, 0.30)
    readonly property color dotIdle: markIdle

    // Readable mark drawn on top of a filled colour.
    //
    // Measure, do not guess from the colour SCHEME: an ambience can pair a
    // light scheme with a dark highlight or the other way round. Perceived
    // luminance of the fill decides whether the mark on top is dark or light.
    //
    // A function, not a chain of readonly bindings -- the chained version came
    // out undefined on the device in Fiat Mos, and an undefined colour does
    // not shout, it silently renders black.
    function markOn(c) {
        if (c === undefined || c === null) return "#F5F5F5"
        return (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) > 0.55 ? "#1A1A1A" : "#F5F5F5"
    }

    readonly property color onAccent: markOn(accent)

    // The wash under a pressed row or menu item. Silica would use the ambience
    // highlight here, which bleeds through Fiat colours as a bright band over
    // the paper; this keeps the press in the app's own accent.
    readonly property color highlightWash: Theme.rgba(accent, 0.15)

    // ---- Silica's own chrome ----
    //
    // Menus, pull-down drawers, ComboBox values, TextField labels and
    // underlines, sliders, selection: none of these takes a colour from us.
    // They read Theme.* directly, which is the ambience, which is why they
    // stay ambience-coloured under Fiat colours no matter how many `color:`
    // lines get added to individual items.
    //
    // Silica's answer is `palette` -- colour roles that hang off an item and
    // are INHERITED by its children. Set it once on the ApplicationWindow and
    // every Silica control below follows.
    //
    // Written defensively on purpose: the roles are not guaranteed to exist on
    // every Silica version, and a missing property assigned in a QML binding
    // is a load-time error that kills the whole page. Assigned from JavaScript
    // a missing property is a no-op, and the try/catch takes the rest.
    //
    // This is necessary and NOT sufficient. Anything that draws its own text
    // must still name a colour from this file -- see the note in PageHead.
    function applyPalette(item) {
        if (item === null || item === undefined) return
        var p = item.palette
        if (p === undefined || p === null) return
        try { p.colorScheme = ambient ? Theme.colorScheme : Theme.DarkOnLight } catch (e) { }
        try { p.primaryColor = primaryText } catch (e) { }
        try { p.secondaryColor = secondaryText } catch (e) { }
        try { p.highlightColor = accent } catch (e) { }
        try { p.secondaryHighlightColor = Theme.rgba(accent, 0.6) } catch (e) { }
        // NOT the accent. This role is what the virtual keyboard paints its
        // keys with, and a 30% plum over light paper turned the whole keyboard
        // mauve. It is the same role that tints selected text, so it has to
        // stay quiet: a neutral wash serves both and shouts in neither.
        // (Fiat Mos paid for this one with a pale green keyboard.)
        try { p.highlightBackgroundColor = Theme.rgba(primaryText, 0.12) } catch (e) { }
        try { p.errorColor = overdue } catch (e) { }
        try { p.highlightDimmerColor = ambient ? Theme.highlightDimmerColor : backgroundLow } catch (e) { }
        try { p.overlayBackgroundColor = ambient ? Theme.overlayBackgroundColor : backgroundHigh } catch (e) { }
    }
}
