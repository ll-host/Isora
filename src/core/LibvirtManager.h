#pragma once

#include <functional>

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

#ifndef Q_OS_WIN
#include <libvirt/libvirt.h>
#endif

class LibvirtManager final : public QObject
{
    Q_OBJECT

  public:
    explicit LibvirtManager(QObject* parent = nullptr);
    ~LibvirtManager() override;

    bool connect(QString* error);
    bool connectReadOnly(QString* error);
    bool isConnected() const;
    QVariantList domains(QString* error) const;
    QString poolPath() const;
    using TransferProgress = std::function<bool(qint64 copied, qint64 total)>;

    QString importIso(const QString& sourcePath, QString* error, QString* sha256 = nullptr,
                      const TransferProgress& progress = {});
    bool deleteVolumeByPath(const QString& path, QString* error);
    bool createMachine(const QVariantMap& options, QString* error);
    bool importExistingMachine(const QString& name, const QString& diskPath, int memoryMiB, int cpuCount,
                               QString* error);
    QVariantMap machineDetails(const QString& id, QString* error) const;
    bool updateMachineResources(const QString& id, int memoryMiB, int cpuCount, int diskGiB, QString* error);
    bool updateMachineGraphics(const QString& id, const QString& displayMode, const QString& gpuId, bool use3d,
                               QString* error);
    bool start(const QString& id, QString* error);
    bool startFromDisk(const QString& id, QString* error);
    bool reset(const QString& id, QString* error);
    bool shutdown(const QString& id, QString* error);
    bool forceStop(const QString& id, QString* error);
    bool removeMachine(const QString& id, bool removeDisk, QString* error);
    bool openDisplay(const QString& id, QString* error) const;
    QVariantList snapshots(const QString& id, QString* error) const;
    bool createSnapshot(const QString& id, const QString& name, QString* error);
    bool revertSnapshot(const QString& id, const QString& name, QString* error);
    bool removeSnapshot(const QString& id, const QString& name, QString* error);
    QVariantList backups(const QString& id, const QString& backupRoot, QString* error) const;
    QString createBackup(const QString& id, const QString& backupRoot, QString* error,
                         const TransferProgress& progress = {});
    bool verifyBackup(const QString& backupPath, QString* error, const TransferProgress& progress = {}) const;
    bool restoreBackup(const QString& id, const QString& backupPath, QString* error,
                       const TransferProgress& progress = {});
    bool removeBackup(const QString& backupPath, const QString& backupRoot, QString* error) const;
    QString connectionUri() const;

  private:
#ifdef Q_OS_WIN
    QString machineDirectory(const QString& id) const;
    QString machineConfigPath(const QString& id) const;
    QString qemuExecutable() const;
    QString qemuImgExecutable() const;
#else
    bool ensurePool(QString* error);
    virStoragePoolPtr pool(QString* error) const;
    virDomainPtr domain(const QString& id, QString* error) const;
    QString createDisk(const QString& machineId, int sizeGiB, QString* error);
    QString ensureNvramTemplate(QString* error);
    QString createVolume(const QString& name, quint64 capacity, const QString& format, QString* error);
    bool downloadVolume(const QString& volumePath, const QString& targetPath, QString* error,
                        const TransferProgress& progress) const;
    bool uploadVolume(const QString& sourcePath, virStorageVolPtr volume, QString* error,
                      const TransferProgress& progress) const;
    bool validateDomainXml(const QString& xml, QString* error) const;
    static QString lastError(const QString& fallback);
    static QString escaped(const QString& value);
    static QString stateText(int state);

    virConnectPtr m_connection = nullptr;
    bool m_readOnly = false;
#endif
    QString m_poolPath = QStringLiteral("/var/lib/libvirt/images/isora");
    bool m_connected = false;
};
