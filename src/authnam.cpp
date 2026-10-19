#include "authnam.h"

#include "credentials.h"

#include <QNetworkRequest>

AuthNam::AuthNam(QObject *parent)
    : QNetworkAccessManager(parent)
{
}

QNetworkReply *AuthNam::createRequest(Operation op, const QNetworkRequest &request, QIODevice *outgoingData)
{
    const Credentials c = Credentials::current();
    if (!c.isValid())
        return QNetworkAccessManager::createRequest(op, request, outgoingData);

    const QString url = request.url().toString();
    if (!url.startsWith(c.server + QLatin1Char('/')))
        return QNetworkAccessManager::createRequest(op, request, outgoingData);

    QNetworkRequest r(request);
    r.setRawHeader("Authorization", c.basicAuth());
    r.setRawHeader("OCS-APIRequest", "true");
    r.setRawHeader("User-Agent", Credentials::userAgent());
    return QNetworkAccessManager::createRequest(op, r, outgoingData);
}

QNetworkAccessManager *AuthNamFactory::create(QObject *parent)
{
    return new AuthNam(parent);
}
