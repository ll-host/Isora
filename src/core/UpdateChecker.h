#pragma once

#include <QObject>
#include <QUrl>

class QNetworkAccessManager;
class QNetworkReply;

class UpdateChecker final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool checking READ checking NOTIFY stateChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY stateChanged)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY stateChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY stateChanged)
    Q_PROPERTY(QString releaseUrl READ releaseUrl NOTIFY stateChanged)
    Q_PROPERTY(QString assetName READ assetName NOTIFY stateChanged)
    Q_PROPERTY(qint64 assetSize READ assetSize NOTIFY stateChanged)
    Q_PROPERTY(QString channel READ channel WRITE setChannel NOTIFY settingsChanged)
    Q_PROPERTY(bool automaticChecks READ automaticChecks WRITE setAutomaticChecks NOTIFY settingsChanged)

  public:
    explicit UpdateChecker(QObject* parent = nullptr);

    bool checking() const;
    bool updateAvailable() const;
    QString latestVersion() const;
    QString statusText() const;
    QString releaseUrl() const;
    QString assetName() const;
    qint64 assetSize() const;
    QString channel() const;
    bool automaticChecks() const;

    void setChannel(const QString& value);
    void setAutomaticChecks(bool value);

    Q_INVOKABLE void checkNow();
    Q_INVOKABLE void openReleasePage() const;

  signals:
    void stateChanged();
    void settingsChanged();

  private:
    void check(bool force);
    void handleReply(QNetworkReply* reply);
    void clearResult();

    QNetworkAccessManager* m_network = nullptr;
    bool m_checking = false;
    bool m_updateAvailable = false;
    QString m_latestVersion;
    QString m_statusText;
    QUrl m_releaseUrl;
    QString m_assetName;
    qint64 m_assetSize = 0;
};
