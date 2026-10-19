#ifndef ACCOUNT_H
#define ACCOUNT_H

#include <QDateTime>
#include <QObject>
#include <QString>
#include <QTimer>

class QNetworkAccessManager;
class QNetworkReply;

// One Nextcloud account: signing in with Login Flow v2 (or an app password
// typed by hand), keeping the app password, and asking the server whether
// Pantry is installed.
class Account : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool signedIn READ signedIn NOTIFY changed)
    Q_PROPERTY(QString server READ server NOTIFY changed)
    Q_PROPERTY(QString loginName READ loginName NOTIFY changed)
    Q_PROPERTY(QString displayName READ displayName NOTIFY displayNameChanged)
    Q_PROPERTY(bool waiting READ waiting NOTIFY waitingChanged)
    Q_PROPERTY(bool starting READ starting NOTIFY waitingChanged)
    Q_PROPERTY(QString loginUrl READ loginUrl NOTIFY waitingChanged)
    Q_PROPERTY(QString pantryState READ pantryState NOTIFY pantryChanged)
    Q_PROPERTY(QString pantryVersion READ pantryVersion NOTIFY pantryChanged)

public:
    explicit Account(QObject *parent = nullptr);

    bool signedIn() const;
    QString server() const { return m_server; }
    QString loginName() const { return m_loginName; }
    QString displayName() const { return m_displayName.isEmpty() ? m_loginName : m_displayName; }
    bool waiting() const { return m_waiting; }
    bool starting() const { return m_starting; }
    QString loginUrl() const { return m_loginUrl; }
    QString pantryState() const { return m_pantryState; }
    QString pantryVersion() const { return m_pantryVersion; }

    Q_INVOKABLE QString normaliseServer(const QString &input) const;
    Q_INVOKABLE void startLogin(const QString &serverInput);
    Q_INVOKABLE void cancelLogin();
    Q_INVOKABLE void loginWithAppPassword(const QString &serverInput, const QString &loginName,
                                          const QString &appPassword);
    Q_INVOKABLE void checkPantry();
    Q_INVOKABLE void signOut();

signals:
    void changed();
    void displayNameChanged();
    void waitingChanged();
    void pantryChanged();
    void loginUrlReady(const QString &url);
    void loginFailed(const QString &message);
    void signedInNow();
    void signedOut();

private:
    void poll();
    void finishLogin(const QString &server, const QString &loginName, const QString &appPassword);
    void setWaiting(bool waiting, bool starting);
    void setPantry(const QString &state, const QString &version);
    void publish();
    QString describe(QNetworkReply *reply) const;

    QNetworkAccessManager *m_nam;
    QTimer m_pollTimer;
    QDateTime m_deadline;

    QString m_server;
    QString m_loginName;
    QString m_appPassword;
    QString m_displayName;

    bool m_waiting = false;
    bool m_starting = false;
    QString m_loginUrl;
    QString m_pollEndpoint;
    QString m_pollToken;
    QNetworkReply *m_pollReply = nullptr;
    int m_flowId = 0;

    QString m_pantryState = QStringLiteral("unknown");
    QString m_pantryVersion;
};

#endif
