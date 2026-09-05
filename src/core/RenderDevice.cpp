#include "RenderDevice.h"

#ifdef Q_OS_WIN
#include <dxgi1_6.h>
#include <wrl/client.h>
#else
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>
#endif

namespace
{
#ifdef Q_OS_WIN
using Microsoft::WRL::ComPtr;

std::optional<RenderDevices::Device> adapterForPreference(DXGI_GPU_PREFERENCE preference, const QString& id,
                                                           const QString& detail)
{
    ComPtr<IDXGIFactory6> factory;
    if (FAILED(CreateDXGIFactory1(IID_PPV_ARGS(&factory))))
        return std::nullopt;

    for (UINT index = 0;; ++index) {
        ComPtr<IDXGIAdapter4> adapter;
        const HRESULT result = factory->EnumAdapterByGpuPreference(index, preference, IID_PPV_ARGS(&adapter));
        if (result == DXGI_ERROR_NOT_FOUND)
            break;
        if (FAILED(result))
            continue;
        DXGI_ADAPTER_DESC3 description{};
        if (FAILED(adapter->GetDesc3(&description)) || (description.Flags & DXGI_ADAPTER_FLAG3_SOFTWARE))
            continue;
        return RenderDevices::Device{id, QString::fromWCharArray(description.Description), {}, detail};
    }
    return std::nullopt;
}
#else
QString deviceRoot(const QString& path)
{
    return QStringLiteral("/sys/class/drm/%1/device").arg(QFileInfo(path).fileName());
}

QString readValue(const QString& path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(file.readAll()).trimmed();
}

QString deviceName(const QString& path)
{
    const QString root = deviceRoot(path);
    const QString pciAddress = QFileInfo(QFileInfo(root).symLinkTarget()).fileName();
    const QString lspci = QStandardPaths::findExecutable(QStringLiteral("lspci"));
    if (pciAddress.isEmpty() || lspci.isEmpty())
        return QStringLiteral("GPU %1").arg(QFileInfo(path).fileName());

    QProcess process;
    process.start(lspci, {QStringLiteral("-s"), pciAddress});
    if (!process.waitForFinished(1000) || process.exitCode() != 0)
        return QStringLiteral("GPU %1").arg(QFileInfo(path).fileName());

    QString result = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
    const qsizetype separator = result.indexOf(QStringLiteral(": "));
    if (separator >= 0)
        result = result.mid(separator + 2);
    const qsizetype revision = result.lastIndexOf(QStringLiteral(" (rev "));
    if (revision >= 0)
        result.truncate(revision);
    return result.isEmpty() ? QStringLiteral("GPU %1").arg(QFileInfo(path).fileName()) : result;
}
#endif
} // namespace

namespace RenderDevices
{
QList<Device> all()
{
#ifdef Q_OS_WIN
    QList<Device> result;
    if (const auto device = adapterForPreference(DXGI_GPU_PREFERENCE_MINIMUM_POWER, QStringLiteral("power-saving"),
                                                  QStringLiteral("Windows · энергосбережение")))
        result.append(*device);
    if (const auto device = adapterForPreference(DXGI_GPU_PREFERENCE_HIGH_PERFORMANCE,
                                                  QStringLiteral("high-performance"),
                                                  QStringLiteral("Windows · высокая производительность")))
        result.append(*device);
    return result;
#else
    QList<Device> result;
    const QDir directory(QStringLiteral("/dev/dri"));
    const QFileInfoList nodes =
        directory.entryInfoList({QStringLiteral("renderD*")}, QDir::System | QDir::Files, QDir::Name);
    for (const QFileInfo& node : nodes) {
        const QString path = node.absoluteFilePath();
        result.append(Device{path, deviceName(path), path, path});
    }
    return result;
#endif
}

std::optional<Device> preferred()
{
#ifdef Q_OS_WIN
    return adapterForPreference(DXGI_GPU_PREFERENCE_HIGH_PERFORMANCE, QStringLiteral("high-performance"),
                                QStringLiteral("Windows · высокая производительность"));
#else
    const QList<Device> devices = all();
    for (const Device& device : devices) {
        if (isIntel(device.path))
            return device;
    }
    return devices.isEmpty() ? std::nullopt : std::optional<Device>(devices.constFirst());
#endif
}

std::optional<Device> find(const QString& id)
{
    const QList<Device> devices = all();
    for (const Device& device : devices) {
        if (device.id == id)
            return device;
    }
    return std::nullopt;
}

bool isIntel(const QString& path)
{
#ifdef Q_OS_WIN
    Q_UNUSED(path)
    return false;
#else
    if (path.isEmpty())
        return false;
    const QString root = deviceRoot(path);
    if (readValue(root + QStringLiteral("/vendor")).compare(QStringLiteral("0x8086"), Qt::CaseInsensitive) == 0)
        return true;
    const QString driver = QFileInfo(root + QStringLiteral("/driver")).symLinkTarget();
    const QString name = QFileInfo(driver).fileName();
    return name == QStringLiteral("i915") || name == QStringLiteral("xe");
#endif
}

std::optional<Device> intel()
{
#ifdef Q_OS_WIN
    return std::nullopt;
#else
    for (const Device& device : all()) {
        if (!isIntel(device.path))
            continue;
        return device;
    }
    return std::nullopt;
#endif
}

bool isRenderNode(const QString& path)
{
#ifdef Q_OS_WIN
    Q_UNUSED(path)
    return false;
#else
    const QString cleanPath = QDir::cleanPath(path);
    for (const Device& device : all()) {
        if (QDir::cleanPath(device.path) == cleanPath)
            return true;
    }
    return false;
#endif
}
} // namespace RenderDevices
