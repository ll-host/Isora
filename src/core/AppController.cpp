#include "AppController.h"
#include "RenderDevice.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QPointer>
#include <QSet>
#include <QSettings>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QTimer>
#include <QtConcurrent>

#include <atomic>
#include <memory>

namespace
{
class ImportedVolumeGuard
{
  public:
    explicit ImportedVolumeGuard(QString path) : m_path(std::move(path)) {}

    ~ImportedVolumeGuard()
    {
        if (m_committed.load() || m_path.isEmpty())
            return;
        QString error;
        LibvirtManager worker;
        if (worker.connect(&error))
            worker.deleteVolumeByPath(m_path, &error);
    }

    void commit() { m_committed.store(true); }

  private:
    QString m_path;
    std::atomic_bool m_committed = false;
};

struct IsoImportResult
{
    QString storagePath;
    QString sha256;
    QString error;
    std::shared_ptr<ImportedVolumeGuard> volumeGuard;
};

struct RefreshResult
{
    bool connected = false;
    QVariantList machines;
    QString error;
};

struct SnapshotResult
{
    QVariantList items;
    QString error;
};

struct BackupResult
{
    QVariantList items;
    QString error;
};

QString formatBytes(qint64 bytes)
{
    if (bytes >= 1024LL * 1024LL * 1024LL)
        return QStringLiteral("%1 ГиБ").arg(bytes / 1073741824.0, 0, 'f', 1);
    return QStringLiteral("%1 МиБ").arg(bytes / 1048576.0, 0, 'f', 0);
}
} // namespace

AppController::AppController(QObject* parent) : QObject(parent)
{
    QSettings().remove(QStringLiteral("graphics/renderNode"));
    QTimer::singleShot(0, this, &AppController::refresh);
}

bool AppController::connected() const
{
    return m_connected;
}

bool AppController::systemReady() const
{
    for (const QVariant& item : diagnostics()) {
        if (item.toMap().value(QStringLiteral("status")).toString() == QStringLiteral("error"))
            return false;
    }
    return true;
}

bool AppController::busy() const
{
    return m_busy;
}

QString AppController::operationTitle() const
{
    return m_operationTitle;
}

QString AppController::operationDetail() const
{
    return m_operationDetail;
}

int AppController::operationProgress() const
{
    return m_operationProgress;
}

QString AppController::message() const
{
    return m_message;
}

QString AppController::connectionUri() const
{
    return m_libvirt.connectionUri();
}

QVariantList AppController::images() const
{
    return m_library.images();
}

QVariantList AppController::machines() const
{
    return m_machines;
}

QVariantList AppController::snapshotItems() const
{
    return m_snapshotItems;
}

QVariantList AppController::backupItems() const
{
    return m_backupItems;
}

QVariantList AppController::hostGpuOptions() const
{
    QVariantList result{
        QVariantMap{{QStringLiteral("id"), QStringLiteral("auto")},
                    {QStringLiteral("name"), windowsHost() ? QStringLiteral("Автоматически (Windows)")
                                                            : QStringLiteral("Автоматически")},
                    {QStringLiteral("detail"), windowsHost() ? QStringLiteral("Системный выбор GPU")
                                                              : QStringLiteral("Предпочтительный DRM render-node")}}};
    for (const RenderDevices::Device& device : RenderDevices::all()) {
        result.append(QVariantMap{{QStringLiteral("id"), device.id}, {QStringLiteral("name"), device.name},
                                  {QStringLiteral("detail"), device.detail}});
    }
    return result;
}

