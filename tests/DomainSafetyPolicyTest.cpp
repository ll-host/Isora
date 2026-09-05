#include <QtTest>

#include "core/DomainSafetyPolicy.h"

class DomainSafetyPolicyTest final : public QObject
{
    Q_OBJECT

  private slots:
    void acceptsManagedFiles();
    void rejectsBlockDevice();
    void rejectsOutsideFile();
    void rejectsHostDevice();
    void rejectsSharedDirectory();
    void rejectsWritableIso();
    void rejectsForeignDomain();
    void rejectsVnc();
    void rejectsEglHeadless();
    void rejectsUnknownSpiceRenderNode();
};

static QString domainWith(const QString& devices, const QString& name = QStringLiteral("isora-test"))
{
    return QStringLiteral("<domain type='kvm'><name>%1</name><devices>%2</devices></domain>").arg(name, devices);
}

void DomainSafetyPolicyTest::acceptsManagedFiles()
{
    const QString devices = QStringLiteral(
        "<disk type='file' device='disk'><source file='/var/lib/libvirt/images/isora/test.qcow2'/></disk>"
        "<disk type='file' device='cdrom'><source file='/var/lib/libvirt/images/isora/test.iso'/><readonly/></disk>");
    QString error;
    QVERIFY2(
        DomainSafetyPolicy::validate(domainWith(devices), QStringLiteral("/var/lib/libvirt/images/isora"), &error),
        qPrintable(error));
}

void DomainSafetyPolicyTest::rejectsBlockDevice()
{
    QString error;
    QVERIFY(!DomainSafetyPolicy::validate(
        domainWith(QStringLiteral("<disk type='block' device='disk'><source dev='/dev/nvme0n1'/></disk>")),
        QStringLiteral("/var/lib/libvirt/images/isora"), &error));
}

void DomainSafetyPolicyTest::rejectsOutsideFile()
{
    QString error;
    QVERIFY(!DomainSafetyPolicy::validate(
        domainWith(QStringLiteral("<disk type='file' device='disk'><source file='/home/user/private.img'/></disk>")),
        QStringLiteral("/var/lib/libvirt/images/isora"), &error));
}

void DomainSafetyPolicyTest::rejectsHostDevice()
{
    QString error;
    QVERIFY(!DomainSafetyPolicy::validate(
        domainWith(QStringLiteral(
            "<disk type='file' device='disk'><source file='/var/lib/libvirt/images/isora/a.qcow2'/></disk><hostdev "
            "mode='subsystem' type='pci'/>")),
        QStringLiteral("/var/lib/libvirt/images/isora"), &error));
}

void DomainSafetyPolicyTest::rejectsSharedDirectory()
{
    QString error;
    QVERIFY(!DomainSafetyPolicy::validate(
        domainWith(QStringLiteral("<disk type='file' device='disk'><source "
                                  "file='/var/lib/libvirt/images/isora/a.qcow2'/></disk><filesystem "
                                  "type='mount'><source dir='/home'/></filesystem>")),
        QStringLiteral("/var/lib/libvirt/images/isora"), &error));
}

void DomainSafetyPolicyTest::rejectsWritableIso()
{
    QString error;
    QVERIFY(!DomainSafetyPolicy::validate(
        domainWith(QStringLiteral(
            "<disk type='file' device='cdrom'><source file='/var/lib/libvirt/images/isora/a.iso'/></disk>")),
        QStringLiteral("/var/lib/libvirt/images/isora"), &error));
}

void DomainSafetyPolicyTest::rejectsForeignDomain()
{
    QString error;
    QVERIFY(!DomainSafetyPolicy::validate(
        domainWith(
            QStringLiteral(
                "<disk type='file' device='disk'><source file='/var/lib/libvirt/images/isora/a.qcow2'/></disk>"),
            QStringLiteral("personal-vm")),
        QStringLiteral("/var/lib/libvirt/images/isora"), &error));
}

void DomainSafetyPolicyTest::rejectsVnc()
{
    const QString devices = QStringLiteral(
        "<disk type='file' device='disk'><source file='/var/lib/libvirt/images/isora/a.qcow2'/></disk>"
        "<graphics type='vnc' listen='127.0.0.1'><listen type='address' address='127.0.0.1'/></graphics>");
    QString error;
    QVERIFY(
        !DomainSafetyPolicy::validate(domainWith(devices), QStringLiteral("/var/lib/libvirt/images/isora"), &error));
}

void DomainSafetyPolicyTest::rejectsEglHeadless()
{
    const QString devices =
        QStringLiteral("<disk type='file' device='disk'><source file='/var/lib/libvirt/images/isora/a.qcow2'/></disk>"
                       "<graphics type='egl-headless'><gl rendernode='/dev/dri/renderD129'/></graphics>");
    QString error;
    QVERIFY(
        !DomainSafetyPolicy::validate(domainWith(devices), QStringLiteral("/var/lib/libvirt/images/isora"), &error));
}

void DomainSafetyPolicyTest::rejectsUnknownSpiceRenderNode()
{
    const QString devices =
        QStringLiteral("<disk type='file' device='disk'><source file='/var/lib/libvirt/images/isora/a.qcow2'/></disk>"
                       "<graphics type='spice'><gl enable='yes' rendernode='/dev/dri/renderD999'/></graphics>");
    QString error;
    QVERIFY(
        !DomainSafetyPolicy::validate(domainWith(devices), QStringLiteral("/var/lib/libvirt/images/isora"), &error));
}

QTEST_MAIN(DomainSafetyPolicyTest)
#include "DomainSafetyPolicyTest.moc"
