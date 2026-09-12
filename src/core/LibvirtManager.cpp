#include "LibvirtManager.h"
#include "DomainSafetyPolicy.h"
#include "RenderDevice.h"

#include <QCryptographicHash>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QDomDocument>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QTemporaryDir>
#include <QUuid>
#include <QXmlStreamWriter>

#include <libvirt/virterror.h>

namespace
{
class PoolHandle
{
  public:
    explicit PoolHandle(virStoragePoolPtr value = nullptr) : value(value) {}
    ~PoolHandle()
    {
        if (value)
            virStoragePoolFree(value);
    }
    operator virStoragePoolPtr() const { return value; }
    virStoragePoolPtr value = nullptr;
};

class VolumeHandle
{
  public:
    explicit VolumeHandle(virStorageVolPtr value = nullptr) : value(value) {}
    ~VolumeHandle()
    {
        if (value)
            virStorageVolFree(value);
    }
    operator virStorageVolPtr() const { return value; }
    virStorageVolPtr value = nullptr;
};

class DomainHandle
{
  public:
    explicit DomainHandle(virDomainPtr value = nullptr) : value(value) {}
    ~DomainHandle()
    {
        if (value)
            virDomainFree(value);
    }
    operator virDomainPtr() const { return value; }
    virDomainPtr value = nullptr;
};

class SnapshotHandle
{
  public:
    explicit SnapshotHandle(virDomainSnapshotPtr value = nullptr) : value(value) {}
    ~SnapshotHandle()
    {
        if (value)
            virDomainSnapshotFree(value);
    }
    operator virDomainSnapshotPtr() const { return value; }
    virDomainSnapshotPtr value = nullptr;
};

QString xmlText(const QDomElement& parent, const QString& tag)
{
    const QDomNodeList nodes = parent.elementsByTagName(tag);
    return nodes.isEmpty() ? QString() : nodes.at(0).toElement().text();
}

QString primaryDiskPath(const QDomElement& root)
{
    const QDomNodeList disks = root.elementsByTagName(QStringLiteral("disk"));
    for (qsizetype index = 0; index < disks.size(); ++index) {
        const QDomElement disk = disks.at(index).toElement();
        if (disk.attribute(QStringLiteral("device")) != QStringLiteral("disk"))
            continue;
        return disk.firstChildElement(QStringLiteral("source")).attribute(QStringLiteral("file"));
    }
    return {};
}

QString nvramPath(const QDomElement& root)
{
    return root.firstChildElement(QStringLiteral("os")).firstChildElement(QStringLiteral("nvram")).text();
}

qint64 memoryMiB(const QDomElement& root)
{
    const QDomElement memory = root.firstChildElement(QStringLiteral("memory"));
    qint64 value = memory.text().toLongLong();
    const QString unit = memory.attribute(QStringLiteral("unit")).toLower();
    if (unit == QStringLiteral("kib"))
        value /= 1024;
    else if (unit == QStringLiteral("gib"))
        value *= 1024;
    return value;
}

QString safeFilePart(QString value)
{
    value = value.trimmed();
    value.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9А-Яа-я._-]+")), QStringLiteral("-"));
    value = value.left(48);
    return value.isEmpty() ? QStringLiteral("machine") : value;
}

QJsonObject readMetadata(const QString& backupPath, QString* error)
{
    error->clear();
    QFile file(QDir(backupPath).filePath(QStringLiteral("metadata.json")));
    if (!file.open(QIODevice::ReadOnly)) {
        *error = QStringLiteral("В резервной копии нет файла metadata.json");
        return {};
    }
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        *error = QStringLiteral("Метаданные резервной копии повреждены");
        return {};
    }
    const QJsonObject object = document.object();
    if (object.value(QStringLiteral("formatVersion")).toInt() != 1) {
        *error = QStringLiteral("Версия формата резервной копии не поддерживается");
        return {};
    }
    return object;
}

QString fileSha256(const QString& path, QString* error, const LibvirtManager::TransferProgress& progress = {})
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        *error = QStringLiteral("Не удалось открыть файл резервной копии");
        return {};
    }
    QCryptographicHash hash(QCryptographicHash::Sha256);
    QByteArray buffer(1024 * 1024, Qt::Uninitialized);
    qint64 done = 0;
    while (!file.atEnd()) {
        const qint64 count = file.read(buffer.data(), buffer.size());
        if (count < 0) {
            *error = QStringLiteral("Не удалось прочитать файл резервной копии");
            return {};
        }
        hash.addData(QByteArrayView(buffer.constData(), count));
        done += count;
        if (progress && !progress(done, file.size())) {
            *error = QStringLiteral("Операция отменена");
            return {};
        }
    }
    return QString::fromLatin1(hash.result().toHex());
}

struct SparseDownloadTarget
{
    QFile* file = nullptr;
    qint64 expected = 0;
    LibvirtManager::TransferProgress progress;
};

int receiveSparseData(virStreamPtr, const char* data, size_t size, void* opaque)
{
    auto* target = static_cast<SparseDownloadTarget*>(opaque);
    const qint64 written = target->file->write(data, qint64(size));
    if (written != qint64(size))
        return -1;
    if (target->progress && !target->progress(target->file->pos(), target->expected))
        return -1;
    return int(written);
}

int receiveSparseHole(virStreamPtr, long long length, void* opaque)
{
    auto* target = static_cast<SparseDownloadTarget*>(opaque);
    if (!target->file->seek(target->file->pos() + length))
        return -1;
    if (target->progress && !target->progress(target->file->pos(), target->expected))
        return -1;
    return 0;
}

bool domainUses3d(const QDomDocument& document)
{
    const QDomNodeList acceleration = document.elementsByTagName(QStringLiteral("acceleration"));
    for (qsizetype index = 0; index < acceleration.size(); ++index) {
        if (acceleration.at(index).toElement().attribute(QStringLiteral("accel3d")) == QStringLiteral("yes"))
            return true;
    }
    return false;
}

bool validDisplayMode(const QString& mode)
{
    return mode == QStringLiteral("windowed") || mode == QStringLiteral("borderless") ||
           mode == QStringLiteral("fullscreen");
}

bool isEglInitializationError(const QString& error)
{
    return error.contains(QStringLiteral("EGL_NOT_INITIALIZED"), Qt::CaseInsensitive) ||
           error.contains(QStringLiteral("eglInitialize failed"), Qt::CaseInsensitive) ||
           error.contains(QStringLiteral("render node init failed"), Qt::CaseInsensitive);
}

bool authorizeManagement(QString* error)
{
    const QString executable = QStandardPaths::findExecutable(QStringLiteral("pkcheck"));
    if (executable.isEmpty())
        return true;

    const QStringList baseArguments{QStringLiteral("--action-id"), QStringLiteral("org.libvirt.unix.manage"),
                                    QStringLiteral("--process"),
                                    QString::number(QCoreApplication::applicationPid())};
    QProcess check;
    check.start(executable, baseArguments);
    const bool checkFinished = check.waitForFinished(5000);
    if (checkFinished && check.exitStatus() == QProcess::NormalExit && check.exitCode() == 0)
        return true;
    if (!checkFinished) {
        check.kill();
        check.waitForFinished();
    }

    QStringList interactiveArguments = baseArguments;
    interactiveArguments.append(QStringLiteral("--allow-user-interaction"));
    check.start(executable, interactiveArguments);
    if (!check.waitForFinished(120000)) {
        check.kill();
        check.waitForFinished();
        *error = QStringLiteral("Авторизация libvirt не завершена");
        return false;
    }
    if (check.exitStatus() != QProcess::NormalExit || check.exitCode() != 0) {
        *error = QStringLiteral("Доступ к управлению виртуальными машинами не подтверждён");
        return false;
    }
    return true;
}

QString displayMetadata(const QDomDocument& document, const QString& attribute, const QString& fallback)
{
    const QDomNodeList nodes = document.elementsByTagName(QStringLiteral("isora:display"));
    if (nodes.isEmpty())
        return fallback;
    const QString value = nodes.at(0).toElement().attribute(attribute);
    return value.isEmpty() ? fallback : value;
}

void setDisplayMetadata(QDomDocument* document, const QString& mode, const QString& gpuId)
{
    QDomElement root = document->documentElement();
    QDomElement metadata = root.firstChildElement(QStringLiteral("metadata"));
    if (metadata.isNull()) {
        metadata = document->createElement(QStringLiteral("metadata"));
        root.insertBefore(metadata, root.firstChild());
    }
    QDomNodeList nodes = document->elementsByTagName(QStringLiteral("isora:display"));
    QDomElement display;
    if (nodes.isEmpty()) {
        display = document->createElement(QStringLiteral("isora:display"));
        display.setAttribute(QStringLiteral("xmlns:isora"), QStringLiteral("https://github.com/ll-host/Isora"));
        metadata.appendChild(display);
    } else {
        display = nodes.at(0).toElement();
    }
    display.setAttribute(QStringLiteral("mode"), mode);
    display.setAttribute(QStringLiteral("gpu"), gpuId);
}

void removeGraphics(QDomElement devices)
{
    QList<QDomNode> graphicsNodes;
    for (QDomElement graphics = devices.firstChildElement(QStringLiteral("graphics")); !graphics.isNull();
         graphics = graphics.nextSiblingElement(QStringLiteral("graphics")))
        graphicsNodes.append(graphics);
    for (const QDomNode& graphics : graphicsNodes)
        devices.removeChild(graphics);
}

