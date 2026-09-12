#include <QCoreApplication>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>

#include "core/IsoLibrary.h"
#include "core/LibvirtManager.h"

namespace
{
QTextStream out(stdout);
QTextStream err(stderr);

void usage()
{
    out << "Isora " << ISORA_VERSION << "\n\n"
        << "Использование:\n"
        << "  isoractl status [--json]\n"
        << "  isoractl image list [--json]\n"
        << "  isoractl image add ПУТЬ\n"
        << "  isoractl image remove ID\n"
        << "  isoractl vm list [--json]\n"
        << "  isoractl vm create ИМЯ ID_ОБРАЗА [параметры]\n"
        << "  isoractl vm import ИМЯ ПУТЬ_QCOW2 [--memory МиБ --cpus ЧИСЛО]\n"
        << "  isoractl vm start|open|reset|shutdown|stop|delete ID\n"
        << "  isoractl vm set ID --memory МиБ --cpus ЧИСЛО --disk ГБ\n"
        << "  isoractl vm graphics ID --display windowed|borderless|fullscreen --gpu ID [--3d] [--restart]\n"
        << "  isoractl snapshot list ID [--json]\n"
        << "  isoractl snapshot create|revert|delete ID ИМЯ\n"
        << "  isoractl backup list|create ID [--json]\n"
        << "  isoractl backup verify|restore|delete ID ПУТЬ\n\n"
        << "Параметры создания машины:\n"
        << "  --memory МиБ     память, по умолчанию 6144\n"
        << "  --cpus ЧИСЛО     процессоры, по умолчанию 4\n"
        << "  --disk ГБ        диск, по умолчанию 48\n"
        << "  --bios           использовать BIOS вместо UEFI\n"
        << "  --3d             включить 3D-ускорение через Intel\n";
}

QString optionValue(const QStringList& arguments, const QString& option, const QString& fallback)
{
    const qsizetype index = arguments.indexOf(option);
    if (index >= 0 && index + 1 < arguments.size())
        return arguments.at(index + 1);
    return fallback;
}

void printJson(const QVariant& value)
{
    QJsonDocument document;
    if (value.metaType().id() == QMetaType::QVariantList)
        document = QJsonDocument(QJsonArray::fromVariantList(value.toList()));
    else
        document = QJsonDocument(QJsonObject::fromVariantMap(value.toMap()));
    out << document.toJson(QJsonDocument::Indented);
}

int fail(const QString& message)
{
    err << "Ошибка: " << message << '\n';
    return 1;
}

} // namespace