QVariantList AppController::diagnostics() const
{
#ifdef Q_OS_WIN
    const QString qemu = qemuPath();
    const bool qemuReady = QFileInfo(qemu).isFile();
    const QString qemuImg = qemuReady ? QFileInfo(qemu).dir().filePath(QStringLiteral("qemu-img.exe")) : QString();
    const bool qemuImgReady = QFileInfo(qemuImg).isFile();
    QStorageInfo storage(m_libvirt.poolPath());
    const qint64 availableGiB = storage.isValid() && storage.isReady()
                                    ? storage.bytesAvailable() / (1024LL * 1024LL * 1024LL)
                                    : -1;
    return {
        QVariantMap{{QStringLiteral("name"), QStringLiteral("Аппаратная виртуализация")},
                    {QStringLiteral("value"), QStringLiteral("Windows Hypervisor Platform (WHPX)")},
                    {QStringLiteral("status"), QStringLiteral("ready")}},
        QVariantMap{{QStringLiteral("name"), QStringLiteral("QEMU")},
                    {QStringLiteral("value"), qemuReady ? qemu : QStringLiteral("qemu-system-x86_64.exe не найден")},
                    {QStringLiteral("status"), qemuReady ? QStringLiteral("ready") : QStringLiteral("error")}},
        QVariantMap{{QStringLiteral("name"), QStringLiteral("Управление дисками")},
                    {QStringLiteral("value"), qemuImgReady ? qemuImg : QStringLiteral("qemu-img.exe не найден рядом с QEMU")},
                    {QStringLiteral("status"), qemuImgReady ? QStringLiteral("ready") : QStringLiteral("error")}},
        QVariantMap{{QStringLiteral("name"), QStringLiteral("Хранилище")},
                    {QStringLiteral("value"), availableGiB >= 0 ? QStringLiteral("Свободно %1 ГиБ").arg(availableGiB)
                                                                  : QStringLiteral("Не удалось проверить")},
                    {QStringLiteral("status"), availableGiB >= 8 ? QStringLiteral("ready") : QStringLiteral("error")}},
        QVariantMap{{QStringLiteral("name"), QStringLiteral("Экран гостя")},
                    {QStringLiteral("value"), QStringLiteral("Отдельное окно QEMU · SDL · 1920×1080")},
                    {QStringLiteral("status"), qemuReady ? QStringLiteral("ready") : QStringLiteral("optional")}},
    };
#else
    const QFileInfo kvm(QStringLiteral("/dev/kvm"));
    const bool kvmReady = kvm.exists() && kvm.isReadable() && kvm.isWritable();
    const bool qemuReady = !QStandardPaths::findExecutable(QStringLiteral("qemu-system-x86_64")).isEmpty();
    const bool viewerReady = !QStandardPaths::findExecutable(QStringLiteral("virt-viewer")).isEmpty();
    const bool uefiReady = QFileInfo(QStringLiteral("/usr/share/edk2/x64/OVMF_CODE.4m.fd")).isReadable() &&
                           QFileInfo(QStringLiteral("/usr/share/edk2/x64/OVMF_VARS.4m.fd")).isReadable();
    const auto renderDevice = RenderDevices::intel();

    QStorageInfo storage(m_libvirt.poolPath());
    if (!storage.isValid() || !storage.isReady())
        storage = QStorageInfo(QStringLiteral("/var/lib/libvirt/images"));
    const qint64 availableGiB = storage.isValid() ? storage.bytesAvailable() / (1024LL * 1024LL * 1024LL) : -1;

    return {
        QVariantMap{{QStringLiteral("name"), QStringLiteral("Аппаратная виртуализация")},
                    {QStringLiteral("value"),
                     kvmReady ? QStringLiteral("Доступ к /dev/kvm есть") : QStringLiteral("Нет доступа к /dev/kvm")},
                    {QStringLiteral("status"), kvmReady ? QStringLiteral("ready") : QStringLiteral("error")}},
        QVariantMap{{QStringLiteral("name"), QStringLiteral("Служба виртуализации")},
                    {QStringLiteral("value"), m_connected ? QStringLiteral("Libvirt запущен · qemu:///system")
                                                          : QStringLiteral("Libvirt недоступен")},
                    {QStringLiteral("status"), m_connected ? QStringLiteral("ready") : QStringLiteral("error")}},
        QVariantMap{{QStringLiteral("name"), QStringLiteral("QEMU")},
                    {QStringLiteral("value"),
                     qemuReady ? QStringLiteral("Установлен") : QStringLiteral("qemu-system-x86_64 не найден")},
                    {QStringLiteral("status"), qemuReady ? QStringLiteral("ready") : QStringLiteral("error")}},
        QVariantMap{{QStringLiteral("name"), QStringLiteral("Просмотр экрана")},
                    {QStringLiteral("value"),
                     viewerReady ? QStringLiteral("virt-viewer установлен") : QStringLiteral("virt-viewer не найден")},
                    {QStringLiteral("status"), viewerReady ? QStringLiteral("ready") : QStringLiteral("error")}},
        QVariantMap{{QStringLiteral("name"), QStringLiteral("UEFI")},
                    {QStringLiteral("value"),
                     uefiReady ? QStringLiteral("OVMF установлен") : QStringLiteral("Файлы OVMF не найдены")},
                    {QStringLiteral("status"), uefiReady ? QStringLiteral("ready") : QStringLiteral("error")}},
        QVariantMap{{QStringLiteral("name"), QStringLiteral("Хранилище")},
                    {QStringLiteral("value"), availableGiB >= 0 ? QStringLiteral("Свободно %1 ГиБ").arg(availableGiB)
                                                                : QStringLiteral("Не удалось проверить")},
                    {QStringLiteral("status"), availableGiB >= 8 ? QStringLiteral("ready") : QStringLiteral("error")}},
        QVariantMap{
            {QStringLiteral("name"), QStringLiteral("3D-ускорение")},
            {QStringLiteral("value"), renderDevice ? renderDevice->name : QStringLiteral("Совместимый GPU не найден")},
            {QStringLiteral("status"), renderDevice ? QStringLiteral("ready") : QStringLiteral("optional")}},
    };
#endif
}

