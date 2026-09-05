#include "ReleaseVersion.h"

#include <QRegularExpression>

ReleaseVersion ReleaseVersion::parse(QString value)
{
    ReleaseVersion result;
    value = value.trimmed();
    if (value.startsWith(QLatin1Char('v'), Qt::CaseInsensitive))
        value.remove(0, 1);

    static const QRegularExpression expression(
        QStringLiteral("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*))?(?:\\+[0-9A-Za-z.-]+)?$"));
    const QRegularExpressionMatch match = expression.match(value);
    if (!match.hasMatch())
        return result;

    bool majorOk = false;
    bool minorOk = false;
    bool patchOk = false;
    result.m_major = match.captured(1).toInt(&majorOk);
    result.m_minor = match.captured(2).toInt(&minorOk);
    result.m_patch = match.captured(3).toInt(&patchOk);
    result.m_prerelease = match.captured(4).split(QLatin1Char('.'), Qt::SkipEmptyParts);
    for (const QString& identifier : result.m_prerelease) {
        if (identifier.size() > 1 && identifier.startsWith(QLatin1Char('0'))) {
            bool numeric = false;
            identifier.toUInt(&numeric);
            if (numeric)
                return ReleaseVersion();
        }
    }
    result.m_valid = majorOk && minorOk && patchOk;
    return result;
}

bool ReleaseVersion::isValid() const
{
    return m_valid;
}

bool ReleaseVersion::isPrerelease() const
{
    return !m_prerelease.isEmpty();
}

QString ReleaseVersion::toString() const
{
    if (!m_valid)
        return {};
    QString result = QStringLiteral("%1.%2.%3").arg(m_major).arg(m_minor).arg(m_patch);
    if (!m_prerelease.isEmpty())
        result += QLatin1Char('-') + m_prerelease.join(QLatin1Char('.'));
    return result;
}

bool operator==(const ReleaseVersion& left, const ReleaseVersion& right)
{
    return left.m_valid == right.m_valid && left.m_major == right.m_major && left.m_minor == right.m_minor &&
           left.m_patch == right.m_patch && left.m_prerelease == right.m_prerelease;
}

bool operator<(const ReleaseVersion& left, const ReleaseVersion& right)
{
    if (!left.m_valid || !right.m_valid)
        return false;
    if (left.m_major != right.m_major)
        return left.m_major < right.m_major;
    if (left.m_minor != right.m_minor)
        return left.m_minor < right.m_minor;
    if (left.m_patch != right.m_patch)
        return left.m_patch < right.m_patch;
    if (left.m_prerelease.isEmpty() || right.m_prerelease.isEmpty())
        return !left.m_prerelease.isEmpty() && right.m_prerelease.isEmpty();

    const qsizetype count = qMin(left.m_prerelease.size(), right.m_prerelease.size());
    for (qsizetype index = 0; index < count; ++index) {
        const QString& leftPart = left.m_prerelease.at(index);
        const QString& rightPart = right.m_prerelease.at(index);
        if (leftPart == rightPart)
            continue;
        bool leftNumeric = false;
        bool rightNumeric = false;
        const quint64 leftNumber = leftPart.toULongLong(&leftNumeric);
        const quint64 rightNumber = rightPart.toULongLong(&rightNumeric);
        if (leftNumeric && rightNumeric)
            return leftNumber < rightNumber;
        if (leftNumeric != rightNumeric)
            return leftNumeric;
        return QString::compare(leftPart, rightPart, Qt::CaseSensitive) < 0;
    }
    return left.m_prerelease.size() < right.m_prerelease.size();
}
