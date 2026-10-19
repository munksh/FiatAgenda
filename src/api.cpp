#include "api.h"

#include "credentials.h"

#include <QBuffer>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QJSEngine>
#include <QJSValueIterator>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMimeDatabase>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>

namespace {

const char *API_BASE = "/ocs/v2.php/apps/pantry/api";
const int REQUEST_TIMEOUT_MS = 20000;
const int UPLOAD_TIMEOUT_MS = 180000;

QNetworkRequest requestFor(const QString &url)
{
    const Credentials c = Credentials::current();
    QNetworkRequest r{QUrl(url)};
    r.setRawHeader("User-Agent", Credentials::userAgent());
    r.setRawHeader("Authorization", c.basicAuth());
    r.setRawHeader("OCS-APIRequest", "true");
    r.setRawHeader("Accept", "application/json");
    return r;
}

}

Api::Api(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
}

QString Api::urlFor(const QString &path, const QJSValue &query) const
{
    QUrl url(Credentials::current().server + QLatin1String(API_BASE) + path);
    if (query.isObject()) {
        QUrlQuery q;
        QJSValueIterator it(query);
        while (it.hasNext()) {
            it.next();
            if (!it.value().isUndefined() && !it.value().isNull())
                q.addQueryItem(it.name(), it.value().toString());
        }
        url.setQuery(q);
    }
    return url.toString(QUrl::FullyEncoded);
}

QString Api::imageUrl(const QString &path, const QJSValue &query) const
{
    if (!Credentials::current().isValid())
        return QString();
    return urlFor(path, query);
}

QString Api::cacheFile(const QString &url) const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/api");
    const QByteArray key = QCryptographicHash::hash(url.toUtf8(), QCryptographicHash::Sha1).toHex();
    return dir + QLatin1Char('/') + QString::fromLatin1(key) + QStringLiteral(".json");
}

QJSValue Api::cached(const QString &path, const QJSValue &query) const
{
    if (!m_engine || !Credentials::current().isValid())
        return QJSValue(QJSValue::UndefinedValue);
    QFile f(cacheFile(urlFor(path, query)));
    if (!f.open(QIODevice::ReadOnly))
        return QJSValue(QJSValue::UndefinedValue);
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (doc.isNull())
        return QJSValue(QJSValue::UndefinedValue);
    return m_engine->toScriptValue(doc.toVariant());
}

void Api::clearCache()
{
    QDir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/api")).removeRecursively();
}

void Api::get(const QString &path, const QJSValue &query, const QJSValue &callback)
{
    if (!Credentials::current().isValid())
        return;
    const QString url = urlFor(path, query);
    QNetworkReply *reply = m_nam->get(requestFor(url));
    m_cacheKeys.insert(reply, url);
    track(reply, callback, true, REQUEST_TIMEOUT_MS);
}

void Api::send(const QString &method, const QString &path, const QJSValue &body, const QJSValue &callback)
{
    if (!Credentials::current().isValid())
        return;
    QNetworkRequest request = requestFor(urlFor(path, QJSValue()));
    const QByteArray verb = method.toUpper().toLatin1();

    QByteArray data;
    if (!body.isUndefined() && !body.isNull()) {
        data = QJsonDocument::fromVariant(body.toVariant()).toJson(QJsonDocument::Compact);
        request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json; charset=utf-8"));
    }

    QNetworkReply *reply = nullptr;
    if (verb == "GET") {
        reply = m_nam->get(request);
    } else if (verb == "POST") {
        reply = m_nam->post(request, data);
    } else if (verb == "PUT") {
        reply = m_nam->put(request, data);
    } else if (verb == "DELETE" && data.isEmpty()) {
        reply = m_nam->deleteResource(request);
    } else {
        // PATCH, or DELETE with a body. Qt 5.6 takes the body only as a device.
        QBuffer *buffer = new QBuffer;
        buffer->setData(data);
        buffer->open(QIODevice::ReadOnly);
        reply = m_nam->sendCustomRequest(request, verb, buffer);
        buffer->setParent(reply);
    }
    track(reply, callback, false, REQUEST_TIMEOUT_MS);
}

