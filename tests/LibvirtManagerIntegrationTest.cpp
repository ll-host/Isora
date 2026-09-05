#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QUuid>
#include <QtTest>

#include "core/LibvirtManager.h"

namespace
{
class IntegrationCleanup
{
  public:
    QString machineId;
    QString backupPath;
    QString backupRoot;
    QString isoPath;

    ~IntegrationCleanup()
    {
        QString error;
        LibvirtManager manager;
        if (!manager.connect(&error))
            return;
        if (!machineId.isEmpty()) {
            manager.forceStop(machineId, &error);
            error.clear();
            manager.removeMachine(machineId, true, &error);
        }
        error.clear();
        if (!backupPath.isEmpty())
            manager.removeBackup(backupPath, backupRoot, &error);
        error.clear();
        if (!isoPath.isEmpty())
            manager.deleteVolumeByPath(isoPath, &error);
    }
};
} // namespace

class LibvirtManagerIntegrationTest final : public QObject
{
    Q_OBJECT

  private slots:
    void resourcesAndBackupLifecycle();
};

void LibvirtManagerIntegrationTest::resourcesAndBackupLifecycle()
{
    QTemporaryDir workspace;
    QVERIFY(workspace.isValid());

    const QString sourceIso = workspace.filePath(QStringLiteral("integration.iso"));
    QFile iso(sourceIso);
    QVERIFY(iso.open(QIODevice::WriteOnly));
    QVERIFY(iso.resize(1024 * 1024));
    iso.close();

    QString error;
    LibvirtManager manager;
    QVERIFY2(manager.connect(&error), qPrintable(error));

    IntegrationCleanup cleanup;
    cleanup.backupRoot = workspace.filePath(QStringLiteral("backups"));
    cleanup.isoPath = manager.importIso(sourceIso, &error);
    QVERIFY2(!cleanup.isoPath.isEmpty(), qPrintable(error));

    const QString label =
        QStringLiteral("Isora integration %1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces).left(8));
    const QVariantMap options{{QStringLiteral("name"), label},     {QStringLiteral("isoPath"), cleanup.isoPath},
                              {QStringLiteral("memoryMiB"), 1024}, {QStringLiteral("cpuCount"), 1},
                              {QStringLiteral("diskGiB"), 8},      {QStringLiteral("useEfi"), false},
                              {QStringLiteral("use3d"), false}};
    QVERIFY2(manager.createMachine(options, &error), qPrintable(error));
    for (const QVariant& item : manager.domains(&error)) {
        const QVariantMap machine = item.toMap();
        if (machine.value(QStringLiteral("name")).toString() == label)
            cleanup.machineId = machine.value(QStringLiteral("id")).toString();
    }
    QVERIFY2(!cleanup.machineId.isEmpty(), "The integration domain was not listed");

    QVERIFY2(manager.updateMachineResources(cleanup.machineId, 2048, 2, 9, &error), qPrintable(error));
    QVariantMap details = manager.machineDetails(cleanup.machineId, &error);
    QCOMPARE(details.value(QStringLiteral("memoryMiB")).toInt(), 2048);
    QCOMPARE(details.value(QStringLiteral("cpuCount")).toInt(), 2);
    QCOMPARE(details.value(QStringLiteral("diskGiB")).toInt(), 9);
    const QString beforeRestore = details.value(QStringLiteral("diskPath")).toString();

    error.clear();
    QVERIFY(!manager.updateMachineResources(cleanup.machineId, 2048, 2, 8, &error));
    QVERIFY(error.contains(QStringLiteral("Уменьшение")));
    QCOMPARE(manager.machineDetails(cleanup.machineId, &error).value(QStringLiteral("diskGiB")).toInt(), 9);

    cleanup.backupPath = manager.createBackup(cleanup.machineId, cleanup.backupRoot, &error);
    QVERIFY2(!cleanup.backupPath.isEmpty(), qPrintable(error));
    QVERIFY2(manager.verifyBackup(cleanup.backupPath, &error), qPrintable(error));
    QVERIFY2(manager.restoreBackup(cleanup.machineId, cleanup.backupPath, &error), qPrintable(error));

    details = manager.machineDetails(cleanup.machineId, &error);
    QVERIFY(details.value(QStringLiteral("diskPath")).toString() != beforeRestore);
    QCOMPARE(details.value(QStringLiteral("memoryMiB")).toInt(), 2048);
    QCOMPARE(details.value(QStringLiteral("cpuCount")).toInt(), 2);
    QCOMPARE(details.value(QStringLiteral("diskGiB")).toInt(), 9);

    QVERIFY2(manager.start(cleanup.machineId, &error), qPrintable(error));
    error.clear();
    QVERIFY(!manager.updateMachineResources(cleanup.machineId, 3072, 2, 9, &error));
    QVERIFY(error.contains(QStringLiteral("выключите")));
    error.clear();
    QVERIFY2(manager.forceStop(cleanup.machineId, &error), qPrintable(error));

    QFile damaged(QDir(cleanup.backupPath).filePath(QStringLiteral("disk.qcow2")));
    QVERIFY(damaged.open(QIODevice::ReadWrite));
    QVERIFY(damaged.resize(32));
    damaged.close();
    error.clear();
    QVERIFY(!manager.verifyBackup(cleanup.backupPath, &error));
    QVERIFY(error.contains(QStringLiteral("Контрольная сумма")));
}

QTEST_GUILESS_MAIN(LibvirtManagerIntegrationTest)

#include "LibvirtManagerIntegrationTest.moc"
