#include "LibvirtManager.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QImage>
#include <QPainter>
#include <QPainterPath>
#include <QProcess>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QTcpServer>
#include <QTcpSocket>
#include <QThread>
#include <QUuid>

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <propkey.h>
#include <propvarutil.h>
#include <shobjidl.h>

#include <iterator>
#include <limits>
#include <cstring>
#include <string>

namespace
{
constexpr qint64 GiB = 1024LL * 1024LL * 1024LL;

QJsonObject readObject(const QString& path, QString* error)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        *error = QStringLiteral("Не удалось открыть конфигурацию машины: %1").arg(file.errorString());
        return {};
    }
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        *error = QStringLiteral("Конфигурация машины повреждена: %1").arg(parseError.errorString());
        return {};
    }
    return document.object();
}

bool writeObject(const QString& path, const QJsonObject& object, QString* error)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        *error = QStringLiteral("Не удалось сохранить конфигурацию машины: %1").arg(file.errorString());
        return false;
    }
    if (file.write(QJsonDocument(object).toJson(QJsonDocument::Indented)) < 0 || !file.commit()) {
        *error = QStringLiteral("Не удалось атомарно сохранить конфигурацию машины: %1").arg(file.errorString());
        return false;
    }
    return true;
}

bool isInside(const QString& path, const QString& root)
{
    const QString cleanRoot = QDir::cleanPath(QFileInfo(root).absoluteFilePath());
    const QString cleanPath = QDir::cleanPath(QFileInfo(path).absoluteFilePath());
    return cleanPath == cleanRoot || cleanPath.startsWith(cleanRoot + QDir::separator(), Qt::CaseInsensitive);
}

QString hashFile(const QString& path, QString* error, const LibvirtManager::TransferProgress& progress = {})
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        *error = QStringLiteral("Не удалось прочитать файл: %1").arg(file.errorString());
        return {};
    }
    QCryptographicHash hash(QCryptographicHash::Sha256);
    QByteArray buffer(1024 * 1024, Qt::Uninitialized);
    qint64 done = 0;
    while (!file.atEnd()) {
        const qint64 count = file.read(buffer.data(), buffer.size());
        if (count < 0) {
            *error = QStringLiteral("Ошибка чтения файла: %1").arg(file.errorString());
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

bool copyFile(const QString& sourcePath, const QString& targetPath, QString* error,
              const LibvirtManager::TransferProgress& progress = {})
{
    QFile source(sourcePath);
    if (!source.open(QIODevice::ReadOnly)) {
        *error = QStringLiteral("Не удалось открыть исходный файл: %1").arg(source.errorString());
        return false;
    }
    QSaveFile target(targetPath);
    if (!target.open(QIODevice::WriteOnly)) {
        *error = QStringLiteral("Не удалось создать файл: %1").arg(target.errorString());
        return false;
    }
    QByteArray buffer(1024 * 1024, Qt::Uninitialized);
    qint64 done = 0;
    while (!source.atEnd()) {
        const qint64 count = source.read(buffer.data(), buffer.size());
        if (count < 0 || target.write(buffer.constData(), count) != count) {
            *error = QStringLiteral("Ошибка копирования файла");
            target.cancelWriting();
            return false;
        }
        done += count;
        if (progress && !progress(done, source.size())) {
            *error = QStringLiteral("Операция отменена");
            target.cancelWriting();
            return false;
        }
    }
    if (!target.commit()) {
        *error = QStringLiteral("Не удалось завершить запись файла: %1").arg(target.errorString());
        return false;
    }
    return true;
}

bool processIsRunning(qint64 pid)
{
    if (pid <= 0 || pid > std::numeric_limits<DWORD>::max())
        return false;
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, DWORD(pid));
    if (!process)
        return false;
    DWORD exitCode = 0;
    const bool running = GetExitCodeProcess(process, &exitCode) && exitCode == STILL_ACTIVE;
    CloseHandle(process);
    return running;
}

bool validDisplayMode(const QString& mode)
{
    return mode == QStringLiteral("windowed") || mode == QStringLiteral("borderless") ||
           mode == QStringLiteral("fullscreen");
}

bool validGpuId(const QString& id)
{
    return id == QStringLiteral("auto") || id == QStringLiteral("power-saving") ||
           id == QStringLiteral("high-performance");
}

void applyGpuPreference(const QString& executable, const QString& gpuId)
{
    HKEY key = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, L"Software\\Microsoft\\DirectX\\UserGpuPreferences", 0, nullptr, 0,
                        KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS)
        return;
    const std::wstring path = QDir::toNativeSeparators(executable).toStdWString();
    if (gpuId == QStringLiteral("auto")) {
        RegDeleteValueW(key, path.c_str());
    } else {
        const std::wstring value = gpuId == QStringLiteral("high-performance") ? L"GpuPreference=2;"
                                                                                : L"GpuPreference=1;";
        RegSetValueExW(key, path.c_str(), 0, REG_SZ, reinterpret_cast<const BYTE*>(value.c_str()),
                       DWORD((value.size() + 1) * sizeof(wchar_t)));
    }
    RegCloseKey(key);
}

