#pragma once

#include <QList>
#include <QString>

#include <optional>

namespace RenderDevices
{
struct Device
{
    QString id;
    QString name;
    QString path;
    QString detail;
};

QList<Device> all();
std::optional<Device> preferred();
std::optional<Device> find(const QString& id);
std::optional<Device> intel();
bool isIntel(const QString& path);
bool isRenderNode(const QString& path);
} // namespace RenderDevices
