#pragma once

#include <functional>

#include <QObject>
#include <QUrl>
#include <QVariantList>

#include "IsoLibrary.h"
#include "LibvirtManager.h"

class AppController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY stateChanged)
    Q_PROPERTY(bool systemReady READ systemReady NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY operationChanged)
    Q_PROPERTY(QString operationTitle READ operationTitle NOTIFY operationChanged)
    Q_PROPERTY(QString operationDetail READ operationDetail NOTIFY operationChanged)
    Q_PROPERTY(int operationProgress READ operationProgress NOTIFY operationChanged)
    Q_PROPERTY(QString message READ message NOTIFY messageChanged)
    Q_PROPERTY(QString connectionUri READ connectionUri NOTIFY stateChanged)
    Q_PROPERTY(QVariantList images READ images NOTIFY imagesChanged)
    Q_PROPERTY(QVariantList machines READ machines NOTIFY machinesChanged)
    Q_PROPERTY(QVariantList diagnostics READ diagnostics NOTIFY stateChanged)
    Q_PROPERTY(QVariantList snapshotItems READ snapshotItems NOTIFY snapshotsChanged)
    Q_PROPERTY(QVariantList backupItems READ backupItems NOTIFY backupsChanged)
    Q_PROPERTY(QVariantList hostGpuOptions READ hostGpuOptions CONSTANT)
    Q_PROPERTY(bool intelRenderAvailable READ intelRenderAvailable CONSTANT)
    Q_PROPERTY(QString intelRenderName READ intelRenderName CONSTANT)
    Q_PROPERTY(QString intelRenderNode READ intelRenderNode CONSTANT)
    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(bool windowsHost READ windowsHost CONSTANT)
    Q_PROPERTY(QString platformName READ platformName CONSTANT)
    Q_PROPERTY(QString qemuPath READ qemuPath NOTIFY settingsChanged)
    Q_PROPERTY(int defaultMemoryMiB READ defaultMemoryMiB NOTIFY settingsChanged)
    Q_PROPERTY(int defaultCpuCount READ defaultCpuCount NOTIFY settingsChanged)
    Q_PROPERTY(int defaultDiskGiB READ defaultDiskGiB NOTIFY settingsChanged)
    Q_PROPERTY(bool defaultUseEfi READ defaultUseEfi NOTIFY settingsChanged)
    Q_PROPERTY(bool defaultUse3d READ defaultUse3d NOTIFY settingsChanged)
    Q_PROPERTY(QString defaultDisplayMode READ defaultDisplayMode NOTIFY settingsChanged)
    Q_PROPERTY(QString defaultGpuId READ defaultGpuId NOTIFY settingsChanged)
    Q_PROPERTY(bool openDisplayAfterStart READ openDisplayAfterStart NOTIFY settingsChanged)
    Q_PROPERTY(QString backupDirectory READ backupDirectory NOTIFY settingsChanged)

  public:
    explicit AppController(QObject* parent = nullptr);

    bool connected() const;
    bool systemReady() const;
    bool busy() const;
    QString operationTitle() const;
    QString operationDetail() const;
    int operationProgress() const;
    QString message() const;
    QString connectionUri() const;
    QVariantList images() const;
    QVariantList machines() const;
    QVariantList diagnostics() const;
    QVariantList snapshotItems() const;
    QVariantList backupItems() const;
    QVariantList hostGpuOptions() const;
    bool intelRenderAvailable() const;
    QString intelRenderName() const;
    QString intelRenderNode() const;
    QString version() const;
    bool windowsHost() const;
    QString platformName() const;
    QString qemuPath() const;
    int defaultMemoryMiB() const;
    int defaultCpuCount() const;
    int defaultDiskGiB() const;
    bool defaultUseEfi() const;
    bool defaultUse3d() const;
    QString defaultDisplayMode() const;
    QString defaultGpuId() const;
    bool openDisplayAfterStart() const;
    QString backupDirectory() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void importIso(const QUrl& url);
    Q_INVOKABLE void removeIso(const QString& id);
    Q_INVOKABLE void createMachine(const QString& name, const QString& imageId, int memoryMiB, int cpuCount,
                                   int diskGiB, bool useEfi, bool use3d);
    Q_INVOKABLE void importExistingMachine(const QString& name, const QUrl& diskUrl, int memoryMiB, int cpuCount);
    Q_INVOKABLE void startMachine(const QString& id);
    Q_INVOKABLE void startMachineFromDisk(const QString& id);
    Q_INVOKABLE void resetMachine(const QString& id);
    Q_INVOKABLE void shutdownMachine(const QString& id);
    Q_INVOKABLE void forceStopMachine(const QString& id);
    Q_INVOKABLE void deleteMachine(const QString& id, bool removeDisk);
    Q_INVOKABLE void openDisplay(const QString& id);
    Q_INVOKABLE void openConsole(const QString& id);
    Q_INVOKABLE void loadSnapshots(const QString& id);
    Q_INVOKABLE void createSnapshot(const QString& id, const QString& name);
    Q_INVOKABLE void revertSnapshot(const QString& id, const QString& name);
    Q_INVOKABLE void deleteSnapshot(const QString& id, const QString& name);
    Q_INVOKABLE void updateMachineResources(const QString& id, int memoryMiB, int cpuCount, int diskGiB);
    Q_INVOKABLE void updateMachineGraphics(const QString& id, const QString& displayMode, const QString& gpuId,
                                           bool use3d, bool restart);
    Q_INVOKABLE void updateMachineConfiguration(const QString& id, int memoryMiB, int cpuCount, int diskGiB,
                                                const QString& displayMode, const QString& gpuId, bool use3d,
                                                bool restart);
    Q_INVOKABLE void loadBackups(const QString& id);
    Q_INVOKABLE void createBackup(const QString& id);
    Q_INVOKABLE void verifyBackup(const QString& path);
    Q_INVOKABLE void restoreBackup(const QString& id, const QString& path);
    Q_INVOKABLE void deleteBackup(const QString& path);
    Q_INVOKABLE void clearMessage();
    Q_INVOKABLE void saveQemuPath(const QString& value);
    Q_INVOKABLE void saveDefaults(int memoryMiB, int cpuCount, int diskGiB, bool useEfi, bool use3d,
                                  const QString& displayMode, const QString& gpuId, bool openAfterStart,
                                  const QString& backupDirectory);

  signals:
    void stateChanged();
    void operationChanged();
    void messageChanged();
    void imagesChanged();
    void machinesChanged();
    void snapshotsChanged();
    void backupsChanged();
    void operationSucceeded(const QString& text);
    void settingsChanged();

  private:
    using Task = std::function<QString()>;
    using Completion = std::function<void()>;

    void setOperation(bool active, const QString& title = {}, const QString& detail = {}, int progress = -1);
    void updateOperation(const QString& detail, int progress);
    void setMessage(const QString& value);
    void runOperation(const QString& title, const QString& success, Task task, Completion afterSuccess = {},
                      bool refreshAfter = true);

    LibvirtManager m_libvirt;
    IsoLibrary m_library;
    QVariantList m_machines;
    QVariantList m_snapshotItems;
    QVariantList m_backupItems;
    bool m_connected = false;
    bool m_busy = false;
    QString m_operationTitle;
    QString m_operationDetail;
    int m_operationProgress = -1;
    QString m_message;
    int m_refreshGeneration = 0;
    int m_snapshotGeneration = 0;
    int m_backupGeneration = 0;
};