void Api::upload(const QString &path, const QString &fileUrl, const QJSValue &fields, const QJSValue &callback)
{
    if (!Credentials::current().isValid())
        return;

    const QUrl source(fileUrl);
    const QString local = source.isLocalFile() ? source.toLocalFile() : fileUrl;
    QFile *file = new QFile(local);
    if (!file->open(QIODevice::ReadOnly)) {
        delete file;
        setError(tr("The picture could not be read."));
        if (callback.isCallable() && m_engine)
            QJSValue(callback).call(QJSValueList() << false << QJSValue(QJSValue::NullValue) << 0
                                    << tr("The picture could not be read."));
        return;
    }

    QHttpMultiPart *multi = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    if (fields.isObject()) {
        QJSValueIterator it(fields);
        while (it.hasNext()) {
            it.next();
            if (it.value().isUndefined() || it.value().isNull())
                continue;
            QHttpPart part;
            part.setHeader(QNetworkRequest::ContentDispositionHeader,
                           QStringLiteral("form-data; name=\"%1\"").arg(it.name()));
            part.setBody(it.value().toString().toUtf8());
            multi->append(part);
        }
    }

    const QString name = QFileInfo(local).fileName();
    QHttpPart image;
    image.setHeader(QNetworkRequest::ContentTypeHeader, QMimeDatabase().mimeTypeForFile(local).name());
    image.setHeader(QNetworkRequest::ContentDispositionHeader,
                    QStringLiteral("form-data; name=\"image\"; filename=\"%1\"").arg(name));
    image.setBodyDevice(file);
    file->setParent(multi);
    multi->append(image);

    QNetworkReply *reply = m_nam->post(requestFor(urlFor(path, QJSValue())), multi);
    multi->setParent(reply);
    track(reply, callback, false, UPLOAD_TIMEOUT_MS);
}

void Api::track(QNetworkReply *reply, const QJSValue &callback, bool cacheIt, int timeoutMs)
{
    if (!cacheIt)
        m_cacheKeys.remove(reply);
    m_callbacks.insert(reply, callback);
    setBusy(m_busy + 1);
    QTimer::singleShot(timeoutMs, reply, [reply]() {
        if (reply->isRunning())
            reply->abort();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply]() { finished(reply); });
}

void Api::finished(QNetworkReply *reply)
{
    reply->deleteLater();
    setBusy(qMax(0, m_busy - 1));
    QJSValue callback = m_callbacks.take(reply);
    const QString cacheKey = m_cacheKeys.take(reply);

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray body = reply->readAll();
    const bool reached = status > 0;
    const bool ok = reply->error() == QNetworkReply::NoError && status >= 200 && status < 300;

    setOffline(!reached);

    const QJsonObject root = QJsonDocument::fromJson(body).object();
    const QJsonObject ocs = root.value(QStringLiteral("ocs")).toObject();
    QJsonValue data = ocs.contains(QStringLiteral("data")) ? ocs.value(QStringLiteral("data"))
                                                           : QJsonValue(root);
    QString message = ocs.value(QStringLiteral("meta")).toObject().value(QStringLiteral("message")).toString();

    if (ok) {
        if (!cacheKey.isEmpty()) {
            const QString path = cacheFile(cacheKey);
            QDir().mkpath(QFileInfo(path).absolutePath());
            QSaveFile f(path);
            if (f.open(QIODevice::WriteOnly)) {
                QJsonDocument doc = data.isArray() ? QJsonDocument(data.toArray()) : QJsonDocument(data.toObject());
                f.write(doc.toJson(QJsonDocument::Compact));
                f.commit();
            }
        }
    } else {
        if (status == 401) {
            message = tr("The server no longer accepts this sign-in.");
            emit unauthorized();
        } else if (status == 403 && message.isEmpty()) {
            message = tr("Your role in this household does not allow that.");
        } else if (!reached) {
            message = tr("No connection to the server.");
        } else if (message.isEmpty() || message == QLatin1String("OK")) {
            message = tr("The server said no (%1).").arg(status);
        }
        // Being offline is shown on its own; it is not an error worth a banner
        // for every refresh that could not happen.
        if (reached)
            setError(message);
    }

    if (callback.isCallable() && m_engine) {
        QJSValue result = m_engine->toScriptValue(data.toVariant());
        QJSValue answer = callback.call(QJSValueList() << ok << result << status << message);
        if (answer.isError())
            qWarning("fiat agenda: callback failed: %s", qPrintable(answer.toString()));
    }
}

void Api::setError(const QString &error)
{
    if (m_error == error)
        return;
    m_error = error;
    emit errorChanged();
}

void Api::dismissError()
{
    setError(QString());
}

void Api::setOffline(bool offline)
{
    if (m_offline == offline)
        return;
    m_offline = offline;
    emit offlineChanged();
}

void Api::setBusy(int busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}
