#include "UpdateChecker.h"

#include "ReleaseVersion.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDesktopServices>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSettings>
#include <QScopeGuard>
#include <QTimer>

namespace
{
constexpr qint64 CheckIntervalSeconds = 24 * 60 * 60;

bool isPlatformAsset(const QString& name)
{
#ifdef Q_OS_WIN
    return name.endsWith(QStringLiteral(".exe"), Qt::CaseInsensitive) &&
           name.contains(QStringLiteral("windows"), Qt::CaseInsensitive);
#else
    return name.endsWith(QStringLiteral(".pkg.tar.zst"), Qt::CaseInsensitive) ||
           (name.endsWith(QStringLiteral(".tar.gz"), Qt::CaseInsensitive) &&
            name.contains(QStringLiteral("Linux"), Qt::CaseInsensitive));
#endif
}
} // namespace

UpdateChecker::UpdateChecker(QObject* parent) : QObject(parent), m_network(new QNetworkAccessManager(this))
{
    if (automaticChecks())
        QTimer::singleShot(2500, this, [this] { check(false); });
}

bool UpdateChecker::checking() const { return m_checking; }
bool UpdateChecker::updateAvailable() const { return m_updateAvailable; }
QString UpdateChecker::latestVersion() const { return m_latestVersion; }
QString UpdateChecker::statusText() const { return m_statusText; }
QString UpdateChecker::releaseUrl() const { return m_releaseUrl.toString(); }
QString UpdateChecker::assetName() const { return m_assetName; }
qint64 UpdateChecker::assetSize() const { return m_assetSize; }

QString UpdateChecker::channel() const
{
    const QString value = QSettings().value(QStringLiteral("updates/channel"), QStringLiteral("preview")).toString();
    return value == QStringLiteral("stable") ? value : QStringLiteral("preview");
}

bool UpdateChecker::automaticChecks() const
{
    return QSettings().value(QStringLiteral("updates/automaticChecks"), true).toBool();
}

void UpdateChecker::setChannel(const QString& value)
{
    const QString normalized = value == QStringLiteral("stable") ? value : QStringLiteral("preview");
    if (channel() == normalized)
        return;
    QSettings().setValue(QStringLiteral("updates/channel"), normalized);
    emit settingsChanged();
    clearResult();
}

void UpdateChecker::setAutomaticChecks(bool value)
{
    if (automaticChecks() == value)
        return;
    QSettings().setValue(QStringLiteral("updates/automaticChecks"), value);
    emit settingsChanged();
}

void UpdateChecker::checkNow()
{
    check(true);
}

void UpdateChecker::openReleasePage() const
{
    if (m_releaseUrl.isValid())
        QDesktopServices::openUrl(m_releaseUrl);
}

void UpdateChecker::check(bool force)
{
    if (m_checking)
        return;
    QSettings settings;
    const QDateTime lastCheck = settings.value(QStringLiteral("updates/lastCheckUtc")).toDateTime();
    if (!force && lastCheck.isValid() && lastCheck.secsTo(QDateTime::currentDateTimeUtc()) < CheckIntervalSeconds)
        return;

    clearResult();
    m_checking = true;
    m_statusText = QStringLiteral("Проверяем GitHub Releases…");
    emit stateChanged();

    QNetworkRequest request(QUrl(QStringLiteral("https://api.github.com/repos/ll-host/Isora/releases?per_page=20")));
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setRawHeader("X-GitHub-Api-Version", "2022-11-28");
    request.setRawHeader("User-Agent", QByteArrayLiteral("Isora/") + QCoreApplication::applicationVersion().toUtf8());
    QNetworkReply* reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply] { handleReply(reply); });
}

void UpdateChecker::handleReply(QNetworkReply* reply)
{
    const auto cleanup = qScopeGuard([reply] { reply->deleteLater(); });
    m_checking = false;
    QSettings().setValue(QStringLiteral("updates/lastCheckUtc"), QDateTime::currentDateTimeUtc());

    if (reply->error() != QNetworkReply::NoError) {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        m_statusText = status == 404
                           ? QStringLiteral("Private alpha проверяется вручную через закрытый GitHub Releases")
                           : QStringLiteral("Не удалось проверить обновления: %1").arg(reply->errorString());
        emit stateChanged();
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(reply->readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isArray()) {
        m_statusText = QStringLiteral("GitHub вернул некорректный список релизов");
        emit stateChanged();
        return;
    }

    const ReleaseVersion current = ReleaseVersion::parse(QCoreApplication::applicationVersion());
    ReleaseVersion newest;
    QJsonObject newestRelease;
    for (const QJsonValue& value : document.array()) {
        const QJsonObject release = value.toObject();
        if (release.value(QStringLiteral("draft")).toBool())
            continue;
        if (channel() == QStringLiteral("stable") && release.value(QStringLiteral("prerelease")).toBool())
            continue;
        const ReleaseVersion candidate = ReleaseVersion::parse(release.value(QStringLiteral("tag_name")).toString());
        if (!candidate.isValid())
            continue;
        if (!newest.isValid() || newest < candidate) {
            newest = candidate;
            newestRelease = release;
        }
    }

    if (!newest.isValid()) {
        m_statusText = QStringLiteral("В выбранном канале пока нет релизов");
        emit stateChanged();
        return;
    }

    m_latestVersion = newest.toString();
    m_releaseUrl = QUrl(newestRelease.value(QStringLiteral("html_url")).toString());
    for (const QJsonValue& value : newestRelease.value(QStringLiteral("assets")).toArray()) {
        const QJsonObject asset = value.toObject();
        const QString name = asset.value(QStringLiteral("name")).toString();
        if (!isPlatformAsset(name))
            continue;
        m_assetName = name;
        m_assetSize = asset.value(QStringLiteral("size")).toInteger();
        break;
    }
    m_updateAvailable = current.isValid() && current < newest;
    m_statusText = m_updateAvailable ? QStringLiteral("Доступна версия %1").arg(m_latestVersion)
                                     : QStringLiteral("Установлена актуальная версия %1").arg(current.toString());
    emit stateChanged();
}

void UpdateChecker::clearResult()
{
    m_updateAvailable = false;
    m_latestVersion.clear();
    m_releaseUrl.clear();
    m_assetName.clear();
    m_assetSize = 0;
    m_statusText.clear();
    emit stateChanged();
}
