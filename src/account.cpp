#include "account.h"

#include "credentials.h"

#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSettings>
#include <QStandardPaths>
#include <QStringList>
#include <QUrl>
#include <QUrlQuery>

namespace {

const int REQUEST_TIMEOUT_MS = 20000;
const int POLL_INTERVAL_MS = 2000;
const int FLOW_MINUTES = 20;    // Nextcloud keeps a login flow token this long

void armTimeout(QNetworkReply *reply, int ms)
{
    QTimer::singleShot(ms, reply, [reply]() {
        if (reply->isRunning())
            reply->abort();
    });
}

int statusOf(QNetworkReply *reply)
{
    return reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
}

// Inside ~/.config/<organisation>/<application>/, the one config folder
// Sailjail leaves writable. The default QSettings file sits beside that folder
// and would not survive inside the sandbox.
QString settingsFile()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/account.conf");
}

QJsonObject ocsData(const QByteArray &body)
{
    return QJsonDocument::fromJson(body).object().value(QStringLiteral("ocs")).toObject()
            .value(QStringLiteral("data")).toObject();
}

}

Account::Account(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
    QSettings s(settingsFile(), QSettings::IniFormat);
    m_server = s.value(QStringLiteral("account/server")).toString();
    m_loginName = s.value(QStringLiteral("account/loginName")).toString();
    m_appPassword = s.value(QStringLiteral("account/appPassword")).toString();
    m_displayName = s.value(QStringLiteral("account/displayName")).toString();
    publish();

    m_pollTimer.setSingleShot(true);
    m_pollTimer.setInterval(POLL_INTERVAL_MS);
    connect(&m_pollTimer, &QTimer::timeout, this, &Account::poll);
}

bool Account::signedIn() const
{
    return !m_server.isEmpty() && !m_loginName.isEmpty() && !m_appPassword.isEmpty();
}

QString Account::normaliseServer(const QString &input) const
{
    QString s = input.trimmed();
    if (s.isEmpty())
        return s;
    if (!s.contains(QStringLiteral("://")))
        s.prepend(QStringLiteral("https://"));

    // People paste whatever the browser shows: cut the page part away.
    const QStringList cuts = { QStringLiteral("/index.php"), QStringLiteral("/apps/"),
                               QStringLiteral("/login"), QStringLiteral("/ocs/") };
    for (const QString &cut : cuts) {
        const int at = s.indexOf(cut, s.indexOf(QStringLiteral("://")) + 3);
        if (at > 0)
            s.truncate(at);
    }
    while (s.endsWith(QLatin1Char('/')))
        s.chop(1);
    return s;
}

QString Account::describe(QNetworkReply *reply) const
{
    switch (reply->error()) {
    case QNetworkReply::HostNotFoundError:
        return tr("No server answers at that address.");
    case QNetworkReply::SslHandshakeFailedError:
        return tr("The phone does not trust the server's certificate.");
    case QNetworkReply::OperationCanceledError:
    case QNetworkReply::TimeoutError:
        return tr("The server did not answer in time.");
    case QNetworkReply::ConnectionRefusedError:
    case QNetworkReply::RemoteHostClosedError:
    case QNetworkReply::NetworkSessionFailedError:
    case QNetworkReply::TemporaryNetworkFailureError:
    case QNetworkReply::UnknownNetworkError:
        return tr("The server cannot be reached right now.");
    default:
        break;
    }
    const int status = statusOf(reply);
    if (status == 404)
        return tr("There is no Nextcloud at that address.");
    if (status >= 300 && status < 400) {
        const QString to = QString::fromUtf8(reply->rawHeader("Location"));
        return to.isEmpty() ? tr("The server sends this address elsewhere.")
                            : tr("The server sends this address on to %1. Try that one.").arg(to);
    }
    return reply->errorString();
}

void Account::setWaiting(bool waiting, bool starting)
{
    if (m_waiting == waiting && m_starting == starting)
        return;
    m_waiting = waiting;
    m_starting = starting;
    emit waitingChanged();
}

void Account::setPantry(const QString &state, const QString &version)
{
    if (m_pantryState == state && m_pantryVersion == version)
        return;
    m_pantryState = state;
    m_pantryVersion = version;
    emit pantryChanged();
}

void Account::publish()
{
    Credentials c;
    if (signedIn()) {
        c.server = m_server;
        c.loginName = m_loginName;
        c.appPassword = m_appPassword;
    }
    Credentials::setCurrent(c);
}