QString normalize3dDisplay(const QString& xml, const QString& renderNode)
{
    QDomDocument document;
    if (!document.setContent(xml))
        return xml;

    QDomElement devices = document.documentElement().firstChildElement(QStringLiteral("devices"));
    const QDomNodeList existingGraphics = devices.elementsByTagName(QStringLiteral("graphics"));
    if (existingGraphics.size() == 1) {
        const QDomElement graphics = existingGraphics.at(0).toElement();
        const QDomElement gl = graphics.firstChildElement(QStringLiteral("gl"));
        if (graphics.attribute(QStringLiteral("type")) == QStringLiteral("spice") &&
            gl.attribute(QStringLiteral("enable")) == QStringLiteral("yes") &&
            gl.attribute(QStringLiteral("rendernode")) == renderNode) {
            return xml;
        }
    }

    removeGraphics(devices);

    QDomElement video = devices.firstChildElement(QStringLiteral("video"));
    if (video.isNull())
        return xml;
    QDomElement model = video.firstChildElement(QStringLiteral("model"));
    if (model.isNull()) {
        model = document.createElement(QStringLiteral("model"));
        video.appendChild(model);
    }
    model.setAttribute(QStringLiteral("type"), QStringLiteral("virtio"));
    model.removeAttribute(QStringLiteral("device"));
    QDomElement acceleration = model.firstChildElement(QStringLiteral("acceleration"));
    if (acceleration.isNull()) {
        acceleration = document.createElement(QStringLiteral("acceleration"));
        model.appendChild(acceleration);
    }
    acceleration.setAttribute(QStringLiteral("accel3d"), QStringLiteral("yes"));

    QDomElement spiceGraphics = document.createElement(QStringLiteral("graphics"));
    spiceGraphics.setAttribute(QStringLiteral("type"), QStringLiteral("spice"));
    spiceGraphics.setAttribute(QStringLiteral("autoport"), QStringLiteral("yes"));
    QDomElement listen = document.createElement(QStringLiteral("listen"));
    listen.setAttribute(QStringLiteral("type"), QStringLiteral("none"));
    spiceGraphics.appendChild(listen);
    QDomElement image = document.createElement(QStringLiteral("image"));
    image.setAttribute(QStringLiteral("compression"), QStringLiteral("off"));
    spiceGraphics.appendChild(image);
    QDomElement gl = document.createElement(QStringLiteral("gl"));
    gl.setAttribute(QStringLiteral("enable"), QStringLiteral("yes"));
    gl.setAttribute(QStringLiteral("rendernode"), renderNode);
    spiceGraphics.appendChild(gl);
    devices.insertBefore(spiceGraphics, video);

    for (QDomElement channel = devices.firstChildElement(QStringLiteral("channel")); !channel.isNull();
         channel = channel.nextSiblingElement(QStringLiteral("channel"))) {
        const QDomElement target = channel.firstChildElement(QStringLiteral("target"));
        if (target.attribute(QStringLiteral("name")) != QStringLiteral("com.redhat.spice.0"))
            continue;
        if (channel.attribute(QStringLiteral("type")) != QStringLiteral("spicevmc")) {
            QDomElement replacement = document.createElement(QStringLiteral("channel"));
            replacement.setAttribute(QStringLiteral("type"), QStringLiteral("spicevmc"));
            QDomElement replacementTarget = document.createElement(QStringLiteral("target"));
            replacementTarget.setAttribute(QStringLiteral("type"), QStringLiteral("virtio"));
            replacementTarget.setAttribute(QStringLiteral("name"), QStringLiteral("com.redhat.spice.0"));
            replacement.appendChild(replacementTarget);
            devices.replaceChild(replacement, channel);
        }
        break;
    }

    return document.toString(-1);
}

QString normalize2dDisplay(const QString& xml)
{
    QDomDocument document;
    if (!document.setContent(xml))
        return xml;
    QDomElement devices = document.documentElement().firstChildElement(QStringLiteral("devices"));
    QDomElement video = devices.firstChildElement(QStringLiteral("video"));
    if (devices.isNull() || video.isNull())
        return xml;
    removeGraphics(devices);
    QDomElement graphics = document.createElement(QStringLiteral("graphics"));
    graphics.setAttribute(QStringLiteral("type"), QStringLiteral("spice"));
    graphics.setAttribute(QStringLiteral("autoport"), QStringLiteral("yes"));
    QDomElement listen = document.createElement(QStringLiteral("listen"));
    listen.setAttribute(QStringLiteral("type"), QStringLiteral("none"));
    graphics.appendChild(listen);
    devices.insertBefore(graphics, video);
    QDomElement model = video.firstChildElement(QStringLiteral("model"));
    if (model.isNull()) {
        model = document.createElement(QStringLiteral("model"));
        video.appendChild(model);
    }
    model.setAttribute(QStringLiteral("type"), QStringLiteral("virtio"));
    // libvirt includes the resolved QEMU model in inactive XML. Keeping
    // `device='virtio-vga-gl'` while removing accel3d produces an invalid
    // fallback: virtio-vga-gl can only be used with 3D acceleration. Let
    // libvirt resolve the non-GL VirtIO model again from type='virtio'.
    model.removeAttribute(QStringLiteral("device"));
    QDomElement acceleration = model.firstChildElement(QStringLiteral("acceleration"));
    if (!acceleration.isNull())
        model.removeChild(acceleration);
    return document.toString(-1);
}
} // namespace

LibvirtManager::LibvirtManager(QObject* parent) : QObject(parent)
{
    virInitialize();
}

LibvirtManager::~LibvirtManager()
{
    if (m_connection)
        virConnectClose(m_connection);
}

QString LibvirtManager::lastError(const QString& fallback)
{
    const virErrorPtr error = virGetLastError();
    if (error && error->message)
        return QString::fromUtf8(error->message).trimmed();
    return fallback;
}

QString LibvirtManager::escaped(const QString& value)
{
    QString output;
    QXmlStreamWriter writer(&output);
    writer.writeCharacters(value);
    return output;
}

bool LibvirtManager::connect(QString* error)
{
    error->clear();
    if (m_connection && !m_readOnly && virConnectIsAlive(m_connection) == 1)
        return true;
    if (m_connection) {
        virConnectClose(m_connection);
        m_connection = nullptr;
    }
    if (!authorizeManagement(error))
        return false;
    m_connection = virConnectOpen("qemu:///system");
    if (!m_connection) {
        *error = QStringLiteral("Не удалось подключиться к системной службе libvirt: %1")
                     .arg(lastError(QStringLiteral("неизвестная ошибка")));
        return false;
    }
    m_readOnly = false;
    return true;
}

bool LibvirtManager::connectReadOnly(QString* error)
{
    error->clear();
    if (m_connection && virConnectIsAlive(m_connection) == 1)
        return true;
    if (m_connection) {
        virConnectClose(m_connection);
        m_connection = nullptr;
    }
    m_connection = virConnectOpenReadOnly("qemu:///system");
    if (!m_connection) {
        *error = QStringLiteral("Не удалось подключиться к системной службе libvirt: %1")
                     .arg(lastError(QStringLiteral("неизвестная ошибка")));
        return false;
    }
    m_readOnly = true;
    return true;
}

bool LibvirtManager::isConnected() const
{
    return m_connection && virConnectIsAlive(m_connection) == 1;
}

QString LibvirtManager::connectionUri() const
{
    return QStringLiteral("qemu:///system");
}

QString LibvirtManager::poolPath() const
{
    return m_poolPath;
}

virStoragePoolPtr LibvirtManager::pool(QString* error) const
{
    if (!m_connection) {
        *error = QStringLiteral("Нет подключения к libvirt");
        return nullptr;
    }
    virStoragePoolPtr result = virStoragePoolLookupByName(m_connection, "isora");
    if (!result)
        *error = lastError(QStringLiteral("Хранилище Isora не найдено"));
    return result;
}

bool LibvirtManager::ensurePool(QString* error)
{
    if (!isConnected() && !connect(error))
        return false;

    PoolHandle storage(virStoragePoolLookupByName(m_connection, "isora"));
    if (!storage.value) {
        const QString xml = QStringLiteral("<pool type='dir'><name>isora</name><target><path>%1</path>"
                                           "<permissions><mode>0711</mode></permissions></target></pool>")
                                .arg(escaped(m_poolPath));
        storage.value = virStoragePoolDefineXML(m_connection, xml.toUtf8().constData(), 0);
        if (!storage.value) {
            *error = QStringLiteral("Не удалось создать хранилище Isora: %1")
                         .arg(lastError(QStringLiteral("недостаточно прав")));
            return false;
        }
        if (virStoragePoolBuild(storage, 0) < 0) {
            *error = QStringLiteral("Не удалось подготовить каталог хранилища: %1").arg(lastError({}));
            return false;
        }
        virStoragePoolSetAutostart(storage, 1);
    }
    if (virStoragePoolIsActive(storage) != 1 && virStoragePoolCreate(storage, 0) < 0) {
        *error = QStringLiteral("Не удалось запустить хранилище Isora: %1").arg(lastError({}));
        return false;
    }
    if (virStoragePoolRefresh(storage, 0) < 0) {
        *error = QStringLiteral("Не удалось обновить хранилище Isora: %1").arg(lastError({}));
        return false;
    }
    return true;
}

