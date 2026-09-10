#pragma once

#include <QColor>
#include <QObject>

class AppearanceController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString accentMode READ accentMode WRITE setAccentMode NOTIFY appearanceChanged)
    Q_PROPERTY(QColor customAccent READ customAccent WRITE setCustomAccent NOTIFY appearanceChanged)
    Q_PROPERTY(QColor accent READ accent NOTIFY appearanceChanged)
    Q_PROPERTY(bool reducedMotion READ reducedMotion WRITE setReducedMotion NOTIFY appearanceChanged)

  public:
    explicit AppearanceController(QObject* parent = nullptr);

    QString accentMode() const;
    QColor customAccent() const;
    QColor accent() const;
    bool reducedMotion() const;

    void setAccentMode(const QString& value);
    void setCustomAccent(const QColor& value);
    void setReducedMotion(bool value);

  signals:
    void appearanceChanged();

  private:
    static QString normalizedAccent(const QString& value);
};