int main(int argc, char* argv[])
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("Isora"));
    QCoreApplication::setApplicationName(QStringLiteral("Isora"));
    const QStringList arguments = app.arguments().mid(1);
    if (arguments.isEmpty() || arguments.contains(QStringLiteral("--help")) ||
        arguments.contains(QStringLiteral("-h"))) {
        usage();
        return 0;
    }
    if (arguments.contains(QStringLiteral("--version"))) {
        out << "Isora " << ISORA_VERSION << '\n';
        return 0;
    }

    LibvirtManager libvirt;
    IsoLibrary library;
    QString error;
    if (!libvirt.connect(&error))
        return fail(error);

    const bool json = arguments.contains(QStringLiteral("--json"));
    const QString group = arguments.value(0);
    if (group == QStringLiteral("status")) {
        const QVariantList machines = libvirt.domains(&error);
        if (!error.isEmpty())
            return fail(error);
        const QVariantMap status{{QStringLiteral("connected"), true},
                                 {QStringLiteral("uri"), libvirt.connectionUri()},
                                 {QStringLiteral("images"), library.images().size()},
                                 {QStringLiteral("machines"), machines.size()}};
        if (json)
            printJson(status);
        else
            out << "Виртуализация: готова\nISO-образов: " << library.images().size()
                << "\nВиртуальных машин: " << machines.size() << '\n';
        return 0;
    }

    if (group == QStringLiteral("image")) {
        const QString action = arguments.value(1);
        if (action == QStringLiteral("list")) {
            if (json)
                printJson(library.images());
            else
                for (const QVariant& item : library.images()) {
                    const QVariantMap image = item.toMap();
                    out << image.value(QStringLiteral("id")).toString() << "  "
                        << image.value(QStringLiteral("name")).toString() << "  "
                        << image.value(QStringLiteral("sizeText")).toString() << '\n';
                }
            return 0;
        }
        if (action == QStringLiteral("add") && arguments.size() >= 3) {
            const QString source = QFileInfo(arguments.at(2)).absoluteFilePath();
            const QString storage = libvirt.importIso(source, &error);
            if (storage.isEmpty())
                return fail(error);
            const QString id = library.add(source, storage, &error);
            if (id.isEmpty()) {
                QString cleanup;
                libvirt.deleteVolumeByPath(storage, &cleanup);
                return fail(error);
            }
            out << "Добавлен ISO-образ: " << id << '\n';
            return 0;
        }
        if (action == QStringLiteral("remove") && arguments.size() >= 3) {
            const QString id = arguments.at(2);
            const QString path = library.storagePath(id);
            if (path.isEmpty())
                return fail(QStringLiteral("ISO-образ не найден"));
            if (!libvirt.deleteVolumeByPath(path, &error))
                return fail(error);
            QString removedPath;
            if (!library.remove(id, &removedPath, &error))
                return fail(error);
            out << "ISO-образ удалён\n";
            return 0;
        }
    }

    if (group == QStringLiteral("vm")) {
        const QString action = arguments.value(1);
        if (action == QStringLiteral("import") && arguments.size() >= 4) {
            if (!libvirt.importExistingMachine(
                    arguments.at(2), QFileInfo(arguments.at(3)).absoluteFilePath(),
                    optionValue(arguments, QStringLiteral("--memory"), QStringLiteral("4096")).toInt(),
                    optionValue(arguments, QStringLiteral("--cpus"), QStringLiteral("4")).toInt(), &error))
                return fail(error);
            out << "Виртуальная машина импортирована\n";
            return 0;
        }
        if (action == QStringLiteral("list")) {
            const QVariantList machines = libvirt.domains(&error);
            if (!error.isEmpty())
                return fail(error);
            if (json)
                printJson(machines);
            else
                for (const QVariant& item : machines) {
                    const QVariantMap machine = item.toMap();
                    out << machine.value(QStringLiteral("id")).toString() << "  "
                        << machine.value(QStringLiteral("name")).toString() << "  "
                        << machine.value(QStringLiteral("state")).toString() << '\n';
                }
            return 0;
        }
        if (action == QStringLiteral("create") && arguments.size() >= 4) {
            const QString isoPath = library.storagePath(arguments.at(3));
            if (isoPath.isEmpty())
                return fail(QStringLiteral("ISO-образ не найден"));
            const QVariantMap options{
                {QStringLiteral("name"), arguments.at(2)},
                {QStringLiteral("isoPath"), isoPath},
                {QStringLiteral("memoryMiB"),
                 optionValue(arguments, QStringLiteral("--memory"), QStringLiteral("6144")).toInt()},
                {QStringLiteral("cpuCount"),
                 optionValue(arguments, QStringLiteral("--cpus"), QStringLiteral("4")).toInt()},
                {QStringLiteral("diskGiB"),
                 optionValue(arguments, QStringLiteral("--disk"), QStringLiteral("48")).toInt()},
                {QStringLiteral("useEfi"), !arguments.contains(QStringLiteral("--bios"))},
                {QStringLiteral("use3d"), arguments.contains(QStringLiteral("--3d"))}};
            if (!libvirt.createMachine(options, &error))
                return fail(error);
            out << "Виртуальная машина создана\n";
            return 0;
        }
        if (arguments.size() >= 3) {
            const QString id = arguments.at(2);
            bool ok = false;
            QString success;
            if (action == QStringLiteral("set")) {
                const QVariantMap details = libvirt.machineDetails(id, &error);
                if (details.isEmpty())
                    return fail(error);
                const int memory = optionValue(arguments, QStringLiteral("--memory"),
                                               details.value(QStringLiteral("memoryMiB")).toString())
                                       .toInt();
                const int cpus = optionValue(arguments, QStringLiteral("--cpus"),
                                             details.value(QStringLiteral("cpuCount")).toString())
                                     .toInt();
                const int disk = optionValue(arguments, QStringLiteral("--disk"),
                                             details.value(QStringLiteral("diskGiB")).toString())
                                     .toInt();
                ok = libvirt.updateMachineResources(id, memory, cpus, disk, &error);
                success = QStringLiteral("Параметры машины сохранены");
            } else if (action == QStringLiteral("graphics")) {
                const QVariantMap details = libvirt.machineDetails(id, &error);
                if (details.isEmpty())
                    return fail(error);
                const bool restart = arguments.contains(QStringLiteral("--restart"));
                if (restart && details.value(QStringLiteral("running")).toBool() &&
                    !libvirt.forceStop(id, &error))
                    return fail(error);
                ok = libvirt.updateMachineGraphics(
                    id, optionValue(arguments, QStringLiteral("--display"),
                                    details.value(QStringLiteral("displayMode"), QStringLiteral("windowed")).toString()),
                    optionValue(arguments, QStringLiteral("--gpu"),
                                details.value(QStringLiteral("gpuId"), QStringLiteral("auto")).toString()),
                    arguments.contains(QStringLiteral("--3d")), &error);
                if (ok && restart)
                    ok = libvirt.start(id, &error);
                success = restart ? QStringLiteral("Машина перезапущена с новой графикой")
                                  : QStringLiteral("Параметры графики сохранены");
            } else if (action == QStringLiteral("start")) {
                ok = libvirt.start(id, &error);
                success = QStringLiteral("Машина запущена");
            } else if (action == QStringLiteral("open")) {
                ok = libvirt.openDisplay(id, &error);
                success = QStringLiteral("Экран открыт");
            } else if (action == QStringLiteral("reset")) {
                ok = libvirt.reset(id, &error);
                success = QStringLiteral("Машина перезагружена");
            } else if (action == QStringLiteral("shutdown")) {
                ok = libvirt.shutdown(id, &error);
                success = QStringLiteral("Запрос на выключение отправлен");
            } else if (action == QStringLiteral("stop")) {
                ok = libvirt.forceStop(id, &error);
                success = QStringLiteral("Машина остановлена");
            } else if (action == QStringLiteral("delete")) {
                ok = libvirt.removeMachine(id, !arguments.contains(QStringLiteral("--keep-disk")), &error);
                success = QStringLiteral("Машина удалена");
            } else {
                return fail(QStringLiteral("Неизвестное действие с виртуальной машиной"));
            }
            if (!ok)
                return fail(error);
            out << success << '\n';
            return 0;
        }
    }

    if (group == QStringLiteral("snapshot")) {
        const QString action = arguments.value(1);
        const QString id = arguments.value(2);
        if (action == QStringLiteral("list") && !id.isEmpty()) {
            const QVariantList snapshots = libvirt.snapshots(id, &error);
            if (!error.isEmpty())
                return fail(error);
            if (json)
                printJson(snapshots);
            else
                for (const QVariant& item : snapshots) {
                    const QVariantMap snapshot = item.toMap();
                    out << snapshot.value(QStringLiteral("name")).toString() << "  "
                        << snapshot.value(QStringLiteral("createdAt")).toString() << '\n';
                }
            return 0;
        }
        if (!id.isEmpty() && arguments.size() >= 4) {
            const QString name = arguments.at(3);
            bool ok = false;
            QString success;
            if (action == QStringLiteral("create")) {
                ok = libvirt.createSnapshot(id, name, &error);
                success = QStringLiteral("Снимок создан");
            } else if (action == QStringLiteral("revert")) {
                ok = libvirt.revertSnapshot(id, name, &error);
                success = QStringLiteral("Состояние восстановлено");
            } else if (action == QStringLiteral("delete")) {
                ok = libvirt.removeSnapshot(id, name, &error);
                success = QStringLiteral("Снимок удалён");
            } else {
                return fail(QStringLiteral("Неизвестное действие со снимком"));
            }
            if (!ok)
                return fail(error);
            out << success << '\n';
            return 0;
        }
    }

    if (group == QStringLiteral("backup")) {
        const QString action = arguments.value(1);
        const QString id = arguments.value(2);
        const QString documents = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
        const QString root =
            QSettings()
                .value(QStringLiteral("backups/directory"), documents + QStringLiteral("/Isora Backups"))
                .toString();
        if (action == QStringLiteral("list") && !id.isEmpty()) {
            const QVariantList items = libvirt.backups(id, root, &error);
            if (!error.isEmpty())
                return fail(error);
            if (json)
                printJson(items);
            else
                for (const QVariant& item : items)
                    out << item.toMap().value(QStringLiteral("path")).toString() << '\n';
            return 0;
        }
        if (action == QStringLiteral("create") && !id.isEmpty()) {
            const QString path = libvirt.createBackup(id, root, &error);
            if (path.isEmpty())
                return fail(error);
            out << path << '\n';
            return 0;
        }
        if (arguments.size() >= 4) {
            const QString path = arguments.at(3);
            bool ok = false;
            if (action == QStringLiteral("verify"))
                ok = libvirt.verifyBackup(path, &error);
            else if (action == QStringLiteral("restore"))
                ok = libvirt.restoreBackup(id, path, &error);
            else if (action == QStringLiteral("delete"))
                ok = libvirt.removeBackup(path, root, &error);
            else
                return fail(QStringLiteral("Неизвестное действие с резервной копией"));
            if (!ok)
                return fail(error);
            out << "Готово\n";
            return 0;
        }
    }

    usage();
    return fail(QStringLiteral("неверная команда"));
}
