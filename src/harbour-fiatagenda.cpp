/*
 * Fiat Agenda -- entry point.
 *
 * Tasks live in QML's LocalStorage and, when asked, in the platform calendar.
 * What C++ adds is the network: a Nextcloud account, the Pantry API for the
 * household's lists, and CalDAV for syncing tasks with Nextcloud Tasks. Each
 * is handed to QML as a context property on the ROOT context, so the cover
 * sees them too -- it is loaded by URL and cannot see ids in the root QML.
 *
 * APP_VERSION comes from the .pro, which takes it from the spec
 * (%qmake5 APP_VERSION=%{version}).
 *
 * The organisation and application names are NOT set here: sailjail sets
 * them from the .desktop file, and they decide where LocalStorage, the
 * account file and the cache live.
 */

#include <QtQuick>

#include <sailfishapp.h>

#include "account.h"
#include "api.h"
#include "authnam.h"
#include "dav.h"

#ifndef APP_VERSION
#define APP_VERSION "0.0.0-dev"
#endif

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));

    Account account;
    Api api;
    Dav dav;
    QObject::connect(&account, &Account::signedOut, &api, &Api::clearCache);

    AuthNamFactory namFactory;
    QScopedPointer<QQuickView> view(SailfishApp::createView());
    view->engine()->setNetworkAccessManagerFactory(&namFactory);
    api.setEngine(view->engine());
    dav.setEngine(view->engine());

    view->rootContext()->setContextProperty(QStringLiteral("appVersion"), QString::fromUtf8(APP_VERSION));
    view->rootContext()->setContextProperty(QStringLiteral("account"), &account);
    view->rootContext()->setContextProperty(QStringLiteral("api"), &api);
    view->rootContext()->setContextProperty(QStringLiteral("dav"), &dav);

    view->setSource(SailfishApp::pathTo(QStringLiteral("qml/harbour-fiatagenda.qml")));
    view->show();

    return app->exec();
}
