#ifndef CREDENTIALS_H
#define CREDENTIALS_H

#include <QByteArray>
#include <QString>

// The signed-in account, readable from any thread. The image loader runs its
// own network access managers on threads of its own, and they need the same
// login the API calls use.
struct Credentials
{
    QString server;
    QString loginName;
    QString appPassword;

    bool isValid() const;
    QByteArray basicAuth() const;

    static Credentials current();
    static void setCurrent(const Credentials &credentials);

    // Nextcloud names the app password after this, under Settings → Security.
    static QByteArray userAgent();
};

#endif
