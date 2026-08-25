/*
 * Fiat Agenda -- entry point.
 *
 * v1 keeps all state in QML's LocalStorage, so there is nothing to register
 * here yet. When calendar export and scheduled reminders land, the helper
 * objects go in as context properties (setContextProperty in main), not
 * qmlRegisterType -- the cover page is loaded by URL and cannot see ids
 * declared in the app's root QML.
 */

#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include <sailfishapp.h>

int main(int argc, char *argv[])
{
    return SailfishApp::main(argc, argv);
}
