#pragma once

#include <QObject>
#include <QVariantList>

class IsoLibrary final : public QObject
{
    Q_OBJECT

  public:
    explicit IsoLibrary(QObject* parent = nullptr);

    QVariantList images() const;
    QString add(const QString& sourcePath, const QString& storagePath, QString* error);
    QString addVerified(const QString& sourcePath, const QString& storagePath, const QString& sha256, QString* error);
    bool remove(const QString& id, QString* storagePath, QString* error);
    QString storagePath(const QString& id) const;
    void reload();

  private:
    QString metadataPath() const;
    void save() const;

    QVariantList m_images;
};
