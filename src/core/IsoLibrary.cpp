#include "IsoLibrary.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QUuid>

IsoLibrary::IsoLibrary(QObject* parent) : QObject(parent)
{
    reload();
}

QVariantList IsoLibrary::images() const
{
    return m_images;
}

QString IsoLibrary::metadataPath() const
{
    const QString root = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(root);
    return root + QStringLiteral("/images.json");
}

void IsoLibrary::reload()
{
    m_images.clear();
    QFile file(metadataPath());
    if (!file.open(QIODevice::ReadOnly))
        return;

    const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
    for (const QJsonValue& value : document.array())
        m_images.append(value.toObject().toVariantMap());
}

void IsoLibrary::save() const
{
    QJsonArray array;
    for (const QVariant& item : m_images)
        array.append(QJsonObject::fromVariantMap(item.toMap()));

    QFile file(metadataPath());
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        file.write(QJsonDocument(array).toJson(QJsonDocument::Indented));
}

QString IsoLibrary::add(const QString& sourcePath, const QString& storagePath, QString* error)
{
    QFile source(sourcePath);
    if (!source.open(QIODevice::ReadOnly)) {
        *error = QStringLiteral("Не удалось прочитать ISO-образ");
        return {};
    }

    QCryptographicHash hash(QCryptographicHash::Sha256);
    if (!hash.addData(&source)) {
        *error = QStringLiteral("Не удалось вычислить контрольную сумму");
        return {};
    }

    return addVerified(sourcePath, storagePath, QString::fromLatin1(hash.result().toHex()), error);
}

QString IsoLibrary::addVerified(const QString& sourcePath, const QString& storagePath, const QString& sha256,
                                QString* error)
{
    for (const QVariant& item : m_images) {
        if (item.toMap().value(QStringLiteral("sha256")).toString() == sha256) {
            *error = QStringLiteral("Этот ISO-образ уже добавлен");
            return {};
        }
    }

    const QFileInfo info(sourcePath);
    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QVariantMap image;
    image.insert(QStringLiteral("id"), id);
    image.insert(QStringLiteral("name"), info.completeBaseName());
    image.insert(QStringLiteral("fileName"), info.fileName());
    image.insert(QStringLiteral("storagePath"), storagePath);
    image.insert(QStringLiteral("size"), info.size());
    image.insert(QStringLiteral("sizeText"), QStringLiteral("%1 ГБ").arg(info.size() / 1073741824.0, 0, 'f', 2));
    image.insert(QStringLiteral("sha256"), sha256);
    image.insert(QStringLiteral("addedAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    m_images.prepend(image);
    save();
    return id;
}

bool IsoLibrary::remove(const QString& id, QString* storagePath, QString* error)
{
    for (qsizetype index = 0; index < m_images.size(); ++index) {
        const QVariantMap item = m_images.at(index).toMap();
        if (item.value(QStringLiteral("id")).toString() != id)
            continue;
        *storagePath = item.value(QStringLiteral("storagePath")).toString();
        m_images.removeAt(index);
        save();
        return true;
    }
    *error = QStringLiteral("ISO-образ не найден в библиотеке");
    return false;
}

QString IsoLibrary::storagePath(const QString& id) const
{
    for (const QVariant& item : m_images) {
        const QVariantMap map = item.toMap();
        if (map.value(QStringLiteral("id")).toString() == id)
            return map.value(QStringLiteral("storagePath")).toString();
    }
    return {};
}