QString LibvirtManager::importIso(const QString& sourcePath, QString* error, QString* sha256,
                                  const TransferProgress& progress)
{
    if (!ensurePool(error))
        return {};

    QFile source(sourcePath);
    if (!source.open(QIODevice::ReadOnly)) {
        *error = QStringLiteral("Не удалось открыть ISO-образ");
        return {};
    }

    PoolHandle storage(pool(error));
    if (!storage.value)
        return {};

    const QString volumeName = QStringLiteral("iso-%1.iso").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const QString volumeXml = QStringLiteral("<volume><name>%1</name><capacity unit='bytes'>%2</capacity>"
                                             "<allocation unit='bytes'>0</allocation><target><format type='raw'/>"
                                             "<permissions><mode>0644</mode></permissions></target></volume>")
                                  .arg(escaped(volumeName))
                                  .arg(source.size());
    VolumeHandle volume(virStorageVolCreateXML(storage, volumeXml.toUtf8().constData(), 0));
    if (!volume.value) {
        *error = QStringLiteral("Не удалось создать ISO в хранилище: %1").arg(lastError({}));
        return {};
    }

    virStreamPtr stream = virStreamNew(m_connection, 0);
    if (!stream || virStorageVolUpload(volume, stream, 0, source.size(), 0) < 0) {
        if (stream)
            virStreamFree(stream);
        virStorageVolDelete(volume, 0);
        *error = QStringLiteral("Не удалось начать копирование ISO: %1").arg(lastError({}));
        return {};
    }

    QByteArray buffer(1024 * 1024, Qt::Uninitialized);
    QCryptographicHash hash(QCryptographicHash::Sha256);
    bool failed = false;
    bool canceled = false;
    qint64 copied = 0;
    while (!source.atEnd() && !failed) {
        const qint64 count = source.read(buffer.data(), buffer.size());
        if (count < 0) {
            failed = true;
            break;
        }
        hash.addData(QByteArrayView(buffer.constData(), count));
        qint64 offset = 0;
        while (offset < count) {
            const int sent = virStreamSend(stream, buffer.constData() + offset, count - offset);
            if (sent <= 0) {
                failed = true;
                break;
            }
            offset += sent;
            copied += sent;
            if (progress && !progress(copied, source.size())) {
                canceled = true;
                failed = true;
                break;
            }
        }
    }
    if (failed || virStreamFinish(stream) < 0) {
        virStreamAbort(stream);
        virStreamFree(stream);
        virStorageVolDelete(volume, 0);
        *error = canceled ? QStringLiteral("Добавление ISO отменено")
                          : QStringLiteral("Копирование ISO прервано: %1").arg(lastError({}));
        return {};
    }
    virStreamFree(stream);

    char* rawPath = virStorageVolGetPath(volume);
    const QString result = rawPath ? QString::fromUtf8(rawPath) : QString();
    free(rawPath);
    if (result.isEmpty())
        *error = QStringLiteral("Libvirt не вернул путь импортированного ISO");
    else if (sha256)
        *sha256 = QString::fromLatin1(hash.result().toHex());
    return result;
}

bool LibvirtManager::deleteVolumeByPath(const QString& path, QString* error)
{
    if (path.isEmpty())
        return true;
    if (!QDir::cleanPath(path).startsWith(m_poolPath + QLatin1Char('/'))) {
        *error = QStringLiteral("Отказано в удалении файла вне хранилища Isora");
        return false;
    }
    VolumeHandle volume(virStorageVolLookupByPath(m_connection, path.toUtf8().constData()));
    if (!volume.value) {
        *error = QStringLiteral("Том не найден в хранилище Isora");
        return false;
    }
    if (virStorageVolDelete(volume, 0) < 0) {
        *error = QStringLiteral("Не удалось удалить том: %1").arg(lastError({}));
        return false;
    }
    return true;
}

QString LibvirtManager::createDisk(const QString& machineId, int sizeGiB, QString* error)
{
    if (!ensurePool(error))
        return {};
    PoolHandle storage(pool(error));
    if (!storage.value)
        return {};
    const QString name = machineId + QStringLiteral("-disk.qcow2");
    const quint64 bytes = quint64(sizeGiB) * 1024ULL * 1024ULL * 1024ULL;
    const QString xml = QStringLiteral("<volume><name>%1</name><capacity unit='bytes'>%2</capacity>"
                                       "<allocation unit='bytes'>0</allocation><target><format type='qcow2'/>"
                                       "<permissions><mode>0640</mode></permissions></target></volume>")
                            .arg(escaped(name))
                            .arg(bytes);
    VolumeHandle volume(virStorageVolCreateXML(storage, xml.toUtf8().constData(), 0));
    if (!volume.value) {
        *error = QStringLiteral("Не удалось создать виртуальный диск: %1").arg(lastError({}));
        return {};
    }
    char* rawPath = virStorageVolGetPath(volume);
    const QString path = rawPath ? QString::fromUtf8(rawPath) : QString();
    free(rawPath);
    return path;
}

QString LibvirtManager::createVolume(const QString& name, quint64 capacity, const QString& format, QString* error)
{
    if (!ensurePool(error))
        return {};
    PoolHandle storage(pool(error));
    if (!storage.value)
        return {};
    const QString xml = QStringLiteral("<volume><name>%1</name><capacity unit='bytes'>%2</capacity>"
                                       "<allocation unit='bytes'>0</allocation><target><format type='%3'/>"
                                       "<permissions><mode>0640</mode></permissions></target></volume>")
                            .arg(escaped(name))
                            .arg(capacity)
                            .arg(escaped(format));
    VolumeHandle volume(virStorageVolCreateXML(storage, xml.toUtf8().constData(), 0));
    if (!volume.value) {
        *error = QStringLiteral("Не удалось создать том: %1").arg(lastError({}));
        return {};
    }
    char* rawPath = virStorageVolGetPath(volume);
    const QString path = rawPath ? QString::fromUtf8(rawPath) : QString();
    free(rawPath);
    return path;
}

bool LibvirtManager::downloadVolume(const QString& volumePath, const QString& targetPath, QString* error,
                                    const TransferProgress& progress) const
{
    VolumeHandle volume(virStorageVolLookupByPath(m_connection, volumePath.toUtf8().constData()));
    if (!volume.value) {
        *error = QStringLiteral("Не удалось открыть том для резервного копирования: %1").arg(lastError({}));
        return false;
    }
    virStorageVolInfo info{};
    virStorageVolGetInfoFlags(volume, &info, VIR_STORAGE_VOL_GET_PHYSICAL);
    QFile target(targetPath);
    if (!target.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        *error = QStringLiteral("Не удалось создать файл резервной копии");
        return false;
    }
    virStreamPtr stream = virStreamNew(m_connection, 0);
    if (!stream || virStorageVolDownload(volume, stream, 0, 0, VIR_STORAGE_VOL_DOWNLOAD_SPARSE_STREAM) < 0) {
        if (stream)
            virStreamFree(stream);
        *error = QStringLiteral("Не удалось начать чтение тома: %1").arg(lastError({}));
        return false;
    }
    SparseDownloadTarget context{&target, qint64(info.allocation), progress};
    if (virStreamSparseRecvAll(stream, receiveSparseData, receiveSparseHole, &context) < 0) {
        virStreamFree(stream);
        *error = QStringLiteral("Копирование тома прервано: %1").arg(lastError({}));
        return false;
    }
    const qint64 finalSize = target.pos();
    if (virStreamFinish(stream) < 0) {
        virStreamFree(stream);
        *error = QStringLiteral("Libvirt не подтвердил резервную копию: %1").arg(lastError({}));
        return false;
    }
    virStreamFree(stream);
    if (!target.resize(finalSize) || !target.flush()) {
        *error = QStringLiteral("Не удалось завершить файл резервной копии");
        return false;
    }
    return true;
}

bool LibvirtManager::uploadVolume(const QString& sourcePath, virStorageVolPtr volume, QString* error,
                                  const TransferProgress& progress) const
{
    QFile source(sourcePath);
    if (!source.open(QIODevice::ReadOnly)) {
        *error = QStringLiteral("Не удалось открыть диск резервной копии");
        return false;
    }
    virStreamPtr stream = virStreamNew(m_connection, 0);
    if (!stream || virStorageVolUpload(volume, stream, 0, source.size(), 0) < 0) {
        if (stream)
            virStreamFree(stream);
        *error = QStringLiteral("Не удалось начать восстановление тома: %1").arg(lastError({}));
        return false;
    }
    QByteArray buffer(1024 * 1024, Qt::Uninitialized);
    qint64 done = 0;
    while (!source.atEnd()) {
        const qint64 count = source.read(buffer.data(), buffer.size());
        if (count < 0) {
            virStreamAbort(stream);
            virStreamFree(stream);
            *error = QStringLiteral("Не удалось прочитать диск резервной копии");
            return false;
        }
        qint64 offset = 0;
        while (offset < count) {
            const int sent = virStreamSend(stream, buffer.constData() + offset, size_t(count - offset));
            if (sent <= 0) {
                virStreamAbort(stream);
                virStreamFree(stream);
                *error = QStringLiteral("Восстановление тома прервано: %1").arg(lastError({}));
                return false;
            }
            offset += sent;
            done += sent;
            if (progress && !progress(done, source.size())) {
                virStreamAbort(stream);
                virStreamFree(stream);
                *error = QStringLiteral("Восстановление отменено");
                return false;
            }
        }
    }
    if (virStreamFinish(stream) < 0) {
        virStreamFree(stream);
        *error = QStringLiteral("Libvirt не подтвердил восстановление: %1").arg(lastError({}));
        return false;
    }
    virStreamFree(stream);
    return true;
}

