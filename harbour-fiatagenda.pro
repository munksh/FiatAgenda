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
    qml/pages/MainPage.qml \
    qml/pages/TaskPage.qml \
    qml/pages/DateDialog.qml \
    qml/pages/TimeDialog.qml \
    qml/pages/CompletedPage.qml \
    qml/cover/CoverPage.qml \
    rpm/harbour-fiatagenda.spec \
    harbour-fiatagenda.desktop

# Not deployed -- kept in the repo so the icon and the design rig can be
# regenerated. tools/make_icon.py rewrites icons/ and the SVG source.
OTHER_FILES += \
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
#   Error on file ...: N o such file or directory
#
# So state it here too. A distinct target name (desktopfile, not desktop) so
# this cannot fight whatever the prf defines. Installing the same file twice
# is harmless; not installing it at all costs an hour.
desktopfile.files = $${TARGET}.desktop
desktopfile.path = /usr/share/applications
INSTALLS += desktopfile