QString AppController::version() const
{
    return QCoreApplication::applicationVersion();
}

bool AppController::windowsHost() const
{
#ifdef Q_OS_WIN
    return true;
#else
    return false;
#endif
}

QString AppController::platformName() const
{
#ifdef Q_OS_WIN
    return QStringLiteral("Windows · QEMU/WHPX");
#else
    return QStringLiteral("Linux · QEMU/KVM + libvirt");
#endif
}

QString AppController::qemuPath() const
{
#ifdef Q_OS_WIN
    const QString configured = QSettings().value(QStringLiteral("windows/qemuPath")).toString();
    if (QFileInfo(configured).isFile())
        return QDir::toNativeSeparators(configured);
    const QString fromPath = QStandardPaths::findExecutable(QStringLiteral("qemu-system-x86_64.exe"));
    if (!fromPath.isEmpty())
        return QDir::toNativeSeparators(fromPath);
    const QString standard = QStringLiteral("C:/Program Files/qemu/qemu-system-x86_64.exe");
    return QFileInfo(standard).isFile() ? QDir::toNativeSeparators(standard) : QString();
#else
    return QStandardPaths::findExecutable(QStringLiteral("qemu-system-x86_64"));
#endif
}

int AppController::defaultMemoryMiB() const
{
    return QSettings().value(QStringLiteral("machines/memoryMiB"), 6144).toInt();
}

int AppController::defaultCpuCount() const
{
    return QSettings().value(QStringLiteral("machines/cpuCount"), 4).toInt();
}

int AppController::defaultDiskGiB() const
{
    return QSettings().value(QStringLiteral("machines/diskGiB"), 48).toInt();
}

bool AppController::defaultUseEfi() const
{
    return QSettings().value(QStringLiteral("machines/useEfi"), true).toBool();
}

bool AppController::defaultUse3d() const
{
    return intelRenderAvailable() && QSettings().value(QStringLiteral("machines/use3d"), false).toBool();
}

QString AppController::defaultDisplayMode() const
{
    const QString mode = QSettings().value(QStringLiteral("machines/displayMode"), QStringLiteral("windowed")).toString();
    return mode == QStringLiteral("borderless") || mode == QStringLiteral("fullscreen") ? mode
                                                                                           : QStringLiteral("windowed");
}

QString AppController::defaultGpuId() const
{
    const QString id = QSettings().value(QStringLiteral("machines/gpuId"), QStringLiteral("auto")).toString();
    for (const QVariant& option : hostGpuOptions()) {
        if (option.toMap().value(QStringLiteral("id")).toString() == id)
            return id;
    }
    return QStringLiteral("auto");
}

bool AppController::openDisplayAfterStart() const
{
    return QSettings().value(QStringLiteral("behavior/openDisplayAfterStart"), true).toBool();
}

QString AppController::backupDirectory() const
{
    const QString documents = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    return QSettings()
        .value(QStringLiteral("backups/directory"), documents + QStringLiteral("/Isora Backups"))
        .toString();
}

bool AppController::intelRenderAvailable() const
{
#ifdef Q_OS_WIN
    return false;
#else
    return !RenderDevices::all().isEmpty();
#endif
}

QString AppController::intelRenderName() const
{
    const auto device = RenderDevices::preferred();
    return device ? device->name : QString();
}