HICON isoraIcon()
{
    static HICON icon = [] {
        constexpr int size = 32;
        QImage image(size, size, QImage::Format_ARGB32_Premultiplied);
        image.fill(Qt::transparent);
        QPainter painter(&image);
        painter.setRenderHint(QPainter::Antialiasing);
        painter.setPen(Qt::NoPen);
        painter.setBrush(QColor(QStringLiteral("#111A26")));
        painter.drawRoundedRect(QRectF(1, 1, 30, 30), 7, 7);
        painter.setPen(QPen(QColor(QStringLiteral("#4B8BE6")), 2));
        painter.setBrush(QColor(QStringLiteral("#172231")));
        painter.drawRoundedRect(QRectF(7, 8, 19, 15), 3, 3);
        painter.setPen(Qt::NoPen);
        painter.setBrush(QColor(QStringLiteral("#7CB3FF")));
        QPainterPath play;
        play.moveTo(14, 12);
        play.lineTo(21, 16);
        play.lineTo(14, 20);
        play.closeSubpath();
        painter.drawPath(play);
        painter.end();

        BITMAPV5HEADER header{};
        header.bV5Size = sizeof(header);
        header.bV5Width = size;
        header.bV5Height = -size;
        header.bV5Planes = 1;
        header.bV5BitCount = 32;
        header.bV5Compression = BI_BITFIELDS;
        header.bV5RedMask = 0x00FF0000;
        header.bV5GreenMask = 0x0000FF00;
        header.bV5BlueMask = 0x000000FF;
        header.bV5AlphaMask = 0xFF000000;
        void* pixels = nullptr;
        HDC screen = GetDC(nullptr);
        HBITMAP color = CreateDIBSection(screen, reinterpret_cast<BITMAPINFO*>(&header), DIB_RGB_COLORS, &pixels,
                                         nullptr, 0);
        ReleaseDC(nullptr, screen);
        if (!color || !pixels)
            return HICON(nullptr);
        memcpy(pixels, image.constBits(), size_t(image.sizeInBytes()));
        HBITMAP mask = CreateBitmap(size, size, 1, 1, nullptr);
        ICONINFO info{};
        info.fIcon = TRUE;
        info.hbmColor = color;
        info.hbmMask = mask;
        HICON result = CreateIconIndirect(&info);
        DeleteObject(color);
        DeleteObject(mask);
        return result;
    }();
    return icon;
}

struct WindowBranding
{
    DWORD pid = 0;
    HWND window = nullptr;
};

BOOL CALLBACK findProcessWindow(HWND window, LPARAM parameter)
{
    auto* branding = reinterpret_cast<WindowBranding*>(parameter);
    DWORD pid = 0;
    GetWindowThreadProcessId(window, &pid);
    if (pid != branding->pid || GetWindow(window, GW_OWNER) != nullptr || !IsWindowVisible(window))
        return TRUE;
    branding->window = window;
    return FALSE;
}

void brandQemuWindow(qint64 processId, const QString& title, const QString& displayMode)
{
    if (processId <= 0 || processId > std::numeric_limits<DWORD>::max())
        return;
    WindowBranding branding{DWORD(processId), nullptr};
    for (int attempt = 0; attempt < 40 && !branding.window; ++attempt) {
        EnumWindows(findProcessWindow, reinterpret_cast<LPARAM>(&branding));
        if (!branding.window)
            QThread::msleep(125);
    }
    if (!branding.window)
        return;

    const std::wstring nativeTitle = title.toStdWString();
    const auto applyWindowBranding = [&] {
        SetWindowTextW(branding.window, nativeTitle.c_str());
        if (const HICON icon = isoraIcon()) {
            SendMessageW(branding.window, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(icon));
            SendMessageW(branding.window, WM_SETICON, ICON_SMALL, reinterpret_cast<LPARAM>(icon));
        }
        if (displayMode == QStringLiteral("borderless")) {
            const LONG_PTR style = GetWindowLongPtrW(branding.window, GWL_STYLE);
            SetWindowLongPtrW(
                branding.window, GWL_STYLE,
                (style & ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU)) |
                    WS_POPUP | WS_VISIBLE);
            MONITORINFO monitorInfo{sizeof(monitorInfo)};
            if (GetMonitorInfoW(MonitorFromWindow(branding.window, MONITOR_DEFAULTTONEAREST), &monitorInfo)) {
                const RECT area = monitorInfo.rcWork;
                SetWindowPos(branding.window, nullptr, area.left, area.top, area.right - area.left,
                             area.bottom - area.top,
                             SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
            }
        }
    };

    applyWindowBranding();
    IPropertyStore* store = nullptr;
    if (SUCCEEDED(SHGetPropertyStoreForWindow(branding.window, IID_PPV_ARGS(&store)))) {
        PROPVARIANT appId;
        if (SUCCEEDED(InitPropVariantFromString(L"Isora.VirtualMachine", &appId))) {
            store->SetValue(PKEY_AppUserModel_ID, appId);
            store->Commit();
            PropVariantClear(&appId);
        }
        store->Release();
    }
    // SDL assigns its final `QEMU (<name>-0)` caption shortly after the HWND is
    // shown. Reapply our identity during that short initialization window so
    // the final taskbar/Alt-Tab title and icon remain Isora-branded.
    for (int attempt = 0; attempt < 16; ++attempt) {
        QThread::msleep(125);
        if (!IsWindow(branding.window))
            break;
        applyWindowBranding();
    }
}

