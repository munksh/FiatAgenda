# Fiat Agenda -- a fast, minimal task list for Sailfish OS.
#
# The harbour- prefix is a STORE requirement, not a name. It is the package
# and binary name; what anyone actually sees is Name= in the .desktop file,
# which still says "Fiat Agenda".
#
# TARGET and the root QML filename must match. Change one and you change:
#   - qml/<TARGET>.qml
#   - <TARGET>.desktop, and Icon= and Exec= inside it
#   - icons/*/<TARGET>.png
#   - rpm/<TARGET>.spec, and Name: inside it
#
# NOTE: any change to this file means
#   Build -> Clean All -> Run qmake -> Build
# in Qt Creator, or the new files will not be picked up.

TARGET = harbour-fiatagenda

CONFIG += sailfishapp

SOURCES += src/harbour-fiatagenda.cpp

# Every QML and JS file must be listed here or it will not be deployed.
# qmldir in particular: leave it out and the app dies at startup with
# "FiatAgendaTheme is not a type".
DISTFILES += \
    qml/harbour-fiatagenda.qml \
    qml/FiatAgendaTheme.qml \
    qml/qmldir \
    qml/Storage.js \
    qml/Dates.js \
    qml/components/FiatBackground.qml \
    qml/components/PageHead.qml \
    qml/components/Wordmark.qml \
    qml/components/SectionLabel.qml \
    qml/components/EmptyNote.qml \
    qml/components/DialogHead.qml \
    qml/components/Pill.qml \
    qml/components/TaskRow.qml \
    qml/components/CalendarBridge.qml \
    qml/components/MunkstolenMark.qml \
    qml/pages/MainPage.qml \
    qml/pages/TaskPage.qml \
    qml/pages/DateDialog.qml \
    qml/pages/TimeDialog.qml \
    qml/pages/CompletedPage.qml \
    qml/pages/AboutPage.qml \
    qml/cover/CoverPage.qml \
    rpm/harbour-fiatagenda.spec \
    harbour-fiatagenda.desktop

# Not deployed -- kept in the repo so the icon and the design rig can be
# regenerated. tools/make_icon.py rewrites icons/ and the SVG source.
OTHER_FILES += \
    LICENSE \
    tools/make_icon.py \
    tools/fiat-agenda-icon.svg \
    tools/fiat-agenda-preview.html

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

# Belt and braces. sailfishapp.prf installs $${TARGET}.desktop on its own --
# when it can find it. If the file is missing, misnamed, or was added after
# the last qmake run, the prf quietly installs nothing, `make install` never
# mentions a desktop file, and the build dies much later and much less
# clearly:
#
#   desktop-file-install ... '/home/deploy/installroot/usr/share/applications/*.desktop'
#   Error on file ...: No such file or directory
#
# So state it here too. A distinct target name (desktopfile, not desktop) so
# this cannot fight whatever the prf defines. Installing the same file twice
# is harmless; not installing it at all costs an hour.
# ---------------------------------------------------------------------------
# The version string the about page shows.
#
# ONE source of truth: the rpm spec. %build passes it in --
#
#     %qmake5 APP_VERSION=%{version}
#
# -- so the number in the about page is the number the package was actually
# built with, and there is nothing to keep in step by hand.
#
# The fallback is deliberately not a plausible version. A build straight out
# of Qt Creator, with no rpm around it, should SAY it is a development build
# rather than claim to be the release it is not.
isEmpty(APP_VERSION) {
    APP_VERSION = 0.0.0-dev
}
DEFINES += APP_VERSION=\\\"$$APP_VERSION\\\"

# ---------------------------------------------------------------------------
# Files without which the package is broken, checked at qmake time.
#
# Every one of these fails SILENTLY otherwise, and each silent failure looks
# like a different bug:
#
#   qml/$${TARGET}.qml   missing -> the binary starts, finds no QML, white
#                        screen, and the only clue is one [W] line in
#                        journalctl saying "File not found"
#   $${TARGET}.desktop   missing -> qmake drops the install rule with a
#                        warning nobody reads, and the build dies much later
#                        on an unexpanded *.desktop glob
#   qml/qmldir           missing -> every page dies with "FiatAgendaTheme is
#                        not a type"
#   the .js files        missing -> the root QML fails to load. White screen
#                        again, different cause.
#
# All four have actually happened. A file transferred by hand can arrive
# renamed -- a browser that strips the hyphen out of harbour-fiatagenda.qml is
# enough -- so the build checks rather than assumes.
REQUIRED_FILES = \
    $${TARGET}.desktop \
    qml/$${TARGET}.qml \
    qml/qmldir \
    qml/Storage.js \
    qml/Dates.js

for(f, REQUIRED_FILES) {
    !exists($$PWD/$$f) {
        error("Missing $$f -- expected it at $$PWD/$$f. Check the filename character for character; a transfer that drops the hyphen from harbour-fiatagenda is the usual cause.")
    }
}

# $$PWD, not a bare filename. This is a shadow build -- qmake runs in
# build-harbourfiatagenda-.../ and a relative path in an INSTALLS entry can be
# resolved against the BUILD directory rather than the source one. $$PWD is
# the directory holding this .pro file, absolute, always.
desktopfile.files = $$PWD/$${TARGET}.desktop
desktopfile.path = /usr/share/applications
INSTALLS += desktopfile