QString AppController::intelRenderNode() const
{
    const auto device = RenderDevices::preferred();
    return device ? device->path : QString();
}

void AppController::setOperation(bool active, const QString& title, const QString& detail, int progress)
{
    m_busy = active;
    m_operationTitle = active ? title : QString();
    m_operationDetail = active ? detail : QString();
    m_operationProgress = active ? progress : -1;
    emit operationChanged();
}

void AppController::updateOperation(const QString& detail, int progress)
{
    if (!m_busy)
        return;
    m_operationDetail = detail;
    m_operationProgress = progress;
    emit operationChanged();
}

void AppController::setMessage(const QString& value)
{
    if (m_message == value)
        return;
    m_message = value;
    emit messageChanged();
}

void AppController::runOperation(const QString& title, const QString& success, Task task, Completion afterSuccess,
                                 bool refreshAfter)
{
    if (m_busy)
        return;

    ++m_refreshGeneration;
    setOperation(true, title);
    auto* watcher = new QFutureWatcher<QString>(this);
    connect(watcher, &QFutureWatcher<QString>::finished, this,
            [this, watcher, success, afterSuccess = std::move(afterSuccess), refreshAfter] {
                const QString error = watcher->result();
                watcher->deleteLater();
                setOperation(false);
                if (!error.isEmpty()) {
                    setMessage(error);
                    return;
                }
                setMessage({});
                if (afterSuccess)
                    afterSuccess();
                emit operationSucceeded(success);
                if (refreshAfter)
                    refresh();
            });
    watcher->setFuture(QtConcurrent::run(std::move(task)));
}

void AppController::refresh()
{
    const int generation = ++m_refreshGeneration;
    auto* watcher = new QFutureWatcher<RefreshResult>(this);
    connect(watcher, &QFutureWatcher<RefreshResult>::finished, this, [this, watcher, generation] {
        const RefreshResult result = watcher->result();
        watcher->deleteLater();
        if (generation != m_refreshGeneration)
            return;
        m_connected = result.connected;
        m_machines = result.machines;
        if (!result.error.isEmpty())
            setMessage(result.error);
        emit stateChanged();
        emit machinesChanged();
    });
    watcher->setFuture(QtConcurrent::run([] {
        RefreshResult result;
        LibvirtManager worker;
        result.connected = worker.connectReadOnly(&result.error);
        if (result.connected)
            result.machines = worker.domains(&result.error);
        return result;
    }));
}

void AppController::importIso(const QUrl& url)
{
    const QString path = url.toLocalFile();
    if (path.isEmpty()) {
        setMessage(QStringLiteral("Выберите ISO-файл на этом компьютере"));
        return;
    }
    const QFileInfo file(path);
    if (!file.exists() || !file.isFile()) {
        setMessage(QStringLiteral("Выбранный ISO-файл не найден"));
        return;
    }
    if (m_busy)
        return;

    QSet<QString> knownHashes;
    for (const QVariant& item : m_library.images())
        knownHashes.insert(item.toMap().value(QStringLiteral("sha256")).toString());

    ++m_refreshGeneration;
    setOperation(true, QStringLiteral("Добавление ISO"), file.fileName(), 0);
    auto* watcher = new QFutureWatcher<IsoImportResult>(this);
    connect(watcher, &QFutureWatcher<IsoImportResult>::finished, this, [this, watcher, path] {
        IsoImportResult result = watcher->result();
        watcher->deleteLater();

        if (result.error.isEmpty())
            m_library.addVerified(path, result.storagePath, result.sha256, &result.error);
        if (result.error.isEmpty() && result.volumeGuard)
            result.volumeGuard->commit();

        setOperation(false);
        if (!result.error.isEmpty()) {
            setMessage(result.error);
            return;
        }
        setMessage({});
        emit imagesChanged();
        emit operationSucceeded(QStringLiteral("ISO добавлен"));
    });

    QPointer<AppController> self(this);
    watcher->setFuture(QtConcurrent::run([path, knownHashes = std::move(knownHashes), self] {
        IsoImportResult result;
        LibvirtManager worker;
        if (!worker.connect(&result.error))
            return result;
        result.storagePath = worker.importIso(path, &result.error, &result.sha256, [self](qint64 copied, qint64 total) {
            if (!self)
                return false;
            const int percent = total > 0 ? qBound(0, int((copied * 100) / total), 100) : -1;
            const QString detail = total > 0 ? QStringLiteral("%1 из %2").arg(formatBytes(copied), formatBytes(total))
                                             : formatBytes(copied);
            QMetaObject::invokeMethod(
                self,
                [self, detail, percent] {
                    if (self)
                        self->updateOperation(detail, percent);
                },
                Qt::QueuedConnection);
            return true;
        });
        if (result.error.isEmpty() && !result.storagePath.isEmpty())
            result.volumeGuard = std::make_shared<ImportedVolumeGuard>(result.storagePath);
        if (result.error.isEmpty() && knownHashes.contains(result.sha256)) {
            QString cleanupError;
            if (worker.deleteVolumeByPath(result.storagePath, &cleanupError) && result.volumeGuard)
                result.volumeGuard->commit();
            result.error = QStringLiteral("Этот ISO уже добавлен");
        }
        return result;
    }));
}