bool terminateOwnedQemu(qint64 pid, const QString& expectedExecutable, QString* error)
{
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_TERMINATE, FALSE, DWORD(pid));
    if (!process) {
        *error = QStringLiteral("Процесс QEMU уже завершён или недоступен");
        return false;
    }
    wchar_t pathBuffer[32768];
    DWORD pathLength = DWORD(std::size(pathBuffer));
    const bool pathOk = QueryFullProcessImageNameW(process, 0, pathBuffer, &pathLength);
    const QString actualPath = pathOk ? QDir::cleanPath(QString::fromWCharArray(pathBuffer, int(pathLength))) : QString();
    if (!pathOk || actualPath.compare(QDir::cleanPath(expectedExecutable), Qt::CaseInsensitive) != 0) {
        CloseHandle(process);
        *error = QStringLiteral("PID больше не принадлежит процессу QEMU этой машины");
        return false;
    }
    const bool stopped = TerminateProcess(process, 1) != FALSE;
    CloseHandle(process);
    if (!stopped)
        *error = QStringLiteral("Windows не удалось завершить процесс QEMU");
    return stopped;
}

bool runTool(const QString& executable, const QStringList& arguments, QString* error, int timeout = 120000)
{
    QProcess process;
    process.start(executable, arguments);
    if (!process.waitForStarted(10000)) {
        *error = QStringLiteral("Не удалось запустить %1: %2").arg(QFileInfo(executable).fileName(), process.errorString());
        return false;
    }
    if (!process.waitForFinished(timeout)) {
        process.kill();
        process.waitForFinished();
        *error = QStringLiteral("Превышено время ожидания %1").arg(QFileInfo(executable).fileName());
        return false;
    }
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        *error = QString::fromUtf8(process.readAllStandardError()).trimmed();
        if (error->isEmpty())
            *error = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
        if (error->isEmpty())
            *error = QStringLiteral("%1 завершился с кодом %2").arg(QFileInfo(executable).fileName()).arg(process.exitCode());
        return false;
    }
    return true;
}

bool sendQmpCommand(quint16 port, const QByteArray& command, QString* error)
{
    QTcpSocket socket;
    socket.connectToHost(QHostAddress::LocalHost, port);
    if (!socket.waitForConnected(3000)) {
        *error = QStringLiteral("QMP этой машины недоступен: %1").arg(socket.errorString());
        return false;
    }
    if (!socket.waitForReadyRead(3000)) {
        *error = QStringLiteral("QMP не прислал приветствие");
        return false;
    }
    socket.readAll();
    socket.write("{\"execute\":\"qmp_capabilities\"}\r\n");
    if (!socket.waitForBytesWritten(3000)) {
        *error = QStringLiteral("Не удалось активировать QMP");
        return false;
    }
    socket.waitForReadyRead(1000);
    socket.readAll();
    socket.write("{\"execute\":\"");
    socket.write(command);
    socket.write("\"}\r\n");
    if (!socket.waitForBytesWritten(3000)) {
        *error = QStringLiteral("Не удалось отправить команду QMP");
        return false;
    }
    return true;
}
} // namespace

LibvirtManager::LibvirtManager(QObject* parent) : QObject(parent)
{
    m_poolPath = QDir(QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation))
                     .filePath(QStringLiteral("storage"));
}

LibvirtManager::~LibvirtManager() = default;

QString LibvirtManager::qemuExecutable() const
{
    const QString configured = QSettings().value(QStringLiteral("windows/qemuPath")).toString();
    if (QFileInfo(configured).isFile())
        return QDir::cleanPath(configured);
    const QString fromPath = QStandardPaths::findExecutable(QStringLiteral("qemu-system-x86_64.exe"));
    if (!fromPath.isEmpty())
        return fromPath;
    const QString standard = QStringLiteral("C:/Program Files/qemu/qemu-system-x86_64.exe");
    return QFileInfo(standard).isFile() ? standard : QString();
}

QString LibvirtManager::qemuImgExecutable() const
{
    const QString qemu = qemuExecutable();
    const QString besideQemu = QFileInfo(qemu).dir().filePath(QStringLiteral("qemu-img.exe"));
    if (QFileInfo(besideQemu).isFile())
        return besideQemu;
    return QStandardPaths::findExecutable(QStringLiteral("qemu-img.exe"));
}

QString LibvirtManager::machineDirectory(const QString& id) const
{
    return QDir(m_poolPath).filePath(QStringLiteral("machines/%1").arg(id));
}

QString LibvirtManager::machineConfigPath(const QString& id) const
{
    return QDir(machineDirectory(id)).filePath(QStringLiteral("machine.json"));
}

bool LibvirtManager::connect(QString* error)
{
    error->clear();
    if (qemuExecutable().isEmpty() || qemuImgExecutable().isEmpty()) {
        *error = QStringLiteral("QEMU не найден. Установите QEMU или укажите путь к qemu-system-x86_64.exe в настройках");
        m_connected = false;
        return false;
    }
    if (!QDir().mkpath(QDir(m_poolPath).filePath(QStringLiteral("machines"))) ||
        !QDir().mkpath(QDir(m_poolPath).filePath(QStringLiteral("iso")))) {
        *error = QStringLiteral("Не удалось создать хранилище Isora: %1").arg(m_poolPath);
        m_connected = false;
        return false;
    }
    m_connected = true;
    return true;
}

bool LibvirtManager::connectReadOnly(QString* error)
{
    return connect(error);
}

bool LibvirtManager::isConnected() const
{
    return m_connected;
}

QString LibvirtManager::connectionUri() const
{
    return QStringLiteral("qemu+whpx:///session");
}

QString LibvirtManager::poolPath() const
{
    return m_poolPath;
}

