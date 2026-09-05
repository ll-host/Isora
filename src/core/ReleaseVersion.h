#pragma once

#include <QString>
#include <QStringList>

class ReleaseVersion
{
  public:
    static ReleaseVersion parse(QString value);

    bool isValid() const;
    bool isPrerelease() const;
    QString toString() const;

    friend bool operator==(const ReleaseVersion& left, const ReleaseVersion& right);
    friend bool operator<(const ReleaseVersion& left, const ReleaseVersion& right);

  private:
    bool m_valid = false;
    int m_major = 0;
    int m_minor = 0;
    int m_patch = 0;
    QStringList m_prerelease;
};
