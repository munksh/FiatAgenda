#include "dav.h"

#include "credentials.h"

#include <QBuffer>
#include <QJSEngine>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QStringList>
#include <QTimer>
#include <QUrl>
#include <QUuid>
#include <QVariantList>
#include <QVariantMap>
#include <QXmlStreamReader>

#include <functional>

namespace {

const int TIMEOUT_MS = 30000;

struct Entry
{
    QString href;
    QHash<QString, QString> props;
    bool calendar = false;
    bool hasComps = false;
    QStringList comps;
};

// A WebDAV multistatus, reduced to what this client asks for. Only properties
// from a propstat answered "200" are kept.
QList<Entry> parseMultistatus(const QByteArray &xml)
{
    QList<Entry> out;
    QXmlStreamReader r(xml);
    QStringList stack;
    QString text;

    Entry cur;
    QHash<QString, QString> props;
    bool calendar = false;
    bool hasComps = false;
    QStringList comps;
    QString status;

    while (!r.atEnd()) {
        r.readNext();
        if (r.isStartElement()) {
            const QString n = r.name().toString();
            if (n == QLatin1String("response")) {
                cur = Entry();
            } else if (n == QLatin1String("propstat")) {
                props.clear();
                calendar = false;
                hasComps = false;
                comps.clear();
                status.clear();
            } else if (n == QLatin1String("calendar") && stack.contains(QStringLiteral("resourcetype"))) {
                calendar = true;
            } else if (n == QLatin1String("supported-calendar-component-set")) {
                hasComps = true;
            } else if (n == QLatin1String("comp") && stack.contains(QStringLiteral("supported-calendar-component-set"))) {
                comps << r.attributes().value(QStringLiteral("name")).toString().toUpper();
            }
            stack << n;
            text.clear();
        } else if (r.isCharacters()) {
            text += r.text();
        } else if (r.isEndElement()) {
            const QString n = stack.isEmpty() ? QString() : stack.takeLast();
            const QString parent = stack.isEmpty() ? QString() : stack.last();
            if (n == QLatin1String("href")) {
                if (parent == QLatin1String("response"))
                    cur.href = QUrl::fromPercentEncoding(text.trimmed().toUtf8());
                else if (parent == QLatin1String("current-user-principal") || parent == QLatin1String("calendar-home-set"))
                    props.insert(parent, QUrl::fromPercentEncoding(text.trimmed().toUtf8()));
            } else if (n == QLatin1String("status") && parent == QLatin1String("propstat")) {
                status = text;
            } else if (parent == QLatin1String("prop")) {
                if (!props.contains(n))
                    props.insert(n, text);
            } else if (n == QLatin1String("propstat")) {
                if (status.contains(QLatin1String(" 200"))) {
                    for (auto it = props.constBegin(); it != props.constEnd(); ++it)
                        cur.props.insert(it.key(), it.value());
                    cur.calendar = cur.calendar || calendar;
                    cur.hasComps = cur.hasComps || hasComps;
                    cur.comps << comps;
                }
            } else if (n == QLatin1String("response")) {
                out << cur;
            }
            text.clear();
        }
    }
    return out;
}

QString xmlEscape(const QString &s)
{
    QString o = s;
    o.replace(QLatin1Char('&'), QLatin1String("&amp;"));
    o.replace(QLatin1Char('<'), QLatin1String("&lt;"));
    o.replace(QLatin1Char('>'), QLatin1String("&gt;"));
    return o;
}

// "#RRGGBB" or "#RRGGBBAA" as servers store it, always handed on as #RRGGBB.
QString shortColour(const QString &c)
{
    const QString t = c.trimmed();
    return (t.startsWith(QLatin1Char('#')) && t.length() >= 7) ? t.left(7) : QString();
}

}

Dav::Dav(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
}

QString Dav::origin() const
{
    const QUrl u(Credentials::current().server);
    QString o = u.scheme() + QStringLiteral("://") + u.host();
    if (u.port() > 0)
        o += QLatin1Char(':') + QString::number(u.port());
    return o;
}

QString Dav::newUid() const
{
    QString id = QUuid::createUuid().toString();
    return id.mid(1, id.length() - 2);
}

void Dav::setBusy(int delta)
{
    const bool before = busy();
    m_busy = qMax(0, m_busy + delta);
    if (before != busy())
        emit busyChanged();
}

QNetworkReply *Dav::send(const QByteArray &verb, const QString &url, const QByteArray &body,
                         const QByteArray &depth, const QList<QPair<QByteArray, QByteArray>> &headers)
{
    const Credentials c = Credentials::current();
    QNetworkRequest r{QUrl(url)};
    r.setRawHeader("User-Agent", Credentials::userAgent());
    r.setRawHeader("Authorization", c.basicAuth());
    if (!depth.isEmpty())
        r.setRawHeader("Depth", depth);
    if (!body.isEmpty() && verb != "PUT")
        r.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/xml; charset=utf-8"));
    for (const auto &h : headers)
        r.setRawHeader(h.first, h.second);

    QBuffer *buffer = new QBuffer;
    buffer->setData(body);
    buffer->open(QIODevice::ReadOnly);
    QNetworkReply *reply = m_nam->sendCustomRequest(r, verb, buffer);
    buffer->setParent(reply);
    QTimer::singleShot(TIMEOUT_MS, reply, [reply]() {
        if (reply->isRunning())
            reply->abort();
    });
    setBusy(+1);
    return reply;
}

