TARGET = harbour-fiatagenda

CONFIG += sailfishapp

SOURCES += src/harbour-fiatagenda.cpp

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
    qml/images/family/harbour-fiatagenda.png \
    qml/images/family/harbour-fiatmargo.png \
    qml/images/family/harbour-fiatglossa.png \
    qml/images/family/harbour-fiatvox.png \
    qml/images/family/harbour-fiatpons.png \
    qml/images/family/harbour-fiatlux.png \
    qml/images/family/harbour-fiatcor.png \
    qml/images/family/harbour-fiatpassus.png \
    qml/images/family/harbour-fiatmos.png \
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
    tools/make_icon.py \
    tools/fiat-agenda-icon.svg \
    tools/fiat-agenda-preview.html

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

isEmpty(APP_VERSION) {
    APP_VERSION = 0.0.0-dev
}
DEFINES += APP_VERSION=\\\"$$APP_VERSION\\\"

REQUIRED_FILES = \
    $${TARGET}.desktop \
    qml/$${TARGET}.qml \
    qml/qmldir \
    qml/Storage.js \
    qml/Dates.js \
    LICENSE

for(f, REQUIRED_FILES) {
    !exists($$PWD/$$f) {
        error("Missing $$f -- expected it at $$PWD/$$f. Check the filename character for character; a transfer that drops the hyphen from harbour-fiatagenda is the usual cause.")
    }
}

desktopfile.files = $$PWD/$${TARGET}.desktop
desktopfile.path = /usr/share/applications
INSTALLS += desktopfile

licensefile.files = $$PWD/LICENSE
licensefile.path = /usr/share/licenses/$${TARGET}
INSTALLS += licensefile
