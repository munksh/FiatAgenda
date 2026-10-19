#ifndef API_H
#define API_H

#include <QHash>
#include <QJSValue>
#include <QObject>
#include <QString>

class QJSEngine;
class QNetworkAccessManager;
class QNetworkReply;

// The Pantry API for QML: every call is relative to
// /ocs/v2.php/apps/pantry/api and answers a callback
//     function (ok, data, status, message)
// with the OCS payload already unwrapped. GET answers are kept on disk, so a
// page can show the last known state before the network has answered.
class Api : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(bool offline READ offline NOTIFY offlineChanged)

public:
    explicit Api(QObject *parent = nullptr);

    void setEngine(QJSEngine *engine) { m_engine = engine; }

    int busy() const { return m_busy; }
    QString error() const { return m_error; }
    bool offline() const { return m_offline; }

    Q_INVOKABLE void get(const QString &path, const QJSValue &query, const QJSValue &callback);
    Q_INVOKABLE void send(const QString &method, const QString &path, const QJSValue &body,
                          const QJSValue &callback);
    Q_INVOKABLE void upload(const QString &path, const QString &fileUrl, const QJSValue &fields,
                            const QJSValue &callback);

    Q_INVOKABLE QJSValue cached(const QString &path, const QJSValue &query) const;
    Q_INVOKABLE QString imageUrl(const QString &path, const QJSValue &query) const;
    Q_INVOKABLE void dismissError();

public slots:
    void clearCache();

signals:
    void busyChanged();
    void errorChanged();
    void offlineChanged();
    void unauthorized();

private:
    QString urlFor(const QString &path, const QJSValue &query) const;
    QString cacheFile(const QString &url) const;
    void track(QNetworkReply *reply, const QJSValue &callback, bool cacheIt, int timeoutMs);
    void finished(QNetworkReply *reply);
    void setError(const QString &error);
    void setOffline(bool offline);
    void setBusy(int busy);

    QJSEngine *m_engine = nullptr;
    QNetworkAccessManager *m_nam;
    QHash<QNetworkReply *, QJSValue> m_callbacks;
    QHash<QNetworkReply *, QString> m_cacheKeys;

    int m_busy = 0;
    QString m_error;
    bool m_offline = false;
};

#endif