void AppController::removeIso(const QString& id)
{
    const QString path = m_library.storagePath(id);
    if (path.isEmpty()) {
        setMessage(QStringLiteral("ISO не найден в библиотеке"));
        return;
    }
    runOperation(
        QStringLiteral("Удаление ISO"), QStringLiteral("ISO удалён"),
        [path] {
            QString error;
            LibvirtManager worker;
            if (!worker.connect(&error) || !worker.deleteVolumeByPath(path, &error))
                return error;
            return QString();
        },
        [this, id] {
            QString removedPath;
            QString error;
            if (!m_library.remove(id, &removedPath, &error))
                setMessage(error);
            emit imagesChanged();
        },
        false);
}

void AppController::createMachine(const QString& name, const QString& imageId, int memoryMiB, int cpuCount, int diskGiB,
                                  bool useEfi, bool use3d)
{
    if (name.trimmed().isEmpty()) {
        setMessage(QStringLiteral("Введите название машины"));
        return;
    }
    const QString isoPath = m_library.storagePath(imageId);
    if (isoPath.isEmpty()) {
        setMessage(QStringLiteral("Выберите установочный образ"));
        return;
    }
    const QVariantMap options{{QStringLiteral("name"), name.trimmed()}, {QStringLiteral("isoPath"), isoPath},
                              {QStringLiteral("memoryMiB"), memoryMiB}, {QStringLiteral("cpuCount"), cpuCount},
                              {QStringLiteral("diskGiB"), diskGiB},     {QStringLiteral("useEfi"), useEfi},
                              {QStringLiteral("use3d"), use3d},
                              {QStringLiteral("displayMode"), defaultDisplayMode()},
                              {QStringLiteral("gpuId"), defaultGpuId()}};
    runOperation(QStringLiteral("Создание машины"), QStringLiteral("Машина создана"), [options] {
        QString error;
        LibvirtManager worker;
        if (!worker.connect(&error) || !worker.createMachine(options, &error))
            return error;
        return QString();
    });
}

void AppController::importExistingMachine(const QString& name, const QUrl& diskUrl, int memoryMiB, int cpuCount)
{
    const QString path = diskUrl.toLocalFile();
    if (name.trimmed().isEmpty() || path.isEmpty()) {
        setMessage(QStringLiteral("Укажите название и существующий QCOW2-диск"));
        return;
    }
    runOperation(QStringLiteral("Импорт машины"), QStringLiteral("Машина импортирована"),
                 [name = name.trimmed(), path, memoryMiB, cpuCount] {
                     QString error;
                     LibvirtManager worker;
                     if (!worker.connect(&error) ||
                         !worker.importExistingMachine(name, path, memoryMiB, cpuCount, &error))
                         return error;
                     return QString();
                 });
}

void AppController::startMachine(const QString& id)
{
    const bool openAfterStart = openDisplayAfterStart();
    runOperation(QStringLiteral("Запуск машины"), QStringLiteral("Машина запущена"), [id, openAfterStart] {
        QString error;
        LibvirtManager worker;
        if (!worker.connect(&error) || !worker.start(id, &error))
            return error;
        if (openAfterStart)
            worker.openDisplay(id, &error);
        return error;
    });
}

void AppController::startMachineFromDisk(const QString& id)
{
    const bool openAfterStart = openDisplayAfterStart();
    runOperation(QStringLiteral("Запуск с виртуального диска"), QStringLiteral("Машина запущена с диска"),
                 [id, openAfterStart] {
                     QString error;
                     LibvirtManager worker;
                     if (!worker.connect(&error) || !worker.startFromDisk(id, &error))
                         return error;
                     if (openAfterStart)
                         worker.openDisplay(id, &error);
                     return error;
                 });
}

