#include <QtTest>

#include "core/ReleaseVersion.h"

class ReleaseVersionTest final : public QObject
{
    Q_OBJECT

  private slots:
    void parsesTags();
    void rejectsInvalidValues();
    void ordersSemVerPrecedence();
};

void ReleaseVersionTest::parsesTags()
{
    const ReleaseVersion version = ReleaseVersion::parse(QStringLiteral("v0.1.0-alpha1"));
    QVERIFY(version.isValid());
    QVERIFY(version.isPrerelease());
    QCOMPARE(version.toString(), QStringLiteral("0.1.0-alpha1"));
    QVERIFY(!ReleaseVersion::parse(QStringLiteral("0.1.0")).isPrerelease());
}

void ReleaseVersionTest::rejectsInvalidValues()
{
    QVERIFY(!ReleaseVersion::parse(QStringLiteral("0.1")).isValid());
    QVERIFY(!ReleaseVersion::parse(QStringLiteral("0.1.0-alpha.01")).isValid());
    QVERIFY(!ReleaseVersion::parse(QStringLiteral("release-0.1.0")).isValid());
}

void ReleaseVersionTest::ordersSemVerPrecedence()
{
    const QStringList ordered{QStringLiteral("0.1.0-alpha1"), QStringLiteral("0.1.0-alpha2"),
                              QStringLiteral("0.1.0-beta1"), QStringLiteral("0.1.0-rc1"),
                              QStringLiteral("0.1.0"), QStringLiteral("0.1.1")};
    for (qsizetype index = 1; index < ordered.size(); ++index) {
        const ReleaseVersion previous = ReleaseVersion::parse(ordered.at(index - 1));
        const ReleaseVersion current = ReleaseVersion::parse(ordered.at(index));
        QVERIFY2(previous < current, qPrintable(ordered.at(index - 1) + QStringLiteral(" must precede ") + ordered.at(index)));
    }
}

QTEST_GUILESS_MAIN(ReleaseVersionTest)

#include "ReleaseVersionTest.moc"
