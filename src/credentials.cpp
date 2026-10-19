#include "credentials.h"

#include <QReadLocker>
#include <QReadWriteLock>
#include <QWriteLocker>

namespace {
QReadWriteLock lock;
Credentials shared;
}

bool Credentials::isValid() const
{
    return !server.isEmpty() && !loginName.isEmpty() && !appPassword.isEmpty();
}

QByteArray Credentials::basicAuth() const
{
    return "Basic " + (loginName + QLatin1Char(':') + appPassword).toUtf8().toBase64();
}

Credentials Credentials::current()
{
    QReadLocker locker(&lock);
    return shared;
}

void Credentials::setCurrent(const Credentials &credentials)
{
    QWriteLocker locker(&lock);
    shared = credentials;
}

QByteArray Credentials::userAgent()
{
    return QByteArrayLiteral("fiat agenda (Sailfish OS)");
}