void AppController::shutdownMachine(const QString& id)
{
    runOperation(QStringLiteral("Выключение машины"), QStringLiteral("Запрос на выключение отправлен"), [id] {
        QString error;
        LibvirtManager worker;
        if (!worker.connect(&error) || !worker.shutdown(id, &error))
            return error;
        return QString();
    });
}

void AppController::resetMachine(const QString& id)
{
    runOperation(QStringLiteral("Перезагрузка машины"), QStringLiteral("Машина перезагружена"), [id] {
        QString error;
        LibvirtManager worker;
        if (!worker.connect(&error) || !worker.reset(id, &error))
            return error;
        return QString();
    });
}

void AppController::forceStopMachine(const QString& id)
{
    runOperation(QStringLiteral("Принудительная остановка"), QStringLiteral("Машина остановлена"), [id] {
        QString error;
        LibvirtManager worker;
        if (!worker.connect(&error) || !worker.forceStop(id, &error))
            return error;
        return QString();
    });
}

void AppController::deleteMachine(const QString& id, bool removeDisk)
{
    runOperation(QStringLiteral("Удаление машины"), QStringLiteral("Машина удалена"), [id, removeDisk] {
        QString error;
        LibvirtManager worker;
        if (!worker.connect(&error) || !worker.removeMachine(id, removeDisk, &error))
            return error;
        return QString();
    });
}

void AppController::openDisplay(const QString& id)
{
    runOperation(
        QStringLiteral("Открытие экрана"), QStringLiteral("Экран открыт"),
        [id] {
            QString error;
            LibvirtManager worker;
            if (!worker.connect(&error) || !worker.openDisplay(id, &error))
                return error;
            return QString();
        },
        {}, false);
}

void AppController::updateMachineGraphics(const QString& id, const QString& displayMode, const QString& gpuId,
                                          bool use3d, bool restart)
{
    const bool openAfterStart = openDisplayAfterStart();
    runOperation(QStringLiteral("Настройка экрана"),
                 restart ? QStringLiteral("Машина перезапущена с новой графикой")
                         : QStringLiteral("Параметры экрана сохранены"),
                 [id, displayMode, gpuId, use3d, restart, openAfterStart] {
                     QString error;
                     LibvirtManager worker;
                     if (!worker.connect(&error))
                         return error;
                     if (restart && !worker.forceStop(id, &error))
                         return error;
                     if (!worker.updateMachineGraphics(id, displayMode, gpuId, use3d, &error))
                         return error;
                     if (restart && !worker.start(id, &error))
                         return error;
                     if (restart && openAfterStart)
                         worker.openDisplay(id, &error);
                     return error;
                 });
}

void AppController::updateMachineConfiguration(const QString& id, int memoryMiB, int cpuCount, int diskGiB,
                                               const QString& displayMode, const QString& gpuId, bool use3d,
                                               bool restart)
{
    const bool openAfterStart = openDisplayAfterStart();
    runOperation(QStringLiteral("Сохранение параметров"),
                 restart ? QStringLiteral("Машина перезапущена с новыми параметрами")
                         : QStringLiteral("Параметры машины сохранены"),
                 [id, memoryMiB, cpuCount, diskGiB, displayMode, gpuId, use3d, restart, openAfterStart] {
                     QString error;
                     LibvirtManager worker;
                     if (!worker.connect(&error))
                         return error;
                     if (restart && !worker.forceStop(id, &error))
                         return error;
                     if (!worker.updateMachineGraphics(id, displayMode, gpuId, use3d, &error))
                         return error;
                     if (!worker.updateMachineResources(id, memoryMiB, cpuCount, diskGiB, &error))
                         return error;
                     if (restart && !worker.start(id, &error))
                         return error;
                     if (restart && openAfterStart)
                         worker.openDisplay(id, &error);
                     return error;
                 });
}

