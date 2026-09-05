#pragma once

#include <QColor>
#include <QObject>

class AppearanceController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString themeMode READ themeMode WRITE setThemeMode NOTIFY appearanceChanged)
    Q_PROPERTY(QString accentMode READ accentMode WRITE setAccentMode NOTIFY appearanceChanged)
    Q_PROPERTY(QColor customAccent READ customAccent WRITE setCustomAccent NOTIFY appearanceChanged)
    Q_PROPERTY(QColor accent READ accent NOTIFY appearanceChanged)
    Q_PROPERTY(bool dark READ dark NOTIFY appearanceChanged)
    Q_PROPERTY(bool reducedMotion READ reducedMotion WRITE setReducedMotion NOTIFY appearanceChanged)

  public:
    explicit AppearanceController(QObject* parent = nullptr);

    QString themeMode() const;
    QString accentMode() const;
    QColor customAccent() const;
    QColor accent() const;
    bool dark() const;
    bool reducedMotion() const;

    void setThemeMode(const QString& value);
    void setAccentMode(const QString& value);
    void setCustomAccent(const QColor& value);
    void setReducedMotion(bool value);

  signals:
    void appearanceChanged();

  private:
    static QString normalizedTheme(const QString& value);
    static QString normalizedAccent(const QString& value);
};
