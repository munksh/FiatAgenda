#include "files.h"

#include <QDir>
#include <QFileInfo>
#include <QSaveFile>
#include <QStandardPaths>

Files::Files(QObject *parent)
    : QObject(parent)
{
}

QString Files::saveDocument(const QString &name, const QString &text) const
{
    // A bare file name only: nothing may climb out of Documents.
    if (name.isEmpty() || name.contains(QLatin1Char('/')) || name.startsWith(QLatin1Char('.')))
        return QString();

    const QString dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (dir.isEmpty() || !QDir().mkpath(dir))
        return QString();

    const QString path = dir + QLatin1Char('/') + name;
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return QString();
    const QByteArray bytes = text.toUtf8();
    if (file.write(bytes) != bytes.size() || !file.commit())
        return QString();
    return QFileInfo(path).absoluteFilePath();
}