void AppController::loadSnapshots(const QString& id)
{
    const int generation = ++m_snapshotGeneration;
    m_snapshotItems.clear();
    emit snapshotsChanged();
    auto* watcher = new QFutureWatcher<SnapshotResult>(this);
    connect(watcher, &QFutureWatcher<SnapshotResult>::finished, this, [this, watcher, generation] {
        const SnapshotResult result = watcher->result();
        watcher->deleteLater();
        if (generation != m_snapshotGeneration)
            return;
        m_snapshotItems = result.items;
        if (!result.error.isEmpty())
            setMessage(result.error);
        emit snapshotsChanged();
    });
    watcher->setFuture(QtConcurrent::run([id] {
        SnapshotResult result;
        LibvirtManager worker;
        if (worker.connect(&result.error))
            result.items = worker.snapshots(id, &result.error);
        return result;
    }));
}

void AppController::createSnapshot(const QString& id, const QString& name)
{
    runOperation(
        QStringLiteral("Создание снимка"), QStringLiteral("Снимок создан"),
        [id, name] {
            QString error;
            LibvirtManager worker;
            if (!worker.connect(&error) || !worker.createSnapshot(id, name, &error))
                return error;
            return QString();
        },
        [this, id] { loadSnapshots(id); }, false);
}

void AppController::revertSnapshot(const QString& id, const QString& name)
{
    runOperation(
        QStringLiteral("Восстановление снимка"), QStringLiteral("Состояние восстановлено"),
        [id, name] {
            QString error;
            LibvirtManager worker;
            if (!worker.connect(&error) || !worker.revertSnapshot(id, name, &error))
                return error;
            return QString();
        },
        [this, id] { loadSnapshots(id); });
}

void AppController::deleteSnapshot(const QString& id, const QString& name)
{
    runOperation(
        QStringLiteral("Удаление снимка"), QStringLiteral("Снимок удалён"),
        [id, name] {
            QString error;
            LibvirtManager worker;
            if (!worker.connect(&error) || !worker.removeSnapshot(id, name, &error))
                return error;
            return QString();
        },
        [this, id] { loadSnapshots(id); }, false);
}

void AppController::updateMachineResources(const QString& id, int memoryMiB, int cpuCount, int diskGiB)
{
    runOperation(QStringLiteral("Сохранение параметров машины"), QStringLiteral("Параметры машины сохранены"),
                 [id, memoryMiB, cpuCount, diskGiB] {
                     QString error;
                     LibvirtManager worker;
                     if (!worker.connect(&error) ||
                         !worker.updateMachineResources(id, memoryMiB, cpuCount, diskGiB, &error))
                         return error;
                     return QString();
                 });
}

void AppController::loadBackups(const QString& id)
{
    const int generation = ++m_backupGeneration;
    m_backupItems.clear();
    emit backupsChanged();
    const QString root = backupDirectory();
    auto* watcher = new QFutureWatcher<BackupResult>(this);
    connect(watcher, &QFutureWatcher<BackupResult>::finished, this, [this, watcher, generation] {
        const BackupResult result = watcher->result();
        watcher->deleteLater();
        if (generation != m_backupGeneration)
            return;
        m_backupItems = result.items;
        if (!result.error.isEmpty())
            setMessage(result.error);
        emit backupsChanged();
    });
    watcher->setFuture(QtConcurrent::run([id, root] {
        BackupResult result;
        LibvirtManager worker;
        if (worker.connect(&result.error))
            result.items = worker.backups(id, root, &result.error);
        return result;
    }));
}

void AppController::createBackup(const QString& id)
{
    if (m_busy)
        return;
    const QString root = backupDirectory();
    ++m_refreshGeneration;
    setOperation(true, QStringLiteral("Создание резервной копии"), QStringLiteral("Подготовка"), 0);
    auto* watcher = new QFutureWatcher<QString>(this);
    connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher, id] {
        const QString error = watcher->result();
        watcher->deleteLater();
        setOperation(false);
        if (!error.isEmpty()) {
            setMessage(error);
            return;
        }
        emit operationSucceeded(QStringLiteral("Резервная копия создана"));
        loadBackups(id);
    });
    QPointer<AppController> self(this);
    watcher->setFuture(QtConcurrent::run([id, root, self] {
        QString error;
        LibvirtManager worker;
        if (!worker.connect(&error))
            return error;
        worker.createBackup(id, root, &error, [self](qint64 done, qint64 total) {
            if (!self)
                return false;
            const int percent = total > 0 ? qBound(0, int(done * 100 / total), 99) : -1;
            const QString detail =
                total > 0 ? QStringLiteral("%1 из %2").arg(formatBytes(done), formatBytes(total)) : formatBytes(done);
            QMetaObject::invokeMethod(
                self,
                [self, detail, percent] {
                    if (self)
                        self->updateOperation(detail, percent);
                },
                Qt::QueuedConnection);
            return true;
        });
        return error;
    }));
}