void Dav::step(QNetworkReply *reply, std::function<void(QNetworkReply *, int, const QByteArray &)> then)
{
    connect(reply, &QNetworkReply::finished, this, [this, reply, then]() {
        reply->deleteLater();
        setBusy(-1);
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status == 401)
            emit unauthorized();
        then(reply, status, reply->readAll());
    });
}

QString Dav::describe(QNetworkReply *reply, int status) const
{
    if (status == 0)
        return tr("No connection to the server.");
    if (status == 401)
        return tr("The server no longer accepts this sign-in.");
    if (status == 403)
        return tr("The server does not allow that.");
    if (status == 404)
        return tr("The server has no such list.");
    if (status == 412)
        return tr("It changed on the server in the meantime.");
    if (status == 507)
        return tr("The server is out of space.");
    return tr("The server said no (%1).").arg(status ? QString::number(status) : reply->errorString());
}

void Dav::answer(QJSValue callback, const QJSValueList &args)
{
    if (!callback.isCallable() || !m_engine)
        return;
    QJSValue result = callback.call(args);
    if (result.isError())
        qWarning("fiat agenda: callback failed: %s", qPrintable(result.toString()));
}

// ---- discovery ----

void Dav::discover(const QJSValue &callback)
{
    if (!Credentials::current().isValid()) {
        answer(callback, QJSValueList() << false << QJSValue() << tr("Not signed in."));
        return;
    }
    discoverAt(0, callback);
}

void Dav::discoverAt(int attempt, const QJSValue &callback)
{
    // Nextcloud keeps CalDAV under remote.php/dav; other servers answer at
    // their root.
    const QStringList roots = { QStringLiteral("/remote.php/dav/"), QStringLiteral("/") };
    if (attempt >= roots.size()) {
        answer(callback, QJSValueList() << false << QJSValue() << tr("The server offers no task lists."));
        return;
    }
    const QByteArray body =
            "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
            "<d:propfind xmlns:d=\"DAV:\"><d:prop><d:current-user-principal/></d:prop></d:propfind>";
    QNetworkReply *reply = send("PROPFIND", Credentials::current().server + roots.at(attempt), body, "0");
    step(reply, [this, attempt, callback](QNetworkReply *r, int status, const QByteArray &data) {
        if (status == 207) {
            for (const Entry &e : parseMultistatus(data)) {
                const QString principal = e.props.value(QStringLiteral("current-user-principal"));
                if (!principal.isEmpty()) {
                    readHome(principal, callback);
                    return;
                }
            }
        }
        if (status == 0 || status == 401) {
            answer(callback, QJSValueList() << false << QJSValue() << describe(r, status));
            return;
        }
        discoverAt(attempt + 1, callback);
    });
}

void Dav::readHome(const QString &principal, const QJSValue &callback)
{
    const QByteArray body =
            "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
            "<d:propfind xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:caldav\">"
            "<d:prop><c:calendar-home-set/></d:prop></d:propfind>";
    QNetworkReply *reply = send("PROPFIND", origin() + principal, body, "0");
    step(reply, [this, callback](QNetworkReply *r, int status, const QByteArray &data) {
        if (status == 207) {
            for (const Entry &e : parseMultistatus(data)) {
                const QString home = e.props.value(QStringLiteral("calendar-home-set"));
                if (!home.isEmpty()) {
                    m_home = home.endsWith(QLatin1Char('/')) ? home : home + QLatin1Char('/');
                    listHome(m_home, callback);
                    return;
                }
            }
        }
        answer(callback, QJSValueList() << false << QJSValue() << (status == 207 ? tr("The server offers no task lists.") : describe(r, status)));
    });
}

void Dav::listHome(const QString &home, const QJSValue &callback)
{
    const QByteArray body =
            "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
            "<d:propfind xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:caldav\" xmlns:a=\"http://apple.com/ns/ical/\">"
            "<d:prop><d:displayname/><d:resourcetype/><c:supported-calendar-component-set/><a:calendar-color/></d:prop>"
            "</d:propfind>";
    QNetworkReply *reply = send("PROPFIND", origin() + home, body, "1");
    step(reply, [this, home, callback](QNetworkReply *r, int status, const QByteArray &data) {
        if (status != 207) {
            answer(callback, QJSValueList() << false << QJSValue() << describe(r, status));
            return;
        }
        QVariantList lists;
        for (const Entry &e : parseMultistatus(data)) {
            if (!e.calendar || e.href == home)
                continue;
            if (e.hasComps && !e.comps.contains(QStringLiteral("VTODO")))
                continue;
            QVariantMap m;
            m.insert(QStringLiteral("href"), e.href);
            QString name = e.props.value(QStringLiteral("displayname")).trimmed();
            if (name.isEmpty()) {
                QString h = e.href;
                if (h.endsWith(QLatin1Char('/')))
                    h.chop(1);
                name = h.mid(h.lastIndexOf(QLatin1Char('/')) + 1);
            }
            m.insert(QStringLiteral("name"), name);
            m.insert(QStringLiteral("color"), shortColour(e.props.value(QStringLiteral("calendar-color"))));
            lists << m;
        }
        answer(callback, QJSValueList() << true << m_engine->toScriptValue(lists) << QString());
    });
}

