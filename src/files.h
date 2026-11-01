#ifndef FILES_H
#define FILES_H

#include <QObject>
#include <QString>

// Writes the one file the app hands over to another: the lists Agenda 2.0
// kept, saved in Documents for fiat penus to bring in. QML cannot write a
// file by itself.
class Files : public QObject
{
    Q_OBJECT

public:
    explicit Files(QObject *parent = nullptr);

    // Saves text as Documents/<name> and returns the full path, or "" when it
    // could not be written. An older file of the same name is replaced.
    Q_INVOKABLE QString saveDocument(const QString &name, const QString &text) const;
};

#endif
