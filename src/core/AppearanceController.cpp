#include "AppearanceController.h"

#include <QGuiApplication>
#include <QPalette>
#include <QSettings>
#include <QStringList>

AppearanceController::AppearanceController(QObject* parent) : QObject(parent)
{
    connect(qGuiApp, &QGuiApplication::paletteChanged, this, [this] { emit appearanceChanged(); });
}

QString AppearanceController::normalizedAccent(const QString& value)
{
    static const QStringList values{QStringLiteral("mint"), QStringLiteral("auto"), QStringLiteral("blue"),
                                    QStringLiteral("violet"), QStringLiteral("teal"), QStringLiteral("amber"),
                                    QStringLiteral("rose"), QStringLiteral("custom")};
    return values.contains(value) ? value : QStringLiteral("mint");
}

QString AppearanceController::accentMode() const
{
    return normalizedAccent(QSettings().value(QStringLiteral("appearance/accent"), QStringLiteral("mint")).toString());
}

QColor AppearanceController::customAccent() const
{
    const QColor value(QSettings().value(QStringLiteral("appearance/customAccent"), QStringLiteral("#9FE0B4")).toString());
    return value.isValid() ? value : QColor(QStringLiteral("#9FE0B4"));
}

QColor AppearanceController::accent() const
{
    const QString mode = accentMode();
    if (mode == QStringLiteral("auto")) {
        const QColor system = qGuiApp->palette().color(QPalette::Highlight);
        return system.isValid() ? system : QColor(QStringLiteral("#9FE0B4"));
    }
    if (mode == QStringLiteral("mint"))
        return QColor(QStringLiteral("#9FE0B4"));
    if (mode == QStringLiteral("violet"))
        return QColor(QStringLiteral("#7767E8"));
    if (mode == QStringLiteral("teal"))
        return QColor(QStringLiteral("#168F91"));
    if (mode == QStringLiteral("amber"))
        return QColor(QStringLiteral("#C77B22"));
    if (mode == QStringLiteral("rose"))
        return QColor(QStringLiteral("#B04A69"));
    if (mode == QStringLiteral("custom"))
        return customAccent();
    return QColor(QStringLiteral("#4D86E8"));
}

bool AppearanceController::reducedMotion() const
{
    return QSettings().value(QStringLiteral("appearance/reducedMotion"), false).toBool();
}

void AppearanceController::setAccentMode(const QString& value)
{
    const QString normalized = normalizedAccent(value);
    if (accentMode() == normalized)
        return;
    QSettings().setValue(QStringLiteral("appearance/accent"), normalized);
    emit appearanceChanged();
}

void AppearanceController::setCustomAccent(const QColor& value)
{
    if (!value.isValid() || customAccent() == value)
        return;
    QSettings().setValue(QStringLiteral("appearance/customAccent"), value.name(QColor::HexRgb));
    QSettings().setValue(QStringLiteral("appearance/accent"), QStringLiteral("custom"));
    emit appearanceChanged();
}

void AppearanceController::setReducedMotion(bool value)
{
    if (reducedMotion() == value)
        return;
    QSettings().setValue(QStringLiteral("appearance/reducedMotion"), value);
    emit appearanceChanged();
}