// ---- tasks ----

void Dav::fetch(const QString &href, const QJSValue &callback)
{
    const QByteArray body =
            "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
            "<c:calendar-query xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:caldav\">"
            "<d:prop><d:getetag/><c:calendar-data/></d:prop>"
            "<c:filter><c:comp-filter name=\"VCALENDAR\"><c:comp-filter name=\"VTODO\"/></c:comp-filter></c:filter>"
            "</c:calendar-query>";
    QNetworkReply *reply = send("REPORT", origin() + href, body, "1");
    step(reply, [this, callback](QNetworkReply *r, int status, const QByteArray &data) {
        if (status != 207) {
            answer(callback, QJSValueList() << false << QJSValue() << status << describe(r, status));
            return;
        }
        QVariantList items;
        for (const Entry &e : parseMultistatus(data)) {
            const QString ics = e.props.value(QStringLiteral("calendar-data"));
            if (ics.isEmpty())
                continue;
            QVariantMap m;
            m.insert(QStringLiteral("href"), e.href);
            m.insert(QStringLiteral("etag"), e.props.value(QStringLiteral("getetag")));
            m.insert(QStringLiteral("ics"), ics);
            items << m;
        }
        answer(callback, QJSValueList() << true << m_engine->toScriptValue(items) << status << QString());
    });
}

void Dav::put(const QString &href, const QString &ics, const QString &etag, const QJSValue &callback)
{
    QList<QPair<QByteArray, QByteArray>> headers;
    headers << qMakePair(QByteArray("Content-Type"), QByteArray("text/calendar; charset=utf-8"));
    if (etag.isEmpty())
        headers << qMakePair(QByteArray("If-None-Match"), QByteArray("*"));
    else
        headers << qMakePair(QByteArray("If-Match"), etag.toUtf8());
    QNetworkReply *reply = send("PUT", origin() + href, ics.toUtf8(), QByteArray(), headers);
    step(reply, [this, callback](QNetworkReply *r, int status, const QByteArray &) {
        const bool ok = status >= 200 && status < 300;
        const QString newEtag = QString::fromUtf8(r->rawHeader("ETag"));
        answer(callback, QJSValueList() << ok << status << newEtag << (ok ? QString() : describe(r, status)));
    });
}

void Dav::remove(const QString &href, const QString &etag, const QJSValue &callback)
{
    QList<QPair<QByteArray, QByteArray>> headers;
    if (!etag.isEmpty())
        headers << qMakePair(QByteArray("If-Match"), etag.toUtf8());
    QNetworkReply *reply = send("DELETE", origin() + href, QByteArray(), QByteArray(), headers);
    step(reply, [this, callback](QNetworkReply *r, int status, const QByteArray &) {
        const bool ok = (status >= 200 && status < 300) || status == 404;
        answer(callback, QJSValueList() << ok << status << (ok ? QString() : describe(r, status)));
    });
}

void Dav::makeList(const QString &name, const QString &color, const QJSValue &callback)
{
    if (m_home.isEmpty()) {
        answer(callback, QJSValueList() << false << QString() << tr("Look up the lists on the server first."));
        return;
    }
    QString slug;
    for (const QChar ch : name.toLower()) {
        if ((ch >= QLatin1Char('a') && ch <= QLatin1Char('z')) || (ch >= QLatin1Char('0') && ch <= QLatin1Char('9')))
            slug += ch;
        else if (!slug.endsWith(QLatin1Char('-')))
            slug += QLatin1Char('-');
    }
    slug = slug.left(32);
    while (slug.endsWith(QLatin1Char('-')))
        slug.chop(1);
    slug += QLatin1Char('-') + newUid().left(8);
    const QString href = m_home + slug + QLatin1Char('/');

    QByteArray body =
            "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
            "<c:mkcalendar xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:caldav\" xmlns:a=\"http://apple.com/ns/ical/\">"
            "<d:set><d:prop><d:displayname>" + xmlEscape(name).toUtf8() + "</d:displayname>"
            "<c:supported-calendar-component-set><c:comp name=\"VTODO\"/></c:supported-calendar-component-set>";
    if (!color.isEmpty())
        body += "<a:calendar-color>" + xmlEscape(color).toUtf8() + "</a:calendar-color>";
    body += "</d:prop></d:set></c:mkcalendar>";

    QNetworkReply *reply = send("MKCALENDAR", origin() + href, body, QByteArray());
    step(reply, [this, href, callback](QNetworkReply *r, int status, const QByteArray &) {
        const bool ok = status == 201 || status == 200;
        answer(callback, QJSValueList() << ok << (ok ? href : QString()) << (ok ? QString() : describe(r, status)));
    });
}