QString LibvirtManager::ensureNvramTemplate(QString* error)
{
    if (!ensurePool(error))
        return {};

    PoolHandle storage(pool(error));
    if (!storage.value)
        return {};

    const QString volumeName = QStringLiteral("OVMF_VARS.4m.qcow2");
    const QString volumePath = m_poolPath + QLatin1Char('/') + volumeName;
    if (QFileInfo::exists(volumePath)) {
        VolumeHandle existing(virStorageVolLookupByName(storage, volumeName.toUtf8().constData()));
        if (!existing.value) {
            *error = QStringLiteral("Не удалось открыть шаблон UEFI NVRAM: %1").arg(lastError({}));
            return {};
        }
        char* rawPath = virStorageVolGetPath(existing);
        const QString path = rawPath ? QString::fromUtf8(rawPath) : QString();
        free(rawPath);
        return path;
    }

    const QString qemuImg = QStandardPaths::findExecutable(QStringLiteral("qemu-img"));
    const QString rawTemplate = QStringLiteral("/usr/share/edk2/x64/OVMF_VARS.4m.fd");
    if (qemuImg.isEmpty() || !QFileInfo(rawTemplate).isReadable()) {
        *error = QStringLiteral("Не найден шаблон UEFI NVRAM или программа qemu-img");
        return {};
    }

    QTemporaryDir temporary;
    if (!temporary.isValid()) {
        *error = QStringLiteral("Не удалось подготовить временный файл UEFI NVRAM");
        return {};
    }
    const QString convertedPath = temporary.filePath(QStringLiteral("OVMF_VARS.4m.qcow2"));
    if (QProcess::execute(qemuImg, {QStringLiteral("convert"), QStringLiteral("-f"), QStringLiteral("raw"),
                                    QStringLiteral("-O"), QStringLiteral("qcow2"), rawTemplate, convertedPath}) != 0) {
        *error = QStringLiteral("Не удалось преобразовать шаблон UEFI NVRAM в QCOW2");
        return {};
    }

    QFile source(convertedPath);
    if (!source.open(QIODevice::ReadOnly)) {
        *error = QStringLiteral("Не удалось открыть подготовленный шаблон UEFI NVRAM");
        return {};
    }
    const QString volumeXml = QStringLiteral("<volume><name>%1</name><capacity unit='bytes'>%2</capacity>"
                                             "<allocation unit='bytes'>0</allocation><target><format type='raw'/>"
                                             "<permissions><mode>0640</mode></permissions></target></volume>")
                                  .arg(escaped(volumeName))
                                  .arg(source.size());
    VolumeHandle volume(virStorageVolCreateXML(storage, volumeXml.toUtf8().constData(), 0));
    if (!volume.value) {
        *error = QStringLiteral("Не удалось создать шаблон UEFI NVRAM: %1").arg(lastError({}));
        return {};
    }

    virStreamPtr stream = virStreamNew(m_connection, 0);
    if (!stream || virStorageVolUpload(volume, stream, 0, source.size(), 0) < 0) {
        if (stream)
            virStreamFree(stream);
        virStorageVolDelete(volume, 0);
        *error = QStringLiteral("Не удалось начать сохранение шаблона UEFI NVRAM: %1").arg(lastError({}));
        return {};
    }

    QByteArray buffer(256 * 1024, Qt::Uninitialized);
    bool failed = false;
    while (!source.atEnd() && !failed) {
        const qint64 count = source.read(buffer.data(), buffer.size());
        if (count < 0) {
            failed = true;
            break;
        }
        qint64 offset = 0;
        while (offset < count) {
            const int sent = virStreamSend(stream, buffer.constData() + offset, count - offset);
            if (sent <= 0) {
                failed = true;
                break;
            }
            offset += sent;
        }
    }
    if (failed || virStreamFinish(stream) < 0) {
        virStreamAbort(stream);
        virStreamFree(stream);
        virStorageVolDelete(volume, 0);
        *error = QStringLiteral("Сохранение шаблона UEFI NVRAM прервано: %1").arg(lastError({}));
        return {};
    }
    virStreamFree(stream);

    char* rawPath = virStorageVolGetPath(volume);
    const QString path = rawPath ? QString::fromUtf8(rawPath) : QString();
    free(rawPath);
    if (path.isEmpty())
        *error = QStringLiteral("Libvirt не вернул путь шаблона UEFI NVRAM");
    return path;
}

bool LibvirtManager::validateDomainXml(const QString& xml, QString* error) const
{
    return DomainSafetyPolicy::validate(xml, m_poolPath, error);
}