void Account::startLogin(const QString &serverInput)
{
    cancelLogin();
    const QString server = normaliseServer(serverInput);
    if (server.isEmpty()) {
        emit loginFailed(tr("Write the address of your Nextcloud first."));
        return;
    }

    const int flow = ++m_flowId;
    setWaiting(false, true);

    QNetworkRequest request(QUrl(server + QStringLiteral("/index.php/login/v2")));
    request.setRawHeader("User-Agent", Credentials::userAgent());
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/x-www-form-urlencoded"));
    QNetworkReply *reply = m_nam->post(request, QByteArray());
    armTimeout(reply, REQUEST_TIMEOUT_MS);

    connect(reply, &QNetworkReply::finished, this, [this, reply, flow]() {
        reply->deleteLater();
        if (flow != m_flowId)
            return;
        const int status = statusOf(reply);
        if (reply->error() != QNetworkReply::NoError || status != 200) {
            setWaiting(false, false);
            emit loginFailed(describe(reply));
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(reply->readAll()).object();
        const QJsonObject p = o.value(QStringLiteral("poll")).toObject();
        m_loginUrl = o.value(QStringLiteral("login")).toString();
        m_pollEndpoint = p.value(QStringLiteral("endpoint")).toString();
        m_pollToken = p.value(QStringLiteral("token")).toString();
        if (m_loginUrl.isEmpty() || m_pollEndpoint.isEmpty() || m_pollToken.isEmpty()) {
            setWaiting(false, false);
            emit loginFailed(tr("The server answered, but not like a Nextcloud."));
            return;
        }
        m_deadline = QDateTime::currentDateTimeUtc().addSecs(FLOW_MINUTES * 60);
        setWaiting(true, false);
        emit loginUrlReady(m_loginUrl);
        m_pollTimer.start();
    });
}

void Account::cancelLogin()
{
    ++m_flowId;
    m_pollTimer.stop();
    if (m_pollReply) {
        m_pollReply->abort();
        m_pollReply = nullptr;
    }
    m_loginUrl.clear();
    m_pollEndpoint.clear();
    m_pollToken.clear();
    setWaiting(false, false);
}

void Account::poll()
{
    if (!m_waiting)
        return;
    if (QDateTime::currentDateTimeUtc() > m_deadline) {
        cancelLogin();
        emit loginFailed(tr("The sign-in took too long. Start again."));
        return;
    }

    const int flow = m_flowId;
    QNetworkRequest request{QUrl(m_pollEndpoint)};
    request.setRawHeader("User-Agent", Credentials::userAgent());
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/x-www-form-urlencoded"));
    QUrlQuery form;
    form.addQueryItem(QStringLiteral("token"), m_pollToken);
    m_pollReply = m_nam->post(request, form.toString(QUrl::FullyEncoded).toUtf8());
    QNetworkReply *reply = m_pollReply;
    armTimeout(reply, REQUEST_TIMEOUT_MS);

    connect(reply, &QNetworkReply::finished, this, [this, reply, flow]() {
        reply->deleteLater();
        if (m_pollReply == reply)
            m_pollReply = nullptr;
        if (flow != m_flowId)
            return;
        if (reply->error() == QNetworkReply::NoError && statusOf(reply) == 200) {
            const QJsonObject o = QJsonDocument::fromJson(reply->readAll()).object();
            const QString server = o.value(QStringLiteral("server")).toString();
            const QString name = o.value(QStringLiteral("loginName")).toString();
            const QString password = o.value(QStringLiteral("appPassword")).toString();
            if (!server.isEmpty() && !name.isEmpty() && !password.isEmpty()) {
                cancelLogin();
                finishLogin(normaliseServer(server), name, password);
                return;
            }
        }
        // 404 means "not approved yet"; anything else is worth another try
        // until the token runs out.
        m_pollTimer.start();
    });
}

void Account::loginWithAppPassword(const QString &serverInput, const QString &loginName,
                                   const QString &appPassword)
{
    cancelLogin();
    const QString server = normaliseServer(serverInput);
    const QString name = loginName.trimmed();
    const QString password = appPassword.trimmed();
    if (server.isEmpty() || name.isEmpty() || password.isEmpty()) {
        emit loginFailed(tr("Server, name and app password are all needed."));
        return;
    }

    const int flow = ++m_flowId;
    setWaiting(false, true);

    Credentials c;
    c.server = server;
    c.loginName = name;
    c.appPassword = password;

    QNetworkRequest request(QUrl(server + QStringLiteral("/ocs/v2.php/cloud/user?format=json")));
    request.setRawHeader("User-Agent", Credentials::userAgent());
    request.setRawHeader("Authorization", c.basicAuth());
    request.setRawHeader("OCS-APIRequest", "true");
    request.setRawHeader("Accept", "application/json");
    QNetworkReply *reply = m_nam->get(request);
    armTimeout(reply, REQUEST_TIMEOUT_MS);

    connect(reply, &QNetworkReply::finished, this, [this, reply, flow, server, name, password]() {
        reply->deleteLater();
        if (flow != m_flowId)
            return;
        setWaiting(false, false);
        const int status = statusOf(reply);
        if (status == 401) {
            emit loginFailed(tr("The name or the app password is wrong."));
            return;
        }
        if (reply->error() != QNetworkReply::NoError || status != 200) {
            emit loginFailed(describe(reply));
            return;
        }
        finishLogin(server, name, password);
    });
}

void Account::finishLogin(const QString &server, const QString &loginName, const QString &appPassword)
{
    m_server = server;
    m_loginName = loginName;
    m_appPassword = appPassword;
    m_displayName.clear();

    QSettings s(settingsFile(), QSettings::IniFormat);
    s.setValue(QStringLiteral("account/server"), m_server);
    s.setValue(QStringLiteral("account/loginName"), m_loginName);
    s.setValue(QStringLiteral("account/appPassword"), m_appPassword);
    s.remove(QStringLiteral("account/displayName"));
    s.sync();

    publish();
    setPantry(QStringLiteral("unknown"), QString());
    emit changed();
    emit displayNameChanged();
    emit signedInNow();
}

void Account::checkPantry()
{
    if (!signedIn())
        return;
    setPantry(QStringLiteral("checking"), m_pantryVersion);

    const Credentials c = Credentials::current();
    auto request = [&c](const QString &path) {
        QNetworkRequest r(QUrl(c.server + path));
        r.setRawHeader("User-Agent", Credentials::userAgent());
        r.setRawHeader("Authorization", c.basicAuth());
        r.setRawHeader("OCS-APIRequest", "true");
        r.setRawHeader("Accept", "application/json");
        return r;
    };

    QNetworkReply *caps = m_nam->get(request(QStringLiteral("/ocs/v2.php/cloud/capabilities?format=json")));
    armTimeout(caps, REQUEST_TIMEOUT_MS);
    connect(caps, &QNetworkReply::finished, this, [this, caps]() {
        caps->deleteLater();
        const int status = statusOf(caps);
        if (status == 401) {
            setPantry(QStringLiteral("unauthorized"), QString());
            return;
        }
        if (caps->error() != QNetworkReply::NoError || status != 200) {
            setPantry(QStringLiteral("unreachable"), m_pantryVersion);
            return;
        }
        const QJsonObject pantry = ocsData(caps->readAll()).value(QStringLiteral("capabilities")).toObject()
                .value(QStringLiteral("pantry")).toObject();
        if (pantry.isEmpty()) {
            setPantry(QStringLiteral("missing"), QString());
            return;
        }
        setPantry(QStringLiteral("present"),
                  pantry.value(QStringLiteral("version")).toObject().value(QStringLiteral("string")).toString());
    });

    QNetworkReply *user = m_nam->get(request(QStringLiteral("/ocs/v2.php/cloud/user?format=json")));
    armTimeout(user, REQUEST_TIMEOUT_MS);
    connect(user, &QNetworkReply::finished, this, [this, user]() {
        user->deleteLater();
        if (user->error() != QNetworkReply::NoError || statusOf(user) != 200)
            return;
        const QString shown = ocsData(user->readAll()).value(QStringLiteral("displayname")).toString();
        if (shown.isEmpty() || shown == m_displayName)
            return;
        m_displayName = shown;
        QSettings(settingsFile(), QSettings::IniFormat).setValue(QStringLiteral("account/displayName"), m_displayName);
        emit displayNameChanged();
    });
}

void Account::signOut()
{
    cancelLogin();
    if (signedIn()) {
        // Revoke the app password on the server, so it stops working there too.
        const Credentials c = Credentials::current();
        QNetworkRequest r(QUrl(c.server + QStringLiteral("/ocs/v2.php/core/apppassword")));
        r.setRawHeader("User-Agent", Credentials::userAgent());
        r.setRawHeader("Authorization", c.basicAuth());
        r.setRawHeader("OCS-APIRequest", "true");
        QNetworkReply *reply = m_nam->deleteResource(r);
        armTimeout(reply, REQUEST_TIMEOUT_MS);
        connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
    }

    m_server.clear();
    m_loginName.clear();
    m_appPassword.clear();
    m_displayName.clear();
    QSettings s(settingsFile(), QSettings::IniFormat);
    s.remove(QStringLiteral("account"));
    s.sync();

    publish();
    setPantry(QStringLiteral("unknown"), QString());
    emit changed();
    emit displayNameChanged();
    emit signedOut();
}