void AppController::verifyBackup(const QString& path)
{
    runOperation(
        QStringLiteral("Проверка резервной копии"), QStringLiteral("Резервная копия исправна"),
        [path] {
            QString error;
            LibvirtManager worker;
            if (!worker.verifyBackup(path, &error))
                return error;
            return QString();
        },
        {}, false);
}

void AppController::restoreBackup(const QString& id, const QString& path)
{
    runOperation(QStringLiteral("Восстановление резервной копии"), QStringLiteral("Машина восстановлена"), [id, path] {
        QString error;
        LibvirtManager worker;
        if (!worker.connect(&error) || !worker.restoreBackup(id, path, &error))
            return error;
        return QString();
    });
}

void AppController::deleteBackup(const QString& path)
{
    const QString root = backupDirectory();
    runOperation(
        QStringLiteral("Удаление резервной копии"), QStringLiteral("Резервная копия удалена"),
        [path, root] {
            QString error;
            LibvirtManager worker;
            if (!worker.removeBackup(path, root, &error))
                return error;
            return QString();
        },
        [this, path] {
            for (qsizetype index = m_backupItems.size() - 1; index >= 0; --index) {
                if (m_backupItems.at(index).toMap().value(QStringLiteral("path")).toString() == path)
                    m_backupItems.removeAt(index);
            }
            emit backupsChanged();
        },
        false);
}

void AppController::clearMessage()
{
    setMessage({});
}

void AppController::saveQemuPath(const QString& value)
{
#ifdef Q_OS_WIN
    const QUrl url(value);
    const QString path = QDir::cleanPath(url.isLocalFile() ? url.toLocalFile() : value);
    if (!QFileInfo(path).isFile() || QFileInfo(path).fileName().compare(QStringLiteral("qemu-system-x86_64.exe"), Qt::CaseInsensitive) != 0) {
        setMessage(QStringLiteral("Выберите qemu-system-x86_64.exe из установленного QEMU"));
        return;
    }
    const QString qemuImg = QFileInfo(path).dir().filePath(QStringLiteral("qemu-img.exe"));
    if (!QFileInfo(qemuImg).isFile()) {
        setMessage(QStringLiteral("Рядом с QEMU не найден qemu-img.exe"));
        return;
    }
    QSettings().setValue(QStringLiteral("windows/qemuPath"), path);
    setMessage({});
    emit settingsChanged();
    emit operationSucceeded(QStringLiteral("Путь к QEMU сохранён"));
    refresh();
#else
    Q_UNUSED(value)
#endif
}

void AppController::saveDefaults(int memoryMiB, int cpuCount, int diskGiB, bool useEfi, bool use3d,
                                 const QString& displayMode, const QString& gpuId, bool openAfterStart,
                                 const QString& backupDirectoryValue)
{
    QSettings settings;
    settings.setValue(QStringLiteral("machines/memoryMiB"), qBound(1024, memoryMiB, 262144));
    settings.setValue(QStringLiteral("machines/cpuCount"), qBound(1, cpuCount, 256));
    settings.setValue(QStringLiteral("machines/diskGiB"), qBound(8, diskGiB, 2048));
    settings.setValue(QStringLiteral("machines/useEfi"), useEfi);
    settings.setValue(QStringLiteral("machines/use3d"), use3d && intelRenderAvailable());
    settings.setValue(QStringLiteral("machines/displayMode"), displayMode);
    settings.setValue(QStringLiteral("machines/gpuId"), gpuId);
    settings.setValue(QStringLiteral("behavior/openDisplayAfterStart"), openAfterStart);
    const QUrl backupUrl(backupDirectoryValue);
    const QString backupPath = backupUrl.isLocalFile() ? backupUrl.toLocalFile() : backupDirectoryValue;
    if (!backupPath.trimmed().isEmpty())
        settings.setValue(QStringLiteral("backups/directory"), QDir::cleanPath(backupPath));
    settings.sync();
    emit settingsChanged();
    emit operationSucceeded(QStringLiteral("Параметры сохранены"));
}
