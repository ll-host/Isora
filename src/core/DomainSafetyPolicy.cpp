#include "DomainSafetyPolicy.h"
#include "RenderDevice.h"

#include <QDir>
#include <QDomDocument>

namespace
{
QString firstText(const QDomElement& parent, const QString& tag)
{
    const QDomNodeList nodes = parent.elementsByTagName(tag);
    return nodes.isEmpty() ? QString() : nodes.at(0).toElement().text();
}
} // namespace

bool DomainSafetyPolicy::validate(const QString& xml, const QString& poolPath, QString* error)
{
    QDomDocument document;
    if (!document.setContent(xml)) {
        *error = QStringLiteral("Внутренняя ошибка конфигурации виртуальной машины");
        return false;
    }
    const QDomElement root = document.documentElement();
    if (root.tagName() != QStringLiteral("domain") || root.attribute(QStringLiteral("type")) != QStringLiteral("kvm")) {
        *error = QStringLiteral("Разрешены только изолированные машины KVM");
        return false;
    }
    if (!firstText(root, QStringLiteral("name")).startsWith(QStringLiteral("isora-"))) {
        *error = QStringLiteral("Небезопасное имя домена");
        return false;
    }

    for (const QString& forbidden : {QStringLiteral("hostdev"), QStringLiteral("filesystem"),
                                     QStringLiteral("redirdev"), QStringLiteral("smartcard")}) {
        if (!root.elementsByTagName(forbidden).isEmpty()) {
            *error = QStringLiteral("Конфигурация содержит запрещённое устройство: %1").arg(forbidden);
            return false;
        }
    }

    const QString rootPath = QDir::cleanPath(poolPath) + QLatin1Char('/');
    const QDomNodeList disks = root.elementsByTagName(QStringLiteral("disk"));
    if (disks.isEmpty()) {
        *error = QStringLiteral("Виртуальная машина должна иметь изолированный диск");
        return false;
    }
    for (qsizetype index = 0; index < disks.size(); ++index) {
        const QDomElement disk = disks.at(index).toElement();
        if (disk.attribute(QStringLiteral("type")) != QStringLiteral("file")) {
            *error = QStringLiteral("Isora запрещает физические и сетевые диски");
            return false;
        }
        const QDomElement source = disk.firstChildElement(QStringLiteral("source"));
        const QString path = QDir::cleanPath(source.attribute(QStringLiteral("file")));
        if (!path.startsWith(rootPath)) {
            *error = QStringLiteral("Диск находится вне хранилища Isora");
            return false;
        }
        if (disk.attribute(QStringLiteral("device")) == QStringLiteral("cdrom") &&
            disk.firstChildElement(QStringLiteral("readonly")).isNull()) {
            *error = QStringLiteral("ISO-образ должен быть подключён только для чтения");
            return false;
        }
    }

    const QDomNodeList graphics = root.elementsByTagName(QStringLiteral("graphics"));
    for (qsizetype index = 0; index < graphics.size(); ++index) {
        const QDomElement item = graphics.at(index).toElement();
        const QString type = item.attribute(QStringLiteral("type"));
        if (type != QStringLiteral("spice")) {
            *error = QStringLiteral("Неподдерживаемый графический канал: %1").arg(type);
            return false;
        }
        const QDomElement gl = item.firstChildElement(QStringLiteral("gl"));
        if (!gl.isNull() && (gl.attribute(QStringLiteral("enable")) != QStringLiteral("yes") ||
                             !RenderDevices::isRenderNode(gl.attribute(QStringLiteral("rendernode"))))) {
            *error = QStringLiteral("Для SPICE GL разрешён только доступный DRM render-node");
            return false;
        }
    }
    return true;
}