bool LibvirtManager::createMachine(const QVariantMap& options, QString* error)
{
    if (!isConnected() && !connect(error))
        return false;
    const QString id = QStringLiteral("isora-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    const bool use3d = options.value(QStringLiteral("use3d")).toBool();
    const QString requestedGpu = options.value(QStringLiteral("gpuId"), QStringLiteral("auto")).toString();
    const auto renderDevice = use3d ? (requestedGpu == QStringLiteral("auto") ? RenderDevices::preferred()
                                                                                 : RenderDevices::find(requestedGpu))
                                    : std::nullopt;
    if (use3d && !renderDevice) {
        *error = QStringLiteral("Выбранный DRM render-node для 3D не найден");
        return false;
    }
    const bool useEfi = options.value(QStringLiteral("useEfi")).toBool();
    const QString nvramTemplate = useEfi ? ensureNvramTemplate(error) : QString();
    if (useEfi && nvramTemplate.isEmpty())
        return false;
    const QString diskPath = createDisk(id, qBound(8, options.value(QStringLiteral("diskGiB")).toInt(), 2048), error);
    if (diskPath.isEmpty())
        return false;

    const QString label = escaped(options.value(QStringLiteral("name")).toString());
    const QString isoPath = escaped(options.value(QStringLiteral("isoPath")).toString());
    const int memory = qBound(1024, options.value(QStringLiteral("memoryMiB")).toInt(), 262144);
    const int cpus = qBound(1, options.value(QStringLiteral("cpuCount")).toInt(), 256);
    const QString renderNode = use3d ? escaped(renderDevice->path) : QString();
    const QString nvramPath = QStringLiteral("%1/%2-nvram.qcow2").arg(m_poolPath, id);

    const QString os = useEfi ? QStringLiteral("<os><type arch='x86_64' machine='q35'>hvm</type>"
                                               "<loader readonly='yes' type='pflash' format='raw'>"
                                               "/usr/share/edk2/x64/OVMF_CODE.4m.fd</loader>"
                                               "<nvram template='%1' templateFormat='qcow2' format='qcow2'>%2</nvram>"
                                               "<boot dev='cdrom'/><boot dev='hd'/><bootmenu enable='yes'/></os>")
                                    .arg(escaped(nvramTemplate), escaped(nvramPath))
                              : QStringLiteral("<os><type arch='x86_64' machine='q35'>hvm</type>"
                                               "<boot dev='cdrom'/><boot dev='hd'/><bootmenu enable='yes'/></os>");
    QString graphics;
    QString displayChannel;
    if (use3d) {
        graphics = QStringLiteral("<graphics type='spice' autoport='yes'><listen type='none'/>"
                                  "<image compression='off'/><gl enable='yes' rendernode='%1'/></graphics>"
                                  "<video><model type='virtio' heads='1' primary='yes'>"
                                  "<acceleration accel3d='yes'/></model></video>")
                       .arg(renderNode);
        displayChannel =
            QStringLiteral("<channel type='spicevmc'><target type='virtio' name='com.redhat.spice.0'/></channel>");
    } else {
        graphics = QStringLiteral("<graphics type='spice' autoport='yes'><listen type='none'/></graphics>"
                                  "<video><model type='virtio' heads='1' primary='yes'/></video>");
        displayChannel =
            QStringLiteral("<channel type='spicevmc'><target type='virtio' name='com.redhat.spice.0'/></channel>");
    }
    const QString network =
        QStandardPaths::findExecutable(QStringLiteral("passt")).isEmpty()
            ? QStringLiteral("<interface type='user'><model type='virtio'/></interface>")
            : QStringLiteral("<interface type='user'><backend type='passt'/><model type='virtio'/></interface>");

    const QString xml =
        QStringLiteral(
            "<domain type='kvm'><name>%1</name><title>%2</title>"
            "<metadata><isora:machine xmlns:isora='https://github.com/ll-host/Isora'>"
            "<isora:managed>true</isora:managed></isora:machine>"
            "<isora:display xmlns:isora='https://github.com/ll-host/Isora' mode='%11' gpu='%12'/></metadata>"
            "<memory unit='MiB'>%4</memory><currentMemory unit='MiB'>%4</currentMemory><vcpu>%5</vcpu>"
            "%6<features><acpi/><apic/></features><cpu mode='host-passthrough' check='none'/>"
            "<clock offset='utc'/><on_poweroff>destroy</on_poweroff><on_reboot>restart</on_reboot>"
            "<on_crash>preserve</on_crash><devices><emulator>/usr/bin/qemu-system-x86_64</emulator>"
            "<disk type='file' device='disk'><driver name='qemu' type='qcow2' discard='unmap'/>"
            "<source file='%3'/><target dev='vda' bus='virtio'/></disk>"
            "<disk type='file' device='cdrom'><driver name='qemu' type='raw'/><source file='%7'/>"
            "<target dev='sda' bus='sata'/><readonly/></disk>"
            "<controller type='usb' model='qemu-xhci'/><controller type='sata' index='0'/>"
            "%8%9<input type='tablet' bus='usb'/><input type='keyboard' bus='usb'/>"
            "<channel type='unix'><target type='virtio' name='org.qemu.guest_agent.0'/></channel>"
            "%10"
            "<serial type='pty'><target type='isa-serial' port='0'/></serial>"
            "<console type='pty'><target type='serial' port='0'/></console>"
            "<memballoon model='virtio'/><rng model='virtio'><backend model='random'>/dev/urandom</backend></rng>"
            "</devices></domain>")
            .arg(id, label, escaped(diskPath))
            .arg(memory)
            .arg(cpus)
            .arg(os)
            .arg(isoPath)
            .arg(graphics)
            .arg(network)
            .arg(displayChannel)
            .arg(escaped(options.value(QStringLiteral("displayMode"), QStringLiteral("windowed")).toString()))
            .arg(escaped(requestedGpu));

    if (!validateDomainXml(xml, error)) {
        QString cleanupError;
        deleteVolumeByPath(diskPath, &cleanupError);
        return false;
    }
    DomainHandle created(virDomainDefineXML(m_connection, xml.toUtf8().constData()));
    if (!created.value) {
        const QString defineError = lastError(QStringLiteral("libvirt отклонил конфигурацию без описания причины"));
        QString cleanupError;
        deleteVolumeByPath(diskPath, &cleanupError);
        *error = QStringLiteral("Не удалось определить виртуальную машину: %1").arg(defineError);
        return false;
    }
    return true;
}

bool LibvirtManager::importExistingMachine(const QString&, const QString&, int, int, QString* error)
{
    *error = QStringLiteral("Импорт внешнего диска пока поддерживается только Windows backend");
    return false;
}

QString LibvirtManager::stateText(int state)
{
    switch (state) {
    case VIR_DOMAIN_RUNNING:
        return QStringLiteral("Запущена");
    case VIR_DOMAIN_BLOCKED:
        return QStringLiteral("Ожидание");
    case VIR_DOMAIN_PAUSED:
        return QStringLiteral("Приостановлена");
    case VIR_DOMAIN_SHUTDOWN:
        return QStringLiteral("Выключается");
    case VIR_DOMAIN_SHUTOFF:
        return QStringLiteral("Выключена");
    case VIR_DOMAIN_CRASHED:
        return QStringLiteral("Аварийно завершена");
    case VIR_DOMAIN_PMSUSPENDED:
        return QStringLiteral("Спит");
    default:
        return QStringLiteral("Неизвестно");
    }
}

QVariantList LibvirtManager::domains(QString* error) const
{
    QVariantList result;
    if (!m_connection)
        return result;
    virDomainPtr* items = nullptr;
    const int count = virConnectListAllDomains(m_connection, &items,
                                               VIR_CONNECT_LIST_DOMAINS_ACTIVE | VIR_CONNECT_LIST_DOMAINS_INACTIVE);
    if (count < 0) {
        *error = lastError(QStringLiteral("Не удалось получить список виртуальных машин"));
        return result;
    }
    for (int index = 0; index < count; ++index) {
        DomainHandle item(items[index]);
        const QString id = QString::fromUtf8(virDomainGetName(item));
        if (!id.startsWith(QStringLiteral("isora-")))
            continue;
        char* rawXml = virDomainGetXMLDesc(item, VIR_DOMAIN_XML_INACTIVE);
        const QString xml = rawXml ? QString::fromUtf8(rawXml) : QString();
        free(rawXml);
        if (!xml.contains(QStringLiteral("https://github.com/ll-host/Isora")))
            continue;

        QDomDocument document;
        document.setContent(xml);
        const QDomElement root = document.documentElement();
        int state = VIR_DOMAIN_NOSTATE;
        int reason = 0;
        virDomainGetState(item, &state, &reason, 0);
        const QString label = xmlText(root, QStringLiteral("title"));
        const QString diskPath = primaryDiskPath(root);
        const qint64 machineMemoryMiB = memoryMiB(root);
        const int cpuCount = xmlText(root, QStringLiteral("vcpu")).toInt();
        int diskGiB = 0;
        VolumeHandle disk(virStorageVolLookupByPath(m_connection, diskPath.toUtf8().constData()));
        virStorageVolInfo diskInfo{};
        if (disk.value && virStorageVolGetInfo(disk, &diskInfo) == 0)
            diskGiB = int((diskInfo.capacity + 1073741823ULL) / 1073741824ULL);
        QStringList resources;
        if (machineMemoryMiB > 0)
            resources.append(machineMemoryMiB % 1024 == 0 ? QStringLiteral("%1 ГиБ").arg(machineMemoryMiB / 1024)
                                                          : QStringLiteral("%1 МиБ").arg(machineMemoryMiB));
        if (cpuCount > 0)
            resources.append(QStringLiteral("%1 CPU").arg(cpuCount));
        if (diskGiB > 0)
            resources.append(QStringLiteral("диск %1 ГиБ").arg(diskGiB));
        result.append(QVariantMap{{QStringLiteral("id"), id},
                                  {QStringLiteral("name"), label.isEmpty() ? id : label},
                                  {QStringLiteral("state"), stateText(state)},
                                  {QStringLiteral("running"), virDomainIsActive(item) == 1},
                                  {QStringLiteral("diskPath"), diskPath},
                                  {QStringLiteral("memoryMiB"), machineMemoryMiB},
                                  {QStringLiteral("cpuCount"), cpuCount},
                                  {QStringLiteral("diskGiB"), diskGiB},
                                  {QStringLiteral("useEfi"), !nvramPath(root).isEmpty()},
                                  {QStringLiteral("use3d"), domainUses3d(document)},
                                  {QStringLiteral("displayMode"), displayMetadata(document, QStringLiteral("mode"), QStringLiteral("windowed"))},
                                  {QStringLiteral("gpuId"), displayMetadata(document, QStringLiteral("gpu"), QStringLiteral("auto"))},
                                  {QStringLiteral("resources"), resources.join(QStringLiteral("  ·  "))},
                                  {QStringLiteral("snapshots"), virDomainSnapshotNum(item, 0)}});
    }
    free(items);
    return result;
}

QVariantMap LibvirtManager::machineDetails(const QString& id, QString* error) const
{
    const QVariantList items = domains(error);
    for (const QVariant& item : items) {
        const QVariantMap machine = item.toMap();
        if (machine.value(QStringLiteral("id")).toString() == id)
            return machine;
    }
    if (error->isEmpty())
        *error = QStringLiteral("Виртуальная машина не найдена");
    return {};
}

bool LibvirtManager::updateMachineResources(const QString& id, int requestedMemoryMiB, int requestedCpuCount,
                                            int requestedDiskGiB, QString* error)
{
    DomainHandle item(domain(id, error));
    if (!item.value)
        return false;
    if (virDomainIsActive(item) == 1) {
        *error = QStringLiteral("Сначала полностью выключите виртуальную машину");
        return false;
    }
    const int newMemoryMiB = qBound(1024, requestedMemoryMiB, 262144);
    const int newCpuCount = qBound(1, requestedCpuCount, 256);
    const int newDiskGiB = qBound(8, requestedDiskGiB, 2048);

    char* rawXml = virDomainGetXMLDesc(item, VIR_DOMAIN_XML_INACTIVE);
    const QString oldXml = rawXml ? QString::fromUtf8(rawXml) : QString();
    free(rawXml);
    QDomDocument document;
    if (!document.setContent(oldXml)) {
        *error = QStringLiteral("Не удалось прочитать параметры виртуальной машины");
        return false;
    }
    QDomElement root = document.documentElement();
    for (const QString& tag : {QStringLiteral("memory"), QStringLiteral("currentMemory")}) {
        QDomElement element = root.firstChildElement(tag);
        if (element.isNull()) {
            element = document.createElement(tag);
            root.insertBefore(element, root.firstChildElement(QStringLiteral("vcpu")));
        }
        element.setAttribute(QStringLiteral("unit"), QStringLiteral("MiB"));
        while (!element.firstChild().isNull())
            element.removeChild(element.firstChild());
        element.appendChild(document.createTextNode(QString::number(newMemoryMiB)));
    }
    QDomElement vcpu = root.firstChildElement(QStringLiteral("vcpu"));
    while (!vcpu.firstChild().isNull())
        vcpu.removeChild(vcpu.firstChild());
    vcpu.appendChild(document.createTextNode(QString::number(newCpuCount)));
    const QString updatedXml = document.toString(-1);
    if (!validateDomainXml(updatedXml, error))
        return false;

    const QString diskPath = primaryDiskPath(root);
    VolumeHandle disk(virStorageVolLookupByPath(m_connection, diskPath.toUtf8().constData()));
    if (!disk.value) {
        *error = QStringLiteral("Не удалось открыть виртуальный диск: %1").arg(lastError({}));
        return false;
    }
    virStorageVolInfo info{};
    if (virStorageVolGetInfo(disk, &info) < 0) {
        *error = QStringLiteral("Не удалось определить размер виртуального диска: %1").arg(lastError({}));
        return false;
    }
    const quint64 requestedBytes = quint64(newDiskGiB) * 1073741824ULL;
    if (requestedBytes < info.capacity) {
        *error = QStringLiteral("Уменьшение виртуального диска не поддерживается");
        return false;
    }

    DomainHandle updated(virDomainDefineXML(m_connection, updatedXml.toUtf8().constData()));
    if (!updated.value) {
        *error = QStringLiteral("Libvirt отклонил новые параметры: %1").arg(lastError({}));
        return false;
    }
    if (requestedBytes > info.capacity && virStorageVolResize(disk, requestedBytes, 0) < 0) {
        DomainHandle rollback(virDomainDefineXML(m_connection, oldXml.toUtf8().constData()));
        Q_UNUSED(rollback);
        *error =
            QStringLiteral("Не удалось увеличить виртуальный диск; CPU и память не изменены: %1").arg(lastError({}));
        return false;
    }
    return true;
}

bool LibvirtManager::updateMachineGraphics(const QString& id, const QString& displayMode, const QString& gpuId,
                                           bool use3d, QString* error)
{
    if (!validDisplayMode(displayMode)) {
        *error = QStringLiteral("Неподдерживаемый режим экрана");
        return false;
    }
    DomainHandle item(domain(id, error));
    if (!item.value)
        return false;
    char* rawXml = virDomainGetXMLDesc(item, VIR_DOMAIN_XML_INACTIVE);
    const QString oldXml = rawXml ? QString::fromUtf8(rawXml) : QString();
    free(rawXml);

    std::optional<RenderDevices::Device> renderDevice;
    if (use3d) {
        renderDevice = gpuId == QStringLiteral("auto") ? RenderDevices::preferred() : RenderDevices::find(gpuId);
        if (!renderDevice) {
            *error = QStringLiteral("Выбранный DRM render-node недоступен");
            return false;
        }
    }
    QString updatedXml = use3d ? normalize3dDisplay(oldXml, renderDevice->path) : normalize2dDisplay(oldXml);
    QDomDocument document;
    if (!document.setContent(updatedXml)) {
        *error = QStringLiteral("Не удалось изменить графическую конфигурацию");
        return false;
    }
    setDisplayMetadata(&document, displayMode, gpuId);
    updatedXml = document.toString(-1);
    if (!validateDomainXml(updatedXml, error))
        return false;
    DomainHandle updated(virDomainDefineXML(m_connection, updatedXml.toUtf8().constData()));
    if (!updated.value) {
        *error = QStringLiteral("Libvirt отклонил графическую конфигурацию: %1").arg(lastError({}));
        return false;
    }
    return true;
}

virDomainPtr LibvirtManager::domain(const QString& id, QString* error) const
{
    if (!id.startsWith(QStringLiteral("isora-"))) {
        *error = QStringLiteral("Isora не управляет этой виртуальной машиной");
        return nullptr;
    }
    virDomainPtr result = virDomainLookupByName(m_connection, id.toUtf8().constData());
    if (!result)
        *error = QStringLiteral("Виртуальная машина не найдена");
    return result;
}

bool LibvirtManager::start(const QString& id, QString* error)
{
    DomainHandle item(domain(id, error));
    if (!item.value)
        return false;
    if (virDomainIsActive(item) == 1)
        return true;

    char* rawXml = virDomainGetXMLDesc(item, VIR_DOMAIN_XML_INACTIVE);
    const QString currentXml = rawXml ? QString::fromUtf8(rawXml) : QString();
    free(rawXml);
    QDomDocument document;
    document.setContent(currentXml);
    QString upgradedXml = currentXml;
    if (domainUses3d(document)) {
        const QString gpuId = displayMetadata(document, QStringLiteral("gpu"), QStringLiteral("auto"));
        const auto renderDevice = gpuId == QStringLiteral("auto") ? RenderDevices::preferred() : RenderDevices::find(gpuId);
        if (!renderDevice) {
            *error = QStringLiteral("Выбранный DRM render-node для 3D не найден");
            return false;
        }
        upgradedXml = normalize3dDisplay(currentXml, renderDevice->path);
    }

    const auto retryWithout3d = [this, &document, &currentXml, error](const QString& startError) {
        if (!domainUses3d(document) || !isEglInitializationError(startError)) {
            *error = QStringLiteral("Не удалось запустить машину: %1").arg(startError);
            return false;
        }

        const QString fallbackXml = normalize2dDisplay(currentXml);
        if (!validateDomainXml(fallbackXml, error))
            return false;
        DomainHandle fallback(virDomainDefineXML(m_connection, fallbackXml.toUtf8().constData()));
        if (!fallback.value) {
            *error = QStringLiteral("Аппаратное 3D недоступно (%1). Не удалось включить безопасный режим 2D: %2")
                         .arg(startError, lastError({}));
            return false;
        }
        if (virDomainCreate(fallback) < 0) {
            *error = QStringLiteral("Аппаратное 3D недоступно (%1). Запуск в режиме 2D также завершился ошибкой: %2")
                         .arg(startError, lastError({}));
            return false;
        }
        return true;
    };

    if (upgradedXml != currentXml) {
        if (!validateDomainXml(upgradedXml, error))
            return false;
        DomainHandle upgraded(virDomainDefineXML(m_connection, upgradedXml.toUtf8().constData()));
        if (!upgraded.value) {
            *error = QStringLiteral("Не удалось обновить графический режим: %1").arg(lastError({}));
            return false;
        }
        if (virDomainCreate(upgraded) < 0) {
            const QString startError = lastError(QStringLiteral("неизвестная ошибка запуска"));
            return retryWithout3d(startError);
        }
        return true;
    }
    if (virDomainCreate(item) < 0) {
        const QString startError = lastError(QStringLiteral("неизвестная ошибка запуска"));
        return retryWithout3d(startError);
    }
    return true;
}

bool LibvirtManager::startFromDisk(const QString& id, QString* error)
{
    DomainHandle item(domain(id, error));
    if (!item.value)
        return false;
    if (virDomainIsActive(item) == 1)
        return true;

    char* rawXml = virDomainGetXMLDesc(item, VIR_DOMAIN_XML_INACTIVE);
    QDomDocument document;
    const bool parsed = rawXml && document.setContent(QString::fromUtf8(rawXml));
    free(rawXml);
    if (!parsed) {
        *error = QStringLiteral("Не удалось прочитать конфигурацию машины");
        return false;
    }

    QDomElement os = document.documentElement().firstChildElement(QStringLiteral("os"));
    if (os.isNull()) {
        *error = QStringLiteral("В конфигурации машины отсутствует раздел загрузки");
        return false;
    }
    for (QDomElement boot = os.firstChildElement(QStringLiteral("boot")); !boot.isNull();) {
        const QDomElement next = boot.nextSiblingElement(QStringLiteral("boot"));
        os.removeChild(boot);
        boot = next;
    }
    QDomElement diskBoot = document.createElement(QStringLiteral("boot"));
    diskBoot.setAttribute(QStringLiteral("dev"), QStringLiteral("hd"));
    const QDomElement bootMenu = os.firstChildElement(QStringLiteral("bootmenu"));
    if (bootMenu.isNull())
        os.appendChild(diskBoot);
    else
        os.insertBefore(diskBoot, bootMenu);

    const QString updatedXml = document.toString(-1);
    if (!validateDomainXml(updatedXml, error))
        return false;
    DomainHandle updated(virDomainDefineXML(m_connection, updatedXml.toUtf8().constData()));
    if (!updated.value) {
        *error = QStringLiteral("Не удалось выбрать загрузку с диска: %1").arg(lastError({}));
        return false;
    }
    return start(id, error);
}

bool LibvirtManager::shutdown(const QString& id, QString* error)
{
    DomainHandle item(domain(id, error));
    if (!item.value)
        return false;
    if (virDomainIsActive(item) != 1)
        return true;
    if (virDomainShutdown(item) < 0) {
        *error = QStringLiteral("Гостевая система не приняла запрос завершения: %1").arg(lastError({}));
        return false;
    }
    return true;
}

bool LibvirtManager::reset(const QString& id, QString* error)
{
    DomainHandle item(domain(id, error));
    if (!item.value)
        return false;
    if (virDomainIsActive(item) != 1) {
        *error = QStringLiteral("Виртуальная машина выключена");
        return false;
    }
    if (virDomainReset(item, 0) < 0) {
        *error = QStringLiteral("Не удалось перезагрузить машину: %1").arg(lastError({}));
        return false;
    }
    return true;
}

bool LibvirtManager::forceStop(const QString& id, QString* error)
{
    DomainHandle item(domain(id, error));
    if (!item.value)
        return false;
    if (virDomainIsActive(item) != 1)
        return true;
    if (virDomainDestroy(item) < 0) {
        *error = QStringLiteral("Не удалось принудительно остановить машину: %1").arg(lastError({}));
        return false;
    }
    return true;
}

bool LibvirtManager::removeMachine(const QString& id, bool removeDisk, QString* error)
{
    DomainHandle item(domain(id, error));
    if (!item.value)
        return false;
    if (virDomainIsActive(item) == 1) {
        *error = QStringLiteral("Сначала полностью остановите виртуальную машину");
        return false;
    }
    char* rawXml = virDomainGetXMLDesc(item, VIR_DOMAIN_XML_INACTIVE);
    const QString xml = rawXml ? QString::fromUtf8(rawXml) : QString();
    free(rawXml);
    if (!xml.contains(QStringLiteral("https://github.com/ll-host/Isora"))) {
        *error = QStringLiteral("Отказано в удалении чужой виртуальной машины");
        return false;
    }
    QDomDocument document;
    document.setContent(xml);
    const QString diskPath = primaryDiskPath(document.documentElement());
    unsigned int flags =
        VIR_DOMAIN_UNDEFINE_MANAGED_SAVE | VIR_DOMAIN_UNDEFINE_SNAPSHOTS_METADATA | VIR_DOMAIN_UNDEFINE_NVRAM;
    if (virDomainUndefineFlags(item, flags) < 0) {
        *error = QStringLiteral("Не удалось удалить описание машины: %1").arg(lastError({}));
        return false;
    }
    if (removeDisk && !diskPath.isEmpty())
        return deleteVolumeByPath(diskPath, error);
    return true;
}

bool LibvirtManager::openDisplay(const QString& id, QString* error) const
{
    DomainHandle item(domain(id, error));
    if (!item.value)
        return false;
    if (virDomainIsActive(item) != 1) {
        *error = QStringLiteral("Сначала запустите виртуальную машину");
        return false;
    }

    QProcess viewer;
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    const QStringList offloadVariables{QStringLiteral("__NV_PRIME_RENDER_OFFLOAD"),
                                       QStringLiteral("__NV_PRIME_RENDER_OFFLOAD_PROVIDER"),
                                       QStringLiteral("__GLX_VENDOR_LIBRARY_NAME"),
                                       QStringLiteral("__VK_LAYER_NV_optimus"),
                                       QStringLiteral("VK_ICD_FILENAMES"),
                                       QStringLiteral("GBM_BACKEND"),
                                       QStringLiteral("DRI_PRIME"),
                                       QStringLiteral("GDK_BACKEND")};
    for (const QString& name : offloadVariables)
        environment.remove(name);
    if (environment.value(QStringLiteral("XDG_SESSION_TYPE")) == QStringLiteral("wayland") &&
        !environment.value(QStringLiteral("WAYLAND_DISPLAY")).isEmpty()) {
        environment.insert(QStringLiteral("GDK_BACKEND"), QStringLiteral("wayland"));
    }
    viewer.setProcessEnvironment(environment);
    char* rawXml = virDomainGetXMLDesc(item, VIR_DOMAIN_XML_INACTIVE);
    QDomDocument document;
    document.setContent(rawXml ? QString::fromUtf8(rawXml) : QString());
    free(rawXml);
    const QString displayMode = displayMetadata(document, QStringLiteral("mode"), QStringLiteral("windowed"));
    const QString gpuId = displayMetadata(document, QStringLiteral("gpu"), QStringLiteral("auto"));
    QString program = QStringLiteral("virt-viewer");
    QStringList arguments{QStringLiteral("--connect"), connectionUri(), QStringLiteral("--attach"), id};
    if (displayMode == QStringLiteral("fullscreen"))
        arguments.prepend(QStringLiteral("--full-screen"));
    else if (displayMode == QStringLiteral("borderless"))
        arguments = QStringList{QStringLiteral("--kiosk"), QStringLiteral("--kiosk-quit"),
                                QStringLiteral("on-disconnect")} + arguments;
    if (gpuId != QStringLiteral("auto")) {
        const auto selected = RenderDevices::find(gpuId);
        const QList<RenderDevices::Device> devices = RenderDevices::all();
        if (selected && selected->name.contains(QStringLiteral("NVIDIA"), Qt::CaseInsensitive) &&
            !QStandardPaths::findExecutable(QStringLiteral("prime-run")).isEmpty()) {
            arguments.prepend(program);
            program = QStringLiteral("prime-run");
        } else if (selected && !devices.isEmpty() && selected->id != devices.constFirst().id) {
            environment.insert(QStringLiteral("DRI_PRIME"), QStringLiteral("1"));
            viewer.setProcessEnvironment(environment);
        }
    }
    viewer.setProgram(program);
    viewer.setArguments(arguments);
    if (!viewer.startDetached()) {
        *error = QStringLiteral("Не удалось запустить virt-viewer");
        return false;
    }
    return true;
}

QVariantList LibvirtManager::snapshots(const QString& id, QString* error) const
{
    QVariantList result;
    DomainHandle item(domain(id, error));
    if (!item.value)
        return result;
    virDomainSnapshotPtr* items = nullptr;
    const int count = virDomainListAllSnapshots(item, &items, 0);
    if (count < 0) {
        *error = QStringLiteral("Не удалось получить снимки состояния: %1").arg(lastError({}));
        return result;
    }
    for (int index = 0; index < count; ++index) {
        SnapshotHandle snapshot(items[index]);
        char* rawXml = virDomainSnapshotGetXMLDesc(snapshot, 0);
        const QString xml = rawXml ? QString::fromUtf8(rawXml) : QString();
        free(rawXml);
        QDomDocument document;
        document.setContent(xml);
        const QDomElement root = document.documentElement();
        const qint64 created = xmlText(root, QStringLiteral("creationTime")).toLongLong();
        result.append(QVariantMap{{QStringLiteral("name"), QString::fromUtf8(virDomainSnapshotGetName(snapshot))},
                                  {QStringLiteral("createdAt"),
                                   QDateTime::fromSecsSinceEpoch(created).toString(QStringLiteral("dd.MM.yyyy HH:mm"))},
                                  {QStringLiteral("state"), xmlText(root, QStringLiteral("state"))}});
    }
    free(items);
    return result;
}

bool LibvirtManager::createSnapshot(const QString& id, const QString& name, QString* error)
{
    DomainHandle item(domain(id, error));
    if (!item.value)
        return false;
    const QString cleanName = name.trimmed();
    if (cleanName.isEmpty()) {
        *error = QStringLiteral("Введите название снимка");
        return false;
    }
    const QString xml =
        QStringLiteral("<domainsnapshot><name>%1</name><description>Создано Isora</description></domainsnapshot>")
            .arg(escaped(cleanName));
    SnapshotHandle snapshot(virDomainSnapshotCreateXML(item, xml.toUtf8().constData(), 0));
    if (!snapshot.value) {
        *error = QStringLiteral("Не удалось создать снимок: %1").arg(lastError({}));
        return false;
    }
    return true;
}

bool LibvirtManager::revertSnapshot(const QString& id, const QString& name, QString* error)
{
    DomainHandle item(domain(id, error));
    if (!item.value)
        return false;
    SnapshotHandle snapshot(virDomainSnapshotLookupByName(item, name.toUtf8().constData(), 0));
    if (!snapshot.value || virDomainRevertToSnapshot(snapshot, 0) < 0) {
        *error = QStringLiteral("Не удалось восстановить состояние: %1").arg(lastError({}));
        return false;
    }
    return true;
}

bool LibvirtManager::removeSnapshot(const QString& id, const QString& name, QString* error)
{
    DomainHandle item(domain(id, error));
    if (!item.value)
        return false;
    SnapshotHandle snapshot(virDomainSnapshotLookupByName(item, name.toUtf8().constData(), 0));
    if (!snapshot.value || virDomainSnapshotDelete(snapshot, 0) < 0) {
        *error = QStringLiteral("Не удалось удалить снимок: %1").arg(lastError({}));
        return false;
    }
    return true;
}

QVariantList LibvirtManager::backups(const QString& id, const QString& backupRoot, QString* error) const
{
    QVariantList result;
    QDir root(backupRoot);
    if (!root.exists())
        return result;
    const QFileInfoList entries =
        root.entryInfoList({QStringLiteral("*.kvmbackup")}, QDir::Dirs | QDir::NoDotAndDotDot, QDir::Time);
    for (const QFileInfo& entry : entries) {
        QString metadataError;
        const QJsonObject metadata = readMetadata(entry.absoluteFilePath(), &metadataError);
        if (!metadataError.isEmpty() || metadata.value(QStringLiteral("machineId")).toString() != id)
            continue;
        const QFileInfo disk(QDir(entry.absoluteFilePath()).filePath(QStringLiteral("disk.qcow2")));
        const QFileInfo nvram(QDir(entry.absoluteFilePath()).filePath(QStringLiteral("nvram.qcow2")));
        const qint64 bytes = (disk.exists() ? disk.size() : 0) + (nvram.exists() ? nvram.size() : 0);
        result.append(QVariantMap{{QStringLiteral("path"), entry.absoluteFilePath()},
                                  {QStringLiteral("name"), metadata.value(QStringLiteral("name")).toString()},
                                  {QStringLiteral("createdAt"), metadata.value(QStringLiteral("createdAt")).toString()},
                                  {QStringLiteral("sizeBytes"), bytes},
                                  {QStringLiteral("sizeText"),
                                   bytes >= 1073741824LL ? QStringLiteral("%1 ГиБ").arg(bytes / 1073741824.0, 0, 'f', 1)
                                                         : QStringLiteral("%1 МиБ").arg(bytes / 1048576.0, 0, 'f', 1)},
                                  {QStringLiteral("valid"), disk.isFile()}});
    }
    Q_UNUSED(error);
    return result;
}

QString LibvirtManager::createBackup(const QString& id, const QString& backupRoot, QString* error,
                                     const TransferProgress& progress)
{
    if (!ensurePool(error))
        return {};
    DomainHandle item(domain(id, error));
    if (!item.value)
        return {};
    if (virDomainIsActive(item) == 1) {
        *error = QStringLiteral("Для резервного копирования полностью выключите виртуальную машину");
        return {};
    }
    char* rawXml = virDomainGetXMLDesc(item, VIR_DOMAIN_XML_INACTIVE);
    const QString xml = rawXml ? QString::fromUtf8(rawXml) : QString();
    free(rawXml);
    QDomDocument document;
    if (!document.setContent(xml)) {
        *error = QStringLiteral("Не удалось прочитать конфигурацию виртуальной машины");
        return {};
    }
    const QDomElement rootElement = document.documentElement();
    const QString diskPath = primaryDiskPath(rootElement);
    const QString machineNvramPath = nvramPath(rootElement);
    VolumeHandle disk(virStorageVolLookupByPath(m_connection, diskPath.toUtf8().constData()));
    virStorageVolInfo diskInfo{};
    if (!disk.value || virStorageVolGetInfoFlags(disk, &diskInfo, VIR_STORAGE_VOL_GET_PHYSICAL) < 0) {
        *error = QStringLiteral("Не удалось определить размер виртуального диска: %1").arg(lastError({}));
        return {};
    }
    QDir rootDirectory(backupRoot);
    if (!rootDirectory.mkpath(QStringLiteral("."))) {
        *error = QStringLiteral("Не удалось создать каталог резервных копий");
        return {};
    }
    QStorageInfo storage(rootDirectory.absolutePath());
    if (storage.isValid() && storage.bytesAvailable() < qint64(diskInfo.allocation) + 128LL * 1024LL * 1024LL) {
        *error = QStringLiteral("Недостаточно места для резервной копии");
        return {};
    }

    const QString label = xmlText(rootElement, QStringLiteral("title"));
    const QString stamp = QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyyMMdd-HHmmss"));
    const QString baseName =
        QStringLiteral("%1-%2-%3.kvmbackup")
            .arg(safeFilePart(label), stamp, QUuid::createUuid().toString(QUuid::WithoutBraces).left(8));
    const QString finalPath = rootDirectory.filePath(baseName);
    const QString partialPath =
        rootDirectory.filePath(QStringLiteral(".partial-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces)));
    QDir partial;
    if (!partial.mkpath(partialPath)) {
        *error = QStringLiteral("Не удалось подготовить резервную копию");
        return {};
    }
    const auto fail = [&](const QString& message) {
        QDir(partialPath).removeRecursively();
        *error = message;
        return QString();
    };
    const QString diskBackup = QDir(partialPath).filePath(QStringLiteral("disk.qcow2"));
    QString transferError;
    if (!downloadVolume(diskPath, diskBackup, &transferError, progress))
        return fail(transferError);
    VolumeHandle nvramVolume(machineNvramPath.isEmpty()
                                 ? nullptr
                                 : virStorageVolLookupByPath(m_connection, machineNvramPath.toUtf8().constData()));
    if (nvramVolume.value) {
        const QString nvramBackup = QDir(partialPath).filePath(QStringLiteral("nvram.qcow2"));
        if (!downloadVolume(machineNvramPath, nvramBackup, &transferError, {}))
            return fail(transferError);
    }
    const QString hash = fileSha256(diskBackup, &transferError);
    if (hash.isEmpty())
        return fail(transferError);
    const int cpuCount = xmlText(rootElement, QStringLiteral("vcpu")).toInt();
    const int diskGiB = int((diskInfo.capacity + 1073741823ULL) / 1073741824ULL);
    const QJsonObject metadata{{QStringLiteral("formatVersion"), 1},
                               {QStringLiteral("machineId"), id},
                               {QStringLiteral("name"), label.isEmpty() ? id : label},
                               {QStringLiteral("createdAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},
                               {QStringLiteral("memoryMiB"), memoryMiB(rootElement)},
                               {QStringLiteral("cpuCount"), cpuCount},
                               {QStringLiteral("diskGiB"), diskGiB},
                               {QStringLiteral("useEfi"), !machineNvramPath.isEmpty()},
                               {QStringLiteral("use3d"), domainUses3d(document)},
                               {QStringLiteral("diskSha256"), hash}};
    QFile metadataFile(QDir(partialPath).filePath(QStringLiteral("metadata.json")));
    if (!metadataFile.open(QIODevice::WriteOnly | QIODevice::Truncate) ||
        metadataFile.write(QJsonDocument(metadata).toJson(QJsonDocument::Indented)) < 0 || !metadataFile.flush())
        return fail(QStringLiteral("Не удалось записать метаданные резервной копии"));
    metadataFile.close();
    if (!rootDirectory.rename(partialPath, finalPath))
        return fail(QStringLiteral("Не удалось завершить резервную копию"));
    if (progress)
        progress(qint64(diskInfo.allocation), qint64(diskInfo.allocation));
    return finalPath;
}

bool LibvirtManager::verifyBackup(const QString& backupPath, QString* error, const TransferProgress& progress) const
{
    const QJsonObject metadata = readMetadata(backupPath, error);
    if (!error->isEmpty())
        return false;
    const QString diskPath = QDir(backupPath).filePath(QStringLiteral("disk.qcow2"));
    if (!QFileInfo(diskPath).isFile()) {
        *error = QStringLiteral("В резервной копии нет disk.qcow2");
        return false;
    }
    const QString expectedHash = metadata.value(QStringLiteral("diskSha256")).toString();
    const QString actualHash = fileSha256(diskPath, error, progress);
    if (actualHash.isEmpty())
        return false;
    if (actualHash != expectedHash) {
        *error = QStringLiteral("Контрольная сумма диска не совпадает; копия повреждена");
        return false;
    }
    const QString qemuImg = QStandardPaths::findExecutable(QStringLiteral("qemu-img"));
    QProcess check;
    check.start(qemuImg, {QStringLiteral("check"), QStringLiteral("-q"), diskPath});
    if (qemuImg.isEmpty() || !check.waitForFinished(-1) || check.exitStatus() != QProcess::NormalExit ||
        check.exitCode() != 0) {
        *error = QStringLiteral("QCOW2-диск резервной копии не прошёл проверку");
        return false;
    }
    return true;
}

bool LibvirtManager::restoreBackup(const QString& id, const QString& backupPath, QString* error,
                                   const TransferProgress& progress)
{
    if (!verifyBackup(backupPath, error, {}))
        return false;
    const QJsonObject metadata = readMetadata(backupPath, error);
    if (metadata.value(QStringLiteral("machineId")).toString() != id) {
        *error = QStringLiteral("Эта резервная копия создана для другой виртуальной машины");
        return false;
    }
    DomainHandle item(domain(id, error));
    if (!item.value)
        return false;
    if (virDomainIsActive(item) == 1) {
        *error = QStringLiteral("Для восстановления полностью выключите виртуальную машину");
        return false;
    }
    char* rawXml = virDomainGetXMLDesc(item, VIR_DOMAIN_XML_INACTIVE);
    const QString oldXml = rawXml ? QString::fromUtf8(rawXml) : QString();
    free(rawXml);
    QDomDocument document;
    if (!document.setContent(oldXml)) {
        *error = QStringLiteral("Не удалось прочитать конфигурацию виртуальной машины");
        return false;
    }
    QDomElement root = document.documentElement();
    const QString oldDiskPath = primaryDiskPath(root);
    const QString oldNvramPath = nvramPath(root);
    const quint64 capacity = quint64(metadata.value(QStringLiteral("diskGiB")).toInt()) * 1073741824ULL;
    const QString suffix = QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    const QString newDiskPath =
        createVolume(QStringLiteral("%1-restore-%2.qcow2").arg(id, suffix), capacity, QStringLiteral("qcow2"), error);
    if (newDiskPath.isEmpty())
        return false;
    VolumeHandle newDisk(virStorageVolLookupByPath(m_connection, newDiskPath.toUtf8().constData()));
    if (!newDisk.value ||
        !uploadVolume(QDir(backupPath).filePath(QStringLiteral("disk.qcow2")), newDisk, error, progress)) {
        QString cleanup;
        deleteVolumeByPath(newDiskPath, &cleanup);
        return false;
    }

    QString newNvramPath;
    const QString nvramBackup = QDir(backupPath).filePath(QStringLiteral("nvram.qcow2"));
    if (QFileInfo(nvramBackup).isFile()) {
        newNvramPath = createVolume(QStringLiteral("%1-restore-%2-nvram.qcow2").arg(id, suffix),
                                    qMax<quint64>(4ULL * 1024ULL * 1024ULL, QFileInfo(nvramBackup).size()),
                                    QStringLiteral("qcow2"), error);
        VolumeHandle newNvram(virStorageVolLookupByPath(m_connection, newNvramPath.toUtf8().constData()));
        if (newNvramPath.isEmpty() || !newNvram.value || !uploadVolume(nvramBackup, newNvram, error, {})) {
            QString cleanup;
            deleteVolumeByPath(newDiskPath, &cleanup);
            if (!newNvramPath.isEmpty())
                deleteVolumeByPath(newNvramPath, &cleanup);
            return false;
        }
    }

    const QDomNodeList disks = root.elementsByTagName(QStringLiteral("disk"));
    for (qsizetype index = 0; index < disks.size(); ++index) {
        QDomElement disk = disks.at(index).toElement();
        if (disk.attribute(QStringLiteral("device")) == QStringLiteral("disk")) {
            disk.firstChildElement(QStringLiteral("source")).setAttribute(QStringLiteral("file"), newDiskPath);
            break;
        }
    }
    if (!newNvramPath.isEmpty()) {
        QDomElement nvram = root.firstChildElement(QStringLiteral("os")).firstChildElement(QStringLiteral("nvram"));
        while (!nvram.firstChild().isNull())
            nvram.removeChild(nvram.firstChild());
        nvram.appendChild(document.createTextNode(newNvramPath));
    }
    for (const QString& tag : {QStringLiteral("memory"), QStringLiteral("currentMemory")}) {
        QDomElement element = root.firstChildElement(tag);
        element.setAttribute(QStringLiteral("unit"), QStringLiteral("MiB"));
        while (!element.firstChild().isNull())
            element.removeChild(element.firstChild());
        element.appendChild(
            document.createTextNode(QString::number(metadata.value(QStringLiteral("memoryMiB")).toInt())));
    }
    QDomElement vcpu = root.firstChildElement(QStringLiteral("vcpu"));
    while (!vcpu.firstChild().isNull())
        vcpu.removeChild(vcpu.firstChild());
    vcpu.appendChild(document.createTextNode(QString::number(metadata.value(QStringLiteral("cpuCount")).toInt())));
    const QString restoredXml = document.toString(-1);
    if (!validateDomainXml(restoredXml, error) || !virDomainDefineXML(m_connection, restoredXml.toUtf8().constData())) {
        if (error->isEmpty())
            *error = QStringLiteral("Libvirt отклонил восстановленную конфигурацию: %1").arg(lastError({}));
        QString cleanup;
        deleteVolumeByPath(newDiskPath, &cleanup);
        if (!newNvramPath.isEmpty())
            deleteVolumeByPath(newNvramPath, &cleanup);
        return false;
    }
    QString cleanup;
    deleteVolumeByPath(oldDiskPath, &cleanup);
    if (!oldNvramPath.isEmpty() && oldNvramPath != newNvramPath)
        deleteVolumeByPath(oldNvramPath, &cleanup);
    return true;
}

bool LibvirtManager::removeBackup(const QString& backupPath, const QString& backupRoot, QString* error) const
{
    const QString cleanRoot = QDir::cleanPath(QFileInfo(backupRoot).absoluteFilePath());
    const QString cleanBackup = QDir::cleanPath(QFileInfo(backupPath).absoluteFilePath());
    if (!cleanBackup.startsWith(cleanRoot + QLatin1Char('/')) || !cleanBackup.endsWith(QStringLiteral(".kvmbackup"))) {
        *error = QStringLiteral("Отказано в удалении каталога вне хранилища резервных копий");
        return false;
    }
    if (!QFileInfo(cleanBackup).isDir()) {
        *error = QStringLiteral("Резервная копия не найдена");
        return false;
    }
    if (!QDir(cleanBackup).removeRecursively()) {
        *error = QStringLiteral("Не удалось удалить резервную копию");
        return false;
    }
    return true;
}
