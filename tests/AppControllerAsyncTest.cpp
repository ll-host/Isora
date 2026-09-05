#include <QCoreApplication>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTimer>
#include <QUrl>
#include <QtTest>

#include "core/AppController.h"

class AppControllerAsyncTest final : public QObject
{
    Q_OBJECT

  private slots:
    void importKeepsEventLoopResponsive();
};

void AppControllerAsyncTest::importKeepsEventLoopResponsive()
{
    QTemporaryDir dataDirectory;
    QVERIFY(dataDirectory.isValid());
    qputenv("XDG_DATA_HOME", dataDirectory.path().toUtf8());
    QCoreApplication::setOrganizationName(QStringLiteral("ll-host-tests"));
    QCoreApplication::setApplicationName(QStringLiteral("IsoraAsyncTest"));

    const QString isoPath = dataDirectory.filePath(QStringLiteral("responsive-test.iso"));
    QFile iso(isoPath);
    QVERIFY(iso.open(QIODevice::WriteOnly));
    const bool largeImport = qEnvironmentVariableIsSet("ISORA_LARGE_TEST");
    const qint64 testSize = (largeImport ? 1024LL : 64LL) * 1024LL * 1024LL;
    QVERIFY(iso.resize(testSize));
    iso.close();

    AppController controller;
    bool eventLoopTicked = false;
    int highestProgress = -1;
    connect(&controller, &AppController::operationChanged, &controller,
            [&] { highestProgress = qMax(highestProgress, controller.operationProgress()); });
    QTimer::singleShot(0, &controller, [&] { eventLoopTicked = true; });

    controller.importIso(QUrl::fromLocalFile(isoPath));
    QVERIFY(controller.busy());
    QTRY_VERIFY_WITH_TIMEOUT(eventLoopTicked, 500);
    QTRY_VERIFY_WITH_TIMEOUT(!controller.busy(), largeImport ? 120000 : 30000);
    QVERIFY2(controller.message().isEmpty(), qPrintable(controller.message()));
    QVERIFY(highestProgress > 0);
    QCOMPARE(controller.images().size(), 1);

    if (!largeImport) {
        controller.importIso(QUrl::fromLocalFile(isoPath));
        QTRY_VERIFY_WITH_TIMEOUT(!controller.busy(), 30000);
        QVERIFY(controller.message().contains(QStringLiteral("уже добавлен")));
        QCOMPARE(controller.images().size(), 1);
        controller.clearMessage();
    }

    const QString id = controller.images().constFirst().toMap().value(QStringLiteral("id")).toString();
    controller.removeIso(id);
    QTRY_VERIFY_WITH_TIMEOUT(!controller.busy(), 10000);
    QVERIFY2(controller.message().isEmpty(), qPrintable(controller.message()));
    QCOMPARE(controller.images().size(), 0);
}

QTEST_GUILESS_MAIN(AppControllerAsyncTest)

#include "AppControllerAsyncTest.moc"
