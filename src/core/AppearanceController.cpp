#include "AppearanceController.h"

#include <QGuiApplication>
#include <QPalette>
#include <QSettings>
#include <QStyleHints>
#include <QStringList>

AppearanceController::AppearanceController(QObject* parent) : QObject(parent)
{
    connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged, this,
            [this] { emit appearanceChanged(); });
    connect(qGuiApp, &QGuiApplication::paletteChanged, this, [this] { emit appearanceChanged(); });
}

QString AppearanceController::normalizedTheme(const QString& value)
{
    return value == QStringLiteral("light") || value == QStringLiteral("dark") ? value : QStringLiteral("system");
}

QString AppearanceController::normalizedAccent(const QString& value)
{
    static const QStringList values{QStringLiteral("auto"), QStringLiteral("blue"), QStringLiteral("violet"),
                                    QStringLiteral("teal"), QStringLiteral("amber"), QStringLiteral("rose"),
                                    QStringLiteral("custom")};
    return values.contains(value) ? value : QStringLiteral("auto");
}

QString AppearanceController::themeMode() const
{
    return normalizedTheme(QSettings().value(QStringLiteral("appearance/theme"), QStringLiteral("dark")).toString());
}

QString AppearanceController::accentMode() const
{
    return normalizedAccent(QSettings().value(QStringLiteral("appearance/accent"), QStringLiteral("blue")).toString());
}

QColor AppearanceController::customAccent() const
{
    const QColor value(QSettings().value(QStringLiteral("appearance/customAccent"), QStringLiteral("#5B8DEF")).toString());
    return value.isValid() ? value : QColor(QStringLiteral("#5B8DEF"));
}

QColor AppearanceController::accent() const
{
    const QString mode = accentMode();
    if (mode == QStringLiteral("auto")) {
        const QColor system = qGuiApp->palette().color(QPalette::Highlight);
        return system.isValid() ? system : QColor(QStringLiteral("#5B8DEF"));
    }
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

bool AppearanceController::dark() const
{
    if (themeMode() == QStringLiteral("dark"))
        return true;
    if (themeMode() == QStringLiteral("light"))
        return false;
    return QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
}

bool AppearanceController::reducedMotion() const
{
    return QSettings().value(QStringLiteral("appearance/reducedMotion"), false).toBool();
}

void AppearanceController::setThemeMode(const QString& value)
{
    const QString normalized = normalizedTheme(value);
    if (themeMode() == normalized)
        return;
    QSettings().setValue(QStringLiteral("appearance/theme"), normalized);
    emit appearanceChanged();
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
