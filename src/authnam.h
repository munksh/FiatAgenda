#ifndef AUTHNAM_H
#define AUTHNAM_H

#include <QNetworkAccessManager>
#include <QQmlNetworkAccessManagerFactory>

// Photos and item pictures are behind the login. An Image element cannot send
// headers, so the engine's own network access adds them for the account's
// server, and only for that server.
class AuthNam : public QNetworkAccessManager
{
    Q_OBJECT
public:
    explicit AuthNam(QObject *parent = nullptr);

protected:
    QNetworkReply *createRequest(Operation op, const QNetworkRequest &request,
                                 QIODevice *outgoingData = nullptr) override;
};

class AuthNamFactory : public QQmlNetworkAccessManagerFactory
{
public:
    QNetworkAccessManager *create(QObject *parent) override;
};

#endif
