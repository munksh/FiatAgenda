#ifndef DAV_H
#define DAV_H

#include <QHash>
#include <QJSValue>
#include <QList>
#include <QObject>
#include <QPair>
#include <QString>

#include <functional>

class QJSEngine;
class QNetworkAccessManager;
class QNetworkReply;

// CalDAV, as much of it as task lists need: find the account's task lists,
// read every task in one, write one task, delete one, make a new list.
//
// Every call answers a callback. hrefs are the server's own paths
// (/remote.php/dav/calendars/…); the origin is put in front here.
class Dav : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit Dav(QObject *parent = nullptr);

    void setEngine(QJSEngine *engine) { m_engine = engine; }
    bool busy() const { return m_busy > 0; }

    // callback(ok, lists, message); lists = [{ href, name, color }]
    Q_INVOKABLE void discover(const QJSValue &callback);
    // callback(ok, items, status, message); items = [{ href, etag, ics }]
    Q_INVOKABLE void fetch(const QString &href, const QJSValue &callback);
    // An empty etag creates (If-None-Match: *), otherwise it updates (If-Match).
    // callback(ok, status, etag, message)
    Q_INVOKABLE void put(const QString &href, const QString &ics, const QString &etag, const QJSValue &callback);
    // callback(ok, status, message)
    Q_INVOKABLE void remove(const QString &href, const QString &etag, const QJSValue &callback);
    // callback(ok, href, message)
    Q_INVOKABLE void makeList(const QString &name, const QString &color, const QJSValue &callback);

    Q_INVOKABLE QString newUid() const;

signals:
    void busyChanged();
    void unauthorized();

private:
    struct Response;
    QNetworkReply *send(const QByteArray &verb, const QString &url, const QByteArray &body,
                        const QByteArray &depth, const QList<QPair<QByteArray, QByteArray>> &headers = {});
    QString origin() const;
    QString describe(QNetworkReply *reply, int status) const;
    void step(QNetworkReply *reply, std::function<void(QNetworkReply *, int, const QByteArray &)> then);
    void discoverAt(int attempt, const QJSValue &callback);
    void readHome(const QString &principal, const QJSValue &callback);
    void listHome(const QString &home, const QJSValue &callback);
    void answer(QJSValue callback, const QJSValueList &args);
    void setBusy(int delta);

    QJSEngine *m_engine = nullptr;
    QNetworkAccessManager *m_nam;
    QString m_home;
    int m_busy = 0;
};

#endif