QString LibvirtManager::importIso(const QString& sourcePath, QString* error, QString* sha256,
                                  const TransferProgress& progress)
{
    error->clear();
    if (!QFileInfo(sourcePath).isFile()) {
        *error = QStringLiteral("ISO-файл не найден");
        return {};
    }
    const QString hash = hashFile(sourcePath, error);
    if (hash.isEmpty())
        return {};
    const QString target = QDir(m_poolPath).filePath(QStringLiteral("iso/%1.iso").arg(hash));
    if (!QFileInfo(target).isFile() && !copyFile(sourcePath, target, error, progress))
        return {};
    if (sha256)
        *sha256 = hash;
    return target;
}

bool LibvirtManager::deleteVolumeByPath(const QString& path, QString* error)
{
    error->clear();
    if (!isInside(path, m_poolPath)) {
        *error = QStringLiteral("Isora отказался удалять файл вне своего хранилища");
        return false;
    }
    if (!QFileInfo::exists(path) || QFile::remove(path))
        return true;
    *error = QStringLiteral("Не удалось удалить файл %1").arg(path);
    return false;
}

bool LibvirtManager::createMachine(const QVariantMap& options, QString* error)
{
    error->clear();
    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString directory = machineDirectory(id);
    if (!QDir().mkpath(directory)) {
        *error = QStringLiteral("Не удалось создать каталог машины");
        return false;
    }
    const int diskGiB = qBound(8, options.value(QStringLiteral("diskGiB")).toInt(), 2048);
    QStorageInfo storage(directory);
    if (storage.isValid() && storage.bytesAvailable() < 512LL * 1024LL * 1024LL) {
        *error = QStringLiteral("В хранилище недостаточно свободного места для новой машины");
        QDir(directory).removeRecursively();
        return false;
    }
    const QString diskPath = QDir(directory).filePath(QStringLiteral("disk.qcow2"));
    if (!runTool(qemuImgExecutable(), {QStringLiteral("create"), QStringLiteral("-f"), QStringLiteral("qcow2"),
                                       diskPath, QStringLiteral("%1G").arg(diskGiB)}, error)) {
        QDir(directory).removeRecursively();
        return false;
    }
    const bool useEfi = options.value(QStringLiteral("useEfi")).toBool();
    QString firmwareCodePath;
    QString nvramPath;
    if (useEfi) {
        const QDir qemuDirectory = QFileInfo(qemuExecutable()).dir();
        firmwareCodePath = qemuDirectory.filePath(QStringLiteral("share/edk2-x86_64-code.fd"));
        const QString nvramTemplate = qemuDirectory.filePath(QStringLiteral("share/edk2-i386-vars.fd"));
        nvramPath = QDir(directory).filePath(QStringLiteral("nvram.fd"));
        if (!QFileInfo(firmwareCodePath).isFile() || !QFileInfo(nvramTemplate).isFile() ||
            !copyFile(nvramTemplate, nvramPath, error)) {
            if (error->isEmpty())
                *error = QStringLiteral("В установленном QEMU не найдены файлы UEFI firmware");
            QDir(directory).removeRecursively();
            return false;
        }
    }
    QJsonObject config{{QStringLiteral("formatVersion"), 1},
                       {QStringLiteral("id"), id},
                       {QStringLiteral("name"), options.value(QStringLiteral("name")).toString().trimmed()},
                       {QStringLiteral("memoryMiB"), qBound(1024, options.value(QStringLiteral("memoryMiB")).toInt(), 262144)},
                       {QStringLiteral("cpuCount"), qBound(1, options.value(QStringLiteral("cpuCount")).toInt(), 256)},
                       {QStringLiteral("diskGiB"), diskGiB},
                       {QStringLiteral("diskPath"), diskPath},
                       {QStringLiteral("isoPath"), options.value(QStringLiteral("isoPath")).toString()},
                       {QStringLiteral("useEfi"), useEfi},
                       {QStringLiteral("firmwareCodePath"), firmwareCodePath},
                       {QStringLiteral("nvramPath"), nvramPath},
                       {QStringLiteral("use3d"), false},
                       {QStringLiteral("displayMode"), QStringLiteral("windowed")},
                       {QStringLiteral("gpuId"), QStringLiteral("auto")},
                       {QStringLiteral("createdAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},
                       {QStringLiteral("pid"), 0},
                       {QStringLiteral("qmpPort"), 0}};
    if (!writeObject(machineConfigPath(id), config, error)) {
        QDir(directory).removeRecursively();
        return false;
    }
    return true;
}

bool LibvirtManager::importExistingMachine(const QString& name, const QString& sourceDiskPath, int memoryMiB,
                                           int cpuCount, QString* error)
{
    error->clear();
    const QString diskPath = QDir::cleanPath(QFileInfo(sourceDiskPath).absoluteFilePath());
    if (name.trimmed().isEmpty()) {
        *error = QStringLiteral("Введите название машины");
        return false;
    }
    if (!QFileInfo(diskPath).isFile()) {
        *error = QStringLiteral("Диск виртуальной машины не найден: %1").arg(diskPath);
        return false;
    }
    if (!runTool(qemuImgExecutable(), {QStringLiteral("check"), QStringLiteral("-q"), diskPath}, error))
        return false;

    QProcess infoProcess;
    infoProcess.start(qemuImgExecutable(), {QStringLiteral("info"), QStringLiteral("--output=json"), diskPath});
    if (!infoProcess.waitForStarted(10000) || !infoProcess.waitForFinished(30000) ||
        infoProcess.exitStatus() != QProcess::NormalExit || infoProcess.exitCode() != 0) {
        *error = QStringLiteral("Не удалось прочитать параметры диска через qemu-img");
        return false;
    }
    QJsonParseError parseError;
    const QJsonDocument info = QJsonDocument::fromJson(infoProcess.readAllStandardOutput(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !info.isObject() ||
        info.object().value(QStringLiteral("format")).toString() != QStringLiteral("qcow2")) {
        *error = QStringLiteral("Для импорта требуется исправный диск QCOW2");
        return false;
    }
    const qint64 virtualSize = info.object().value(QStringLiteral("virtual-size")).toInteger();
    if (virtualSize <= 0) {
        *error = QStringLiteral("qemu-img не вернул размер виртуального диска");
        return false;
    }

    const QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString directory = machineDirectory(id);
    if (!QDir().mkpath(directory)) {
        *error = QStringLiteral("Не удалось создать каталог машины");
        return false;
    }
    const int diskGiB = int(qMin<qint64>(2048, (virtualSize + GiB - 1) / GiB));
    const QJsonObject config{{QStringLiteral("formatVersion"), 1},
                             {QStringLiteral("id"), id},
                             {QStringLiteral("name"), name.trimmed()},
                             {QStringLiteral("memoryMiB"), qBound(1024, memoryMiB, 262144)},
                             {QStringLiteral("cpuCount"), qBound(1, cpuCount, 256)},
                             {QStringLiteral("diskGiB"), diskGiB},
                             {QStringLiteral("diskPath"), diskPath},
                             {QStringLiteral("externalDisk"), true},
                             {QStringLiteral("isoPath"), QString()},
                             {QStringLiteral("useEfi"), false},
                              {QStringLiteral("use3d"), false},
                              {QStringLiteral("displayMode"), QStringLiteral("windowed")},
                              {QStringLiteral("gpuId"), QStringLiteral("auto")},
                             {QStringLiteral("createdAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},
                             {QStringLiteral("pid"), 0},
                             {QStringLiteral("qmpPort"), 0}};
    if (writeObject(machineConfigPath(id), config, error))
        return true;
    QDir(directory).removeRecursively();
    return false;
}

QVariantList LibvirtManager::domains(QString* error) const
{
    error->clear();
    QVariantList result;
    const QDir root(QDir(m_poolPath).filePath(QStringLiteral("machines")));
    for (const QFileInfo& entry : root.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name)) {
        QString readError;
        const QJsonObject object = readObject(QDir(entry.absoluteFilePath()).filePath(QStringLiteral("machine.json")), &readError);
        if (!readError.isEmpty())
            continue;
        const bool running = processIsRunning(object.value(QStringLiteral("pid")).toInteger());
        const QStringList resources{QStringLiteral("%1 ГиБ RAM").arg(object.value(QStringLiteral("memoryMiB")).toInt() / 1024.0, 0, 'f', 1),
                                    QStringLiteral("%1 vCPU").arg(object.value(QStringLiteral("cpuCount")).toInt()),
                                    QStringLiteral("диск %1 ГиБ").arg(object.value(QStringLiteral("diskGiB")).toInt())};
        result.append(QVariantMap{{QStringLiteral("id"), object.value(QStringLiteral("id")).toString()},
                                  {QStringLiteral("name"), object.value(QStringLiteral("name")).toString()},
                                  {QStringLiteral("state"), running ? QStringLiteral("Работает") : QStringLiteral("Выключена")},
                                  {QStringLiteral("running"), running},
                                  {QStringLiteral("diskPath"), object.value(QStringLiteral("diskPath")).toString()},
                                  {QStringLiteral("memoryMiB"), object.value(QStringLiteral("memoryMiB")).toInt()},
                                  {QStringLiteral("cpuCount"), object.value(QStringLiteral("cpuCount")).toInt()},
                                  {QStringLiteral("diskGiB"), object.value(QStringLiteral("diskGiB")).toInt()},
                                  {QStringLiteral("useEfi"), object.value(QStringLiteral("useEfi")).toBool()},
                                  {QStringLiteral("use3d"), false},
                                  {QStringLiteral("displayMode"), object.value(QStringLiteral("displayMode")).toString(QStringLiteral("windowed"))},
                                  {QStringLiteral("gpuId"), object.value(QStringLiteral("gpuId")).toString(QStringLiteral("auto"))},
                                  {QStringLiteral("snapshots"), 0},
                                  {QStringLiteral("resources"), resources.join(QStringLiteral(" · "))}});
    }
    return result;
}

QVariantMap LibvirtManager::machineDetails(const QString& id, QString* error) const
{
    const QJsonObject object = readObject(machineConfigPath(id), error);
    if (!error->isEmpty())
        return {};
    return QVariantMap{{QStringLiteral("id"), id},
                       {QStringLiteral("name"), object.value(QStringLiteral("name")).toString()},
                       {QStringLiteral("memoryMiB"), object.value(QStringLiteral("memoryMiB")).toInt()},
                       {QStringLiteral("cpuCount"), object.value(QStringLiteral("cpuCount")).toInt()},
                       {QStringLiteral("diskGiB"), object.value(QStringLiteral("diskGiB")).toInt()},
                       {QStringLiteral("diskPath"), object.value(QStringLiteral("diskPath")).toString()},
                       {QStringLiteral("useEfi"), object.value(QStringLiteral("useEfi")).toBool()},
                        {QStringLiteral("use3d"), false},
                        {QStringLiteral("displayMode"), object.value(QStringLiteral("displayMode")).toString(QStringLiteral("windowed"))},
                        {QStringLiteral("gpuId"), object.value(QStringLiteral("gpuId")).toString(QStringLiteral("auto"))},
                       {QStringLiteral("running"), processIsRunning(object.value(QStringLiteral("pid")).toInteger())}};
}

bool LibvirtManager::updateMachineResources(const QString& id, int memoryMiB, int cpuCount, int diskGiB, QString* error)
{
    QJsonObject object = readObject(machineConfigPath(id), error);
    if (!error->isEmpty())
        return false;
    if (processIsRunning(object.value(QStringLiteral("pid")).toInteger())) {
        *error = QStringLiteral("Чтобы изменить ресурсы, выключите виртуальную машину");
        return false;
    }
    const int currentDiskGiB = object.value(QStringLiteral("diskGiB")).toInt();
    if (diskGiB < currentDiskGiB) {
        *error = QStringLiteral("Уменьшение виртуального диска не поддерживается");
        return false;
    }
    if (diskGiB > currentDiskGiB &&
        !runTool(qemuImgExecutable(), {QStringLiteral("resize"), object.value(QStringLiteral("diskPath")).toString(),
                                       QStringLiteral("%1G").arg(diskGiB)}, error))
        return false;
    object.insert(QStringLiteral("memoryMiB"), qBound(1024, memoryMiB, 262144));
    object.insert(QStringLiteral("cpuCount"), qBound(1, cpuCount, 256));
    object.insert(QStringLiteral("diskGiB"), qBound(currentDiskGiB, diskGiB, 2048));
    return writeObject(machineConfigPath(id), object, error);
}

bool LibvirtManager::updateMachineGraphics(const QString& id, const QString& displayMode, const QString& gpuId,
                                           bool use3d, QString* error)
{
    Q_UNUSED(use3d)
    error->clear();
    if (!validDisplayMode(displayMode) || !validGpuId(gpuId)) {
        *error = QStringLiteral("Неподдерживаемый режим экрана или GPU");
        return false;
    }
    QJsonObject object = readObject(machineConfigPath(id), error);
    if (!error->isEmpty())
        return false;
    object.insert(QStringLiteral("displayMode"), displayMode);
    object.insert(QStringLiteral("gpuId"), gpuId);
    return writeObject(machineConfigPath(id), object, error);
}

bool LibvirtManager::start(const QString& id, QString* error)
{
    QJsonObject object = readObject(machineConfigPath(id), error);
    if (!error->isEmpty())
        return false;
    if (processIsRunning(object.value(QStringLiteral("pid")).toInteger())) {
        *error = QStringLiteral("Виртуальная машина уже запущена");
        return false;
    }
    QTcpServer portProbe;
    if (!portProbe.listen(QHostAddress::LocalHost, 0)) {
        *error = QStringLiteral("Не удалось выделить локальный QMP-порт");
        return false;
    }
    const quint16 qmpPort = portProbe.serverPort();
    portProbe.close();
    const QString diskPath = object.value(QStringLiteral("diskPath")).toString();
    const QString displayMode = object.value(QStringLiteral("displayMode")).toString(QStringLiteral("windowed"));
    const QString gpuId = object.value(QStringLiteral("gpuId")).toString(QStringLiteral("auto"));
    if (!validDisplayMode(displayMode) || !validGpuId(gpuId)) {
        *error = QStringLiteral("Конфигурация экрана или GPU повреждена");
        return false;
    }
    QStringList arguments{QStringLiteral("-name"), QStringLiteral("Isora — %1").arg(object.value(QStringLiteral("name")).toString()),
                          QStringLiteral("-machine"), QStringLiteral("q35"),
                          QStringLiteral("-accel"), QStringLiteral("whpx"),
                          QStringLiteral("-m"), QString::number(object.value(QStringLiteral("memoryMiB")).toInt()),
                          QStringLiteral("-smp"), QString::number(object.value(QStringLiteral("cpuCount")).toInt()),
                          QStringLiteral("-device"), QStringLiteral("virtio-mouse-pci"),
                          QStringLiteral("-device"), QStringLiteral("VGA,vgamem_mb=256,xres=1920,yres=1080"),
                          QStringLiteral("-display"), QStringLiteral("sdl,gl=off"),
                          QStringLiteral("-drive"), QStringLiteral("file=%1,if=virtio,format=qcow2").arg(diskPath),
                           QStringLiteral("-qmp"), QStringLiteral("tcp:127.0.0.1:%1,server=on,wait=off").arg(qmpPort)};
    if (displayMode == QStringLiteral("fullscreen"))
        arguments << QStringLiteral("-full-screen");
    if (object.value(QStringLiteral("useEfi")).toBool()) {
        const QString firmwareCodePath = object.value(QStringLiteral("firmwareCodePath")).toString();
        const QString nvramPath = object.value(QStringLiteral("nvramPath")).toString();
        if (!QFileInfo(firmwareCodePath).isFile() || !QFileInfo(nvramPath).isFile()) {
            *error = QStringLiteral("Файлы UEFI этой машины не найдены");
            return false;
        }
        arguments << QStringLiteral("-drive")
                  << QStringLiteral("if=pflash,format=raw,readonly=on,file=%1").arg(firmwareCodePath)
                  << QStringLiteral("-drive") << QStringLiteral("if=pflash,format=raw,file=%1").arg(nvramPath);
    }
    const QString isoPath = object.value(QStringLiteral("isoPath")).toString();
    if (!object.value(QStringLiteral("bootFromDisk")).toBool() && QFileInfo(isoPath).isFile()) {
        arguments << QStringLiteral("-drive")
                  << QStringLiteral("file=%1,media=cdrom,readonly=on").arg(isoPath)
                  << QStringLiteral("-boot") << QStringLiteral("order=d");
    } else {
        arguments << QStringLiteral("-boot") << QStringLiteral("order=c");
    }
    qint64 pid = 0;
    applyGpuPreference(qemuExecutable(), gpuId);
    QProcess process;
    process.setProgram(qemuExecutable());
    process.setArguments(arguments);
    process.setWorkingDirectory(machineDirectory(id));
    process.setStandardOutputFile(QDir(machineDirectory(id)).filePath(QStringLiteral("qemu.log")), QIODevice::Append);
    process.setStandardErrorFile(QDir(machineDirectory(id)).filePath(QStringLiteral("qemu.log")), QIODevice::Append);
    if (!process.startDetached(&pid)) {
        *error = QStringLiteral("Не удалось запустить QEMU с WHPX");
        return false;
    }
    object.insert(QStringLiteral("pid"), pid);
    object.insert(QStringLiteral("qmpPort"), int(qmpPort));
    if (!writeObject(machineConfigPath(id), object, error))
        return false;
    brandQemuWindow(pid, QStringLiteral("Isora — %1").arg(object.value(QStringLiteral("name")).toString()),
                    displayMode);
    return true;
}

bool LibvirtManager::startFromDisk(const QString& id, QString* error)
{
    QJsonObject object = readObject(machineConfigPath(id), error);
    if (!error->isEmpty())
        return false;
    object.insert(QStringLiteral("bootFromDisk"), true);
    if (!writeObject(machineConfigPath(id), object, error))
        return false;
    return start(id, error);
}

bool LibvirtManager::shutdown(const QString& id, QString* error)
{
    const QJsonObject object = readObject(machineConfigPath(id), error);
    if (!error->isEmpty())
        return false;
    if (!processIsRunning(object.value(QStringLiteral("pid")).toInteger())) {
        *error = QStringLiteral("Виртуальная машина уже выключена");
        return false;
    }
    return sendQmpCommand(quint16(object.value(QStringLiteral("qmpPort")).toInt()), QByteArrayLiteral("system_powerdown"), error);
}

bool LibvirtManager::reset(const QString& id, QString* error)
{
    const QJsonObject object = readObject(machineConfigPath(id), error);
    if (!error->isEmpty())
        return false;
    if (!processIsRunning(object.value(QStringLiteral("pid")).toInteger())) {
        *error = QStringLiteral("Виртуальная машина выключена");
        return false;
    }
    return sendQmpCommand(quint16(object.value(QStringLiteral("qmpPort")).toInt()), QByteArrayLiteral("system_reset"), error);
}

bool LibvirtManager::forceStop(const QString& id, QString* error)
{
    QJsonObject object = readObject(machineConfigPath(id), error);
    if (!error->isEmpty())
        return false;
    const qint64 pid = object.value(QStringLiteral("pid")).toInteger();
    if (!processIsRunning(pid)) {
        object.insert(QStringLiteral("pid"), 0);
        object.insert(QStringLiteral("qmpPort"), 0);
        writeObject(machineConfigPath(id), object, error);
        return true;
    }
    if (!terminateOwnedQemu(pid, qemuExecutable(), error))
        return false;
    object.insert(QStringLiteral("pid"), 0);
    object.insert(QStringLiteral("qmpPort"), 0);
    return writeObject(machineConfigPath(id), object, error);
}

bool LibvirtManager::removeMachine(const QString& id, bool removeDisk, QString* error)
{
    const QJsonObject object = readObject(machineConfigPath(id), error);
    if (!error->isEmpty())
        return false;
    if (processIsRunning(object.value(QStringLiteral("pid")).toInteger())) {
        *error = QStringLiteral("Перед удалением выключите виртуальную машину");
        return false;
    }
    if (removeDisk) {
        if (!QDir(machineDirectory(id)).removeRecursively()) {
            *error = QStringLiteral("Не удалось удалить каталог машины");
            return false;
        }
        return true;
    }
    return QFile::remove(machineConfigPath(id));
}

bool LibvirtManager::openDisplay(const QString& id, QString* error) const
{
    const QJsonObject object = readObject(machineConfigPath(id), error);
    if (!error->isEmpty())
        return false;
    if (!processIsRunning(object.value(QStringLiteral("pid")).toInteger())) {
        *error = QStringLiteral("Экран открывается вместе с QEMU; сначала запустите машину");
        return false;
    }
    return true;
}

bool LibvirtManager::openConsole(const QString&, QString* error) const
{
    *error = QStringLiteral("Отдельная serial-консоль Windows появится в следующей alpha; сейчас используйте окно QEMU");
    return false;
}

QVariantList LibvirtManager::snapshots(const QString&, QString* error) const
{
    error->clear();
    return {};
}

bool LibvirtManager::createSnapshot(const QString&, const QString&, QString* error)
{
    *error = QStringLiteral("Snapshots Windows backend ещё не включены в alpha1");
    return false;
}

bool LibvirtManager::revertSnapshot(const QString&, const QString&, QString* error)
{
    *error = QStringLiteral("Snapshots Windows backend ещё не включены в alpha1");
    return false;
}

bool LibvirtManager::removeSnapshot(const QString&, const QString&, QString* error)
{
    *error = QStringLiteral("Snapshots Windows backend ещё не включены в alpha1");
    return false;
}

QVariantList LibvirtManager::backups(const QString& id, const QString& backupRoot, QString* error) const
{
    error->clear();
    QVariantList result;
    const QDir root(QDir(backupRoot).filePath(id));
    for (const QFileInfo& entry : root.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Time)) {
        QString metadataError;
        const QJsonObject metadata = readObject(QDir(entry.absoluteFilePath()).filePath(QStringLiteral("metadata.json")), &metadataError);
        result.append(QVariantMap{{QStringLiteral("path"), entry.absoluteFilePath()},
                                  {QStringLiteral("name"), entry.fileName()},
                                  {QStringLiteral("createdAt"), metadata.value(QStringLiteral("createdAt")).toString()},
                                  {QStringLiteral("size"), QFileInfo(QDir(entry.absoluteFilePath()).filePath(QStringLiteral("disk.qcow2"))).size()},
                                  {QStringLiteral("valid"), metadataError.isEmpty()}});
    }
    return result;
}

QString LibvirtManager::createBackup(const QString& id, const QString& backupRoot, QString* error,
                                     const TransferProgress& progress)
{
    const QJsonObject machine = readObject(machineConfigPath(id), error);
    if (!error->isEmpty())
        return {};
    if (processIsRunning(machine.value(QStringLiteral("pid")).toInteger())) {
        *error = QStringLiteral("Для резервного копирования выключите виртуальную машину");
        return {};
    }
    const QString parent = QDir(backupRoot).filePath(id);
    if (!QDir().mkpath(parent)) {
        *error = QStringLiteral("Не удалось создать каталог резервных копий");
        return {};
    }
    const QString name = QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyyMMdd-HHmmss-zzz"));
    const QString partial = QDir(parent).filePath(QStringLiteral(".partial-%1").arg(name));
    const QString target = QDir(parent).filePath(name);
    if (!QDir().mkpath(partial)) {
        *error = QStringLiteral("Не удалось подготовить резервную копию");
        return {};
    }
    const QString backupDisk = QDir(partial).filePath(QStringLiteral("disk.qcow2"));
    if (!copyFile(machine.value(QStringLiteral("diskPath")).toString(), backupDisk, error, progress)) {
        QDir(partial).removeRecursively();
        return {};
    }
    const QString hash = hashFile(backupDisk, error);
    QJsonObject metadata{{QStringLiteral("formatVersion"), 1},
                         {QStringLiteral("machineId"), id},
                         {QStringLiteral("createdAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},
                         {QStringLiteral("diskGiB"), machine.value(QStringLiteral("diskGiB")).toInt()},
                         {QStringLiteral("diskSha256"), hash},
                         {QStringLiteral("machine"), machine}};
    if (hash.isEmpty() || !writeObject(QDir(partial).filePath(QStringLiteral("metadata.json")), metadata, error) ||
        !QDir().rename(partial, target)) {
        if (error->isEmpty())
            *error = QStringLiteral("Не удалось опубликовать резервную копию");
        QDir(partial).removeRecursively();
        return {};
    }
    return target;
}

bool LibvirtManager::verifyBackup(const QString& backupPath, QString* error, const TransferProgress& progress) const
{
    const QJsonObject metadata = readObject(QDir(backupPath).filePath(QStringLiteral("metadata.json")), error);
    if (!error->isEmpty())
        return false;
    const QString disk = QDir(backupPath).filePath(QStringLiteral("disk.qcow2"));
    const QString hash = hashFile(disk, error, progress);
    if (hash.isEmpty())
        return false;
    if (hash != metadata.value(QStringLiteral("diskSha256")).toString()) {
        *error = QStringLiteral("Контрольная сумма резервной копии не совпадает");
        return false;
    }
    return runTool(qemuImgExecutable(), {QStringLiteral("check"), QStringLiteral("-q"), disk}, error);
}

bool LibvirtManager::restoreBackup(const QString& id, const QString& backupPath, QString* error,
                                   const TransferProgress& progress)
{
    QJsonObject machine = readObject(machineConfigPath(id), error);
    if (!error->isEmpty())
        return false;
    if (processIsRunning(machine.value(QStringLiteral("pid")).toInteger())) {
        *error = QStringLiteral("Для восстановления выключите виртуальную машину");
        return false;
    }
    if (!verifyBackup(backupPath, error, progress))
        return false;
    const QString diskPath = machine.value(QStringLiteral("diskPath")).toString();
    return copyFile(QDir(backupPath).filePath(QStringLiteral("disk.qcow2")), diskPath, error, progress);
}

bool LibvirtManager::removeBackup(const QString& backupPath, const QString& backupRoot, QString* error) const
{
    error->clear();
    if (!isInside(backupPath, backupRoot) || QFileInfo(backupPath).absoluteFilePath() == QFileInfo(backupRoot).absoluteFilePath()) {
        *error = QStringLiteral("Isora отказался удалить каталог вне резервного хранилища");
        return false;
    }
    if (!QDir(backupPath).removeRecursively()) {
        *error = QStringLiteral("Не удалось удалить резервную копию");
        return false;
    }
    return true;
}
