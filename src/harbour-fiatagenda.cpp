/*
 * Fiat Agenda -- entry point.
 *
 * All state lives in QML's LocalStorage and the platform calendar, so there
 * is nothing to register here. The one thing C++ still has to do is hand QML
 * the version string: QML cannot read the rpm spec, and a number typed into
 * the about page by hand is a number that will one day be wrong.
 *
 * APP_VERSION comes from the .pro, which takes it from the spec:
 *
 *     %build
 *     %qmake5 APP_VERSION=%{version}
 *
 * So SailfishApp::main() is replaced by what it does internally -- an
 * application, a view, a source -- with one extra line in the middle. Nothing
 * else changes; this IS the template's other documented form.
 *
 * setContextProperty on the ROOT context, so the cover page sees it too. The
 * cover is loaded by URL and cannot see ids declared in the app's root QML,
 * which is the same reason helper objects would go here rather than there.
 */

#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QScopedPointer>
#include <QString>

#include <sailfishapp.h>

// A build with no version passed in should say so rather than invent one.
#ifndef APP_VERSION
#define APP_VERSION "0.0.0-dev"
#endif

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    QScopedPointer<QQuickView> view(SailfishApp::createView());

    view->rootContext()->setContextProperty("appVersion",
                                            QString(QLatin1String(APP_VERSION)));

    view->setSource(SailfishApp::pathTo("qml/harbour-fiatagenda.qml"));
    view->show();

    return app->exec();
}
