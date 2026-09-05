#include <QCommandLineParser>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QScreen>
#include <QSettings>
#include <QTextStream>
#include <QTimer>

#include "core/AppController.h"
#include "core/AppearanceController.h"
#include "core/UpdateChecker.h"

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("Isora"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("github.com/ll-host"));
    QCoreApplication::setApplicationName(QStringLiteral("Isora"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("Isora"));
    QGuiApplication::setWindowIcon(QIcon(QStringLiteral(":/qt/qml/Isora/qml/assets/icons/app.svg")));
    QCoreApplication::setApplicationVersion(QStringLiteral(ISORA_VERSION));
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QCommandLineParser parser;
    parser.addHelpOption();
    parser.addOption({QStringList{QStringLiteral("v"), QStringLiteral("version")}, QStringLiteral("Показать версию")});
    parser.addOption(
        {QStringLiteral("screenshot"), QStringLiteral("Сохранить снимок интерфейса"), QStringLiteral("path")});
    parser.addOption({QStringLiteral("page"), QStringLiteral("Открыть страницу интерфейса"), QStringLiteral("name"),
                      QStringLiteral("machines")});
    parser.addOption(
        {QStringLiteral("width"), QStringLiteral("Ширина окна для проверки интерфейса"), QStringLiteral("pixels")});
    parser.addOption(
        {QStringLiteral("height"), QStringLiteral("Высота окна для проверки интерфейса"), QStringLiteral("pixels")});
    parser.addOption(
        {QStringLiteral("dialog"), QStringLiteral("Открыть диалог для проверки интерфейса"), QStringLiteral("name")});
    parser.process(app);
    if (parser.isSet(QStringLiteral("version"))) {
        QTextStream(stdout) << "Isora " << ISORA_VERSION << '\n';
        return 0;
    }

    AppController controller;
    AppearanceController appearanceController;
    UpdateChecker updateChecker;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("App"), &controller);
    engine.rootContext()->setContextProperty(QStringLiteral("Appearance"), &appearanceController);
    engine.rootContext()->setContextProperty(QStringLiteral("Updates"), &updateChecker);
    engine.loadFromModule(QStringLiteral("Isora"), QStringLiteral("Main"));

    if (engine.rootObjects().isEmpty())
        return 1;
    QObject* root = engine.rootObjects().constFirst();
    QQuickWindow* window = qobject_cast<QQuickWindow*>(root);
    if (window && parser.isSet(QStringLiteral("width")) && parser.isSet(QStringLiteral("height"))) {
        window->resize(parser.value(QStringLiteral("width")).toInt(), parser.value(QStringLiteral("height")).toInt());
    } else if (window && !parser.isSet(QStringLiteral("screenshot"))) {
        QSettings settings;
        const QSize savedSize = settings.value(QStringLiteral("window/size"), QSize(1180, 760)).toSize();
        const QPoint savedPosition = settings.value(QStringLiteral("window/position")).toPoint();
        window->resize(savedSize.expandedTo(window->minimumSize()));
        const QRect candidate(savedPosition, window->size());
        bool visibleOnScreen = false;
        for (const QScreen* screen : QGuiApplication::screens()) {
            if (screen->availableGeometry().intersects(candidate)) {
                visibleOnScreen = true;
                break;
            }
        }
        if (visibleOnScreen)
            window->setPosition(savedPosition);
        if (settings.value(QStringLiteral("window/maximized"), false).toBool())
            QTimer::singleShot(0, window, &QQuickWindow::showMaximized);
    }
    if (window) {
        QObject::connect(&app, &QCoreApplication::aboutToQuit, window, [window] {
            QSettings settings;
            settings.setValue(QStringLiteral("window/maximized"), window->visibility() == QWindow::Maximized);
            if (window->visibility() != QWindow::Maximized && window->visibility() != QWindow::FullScreen) {
                settings.setValue(QStringLiteral("window/size"), window->size());
                settings.setValue(QStringLiteral("window/position"), window->position());
            }
        });
    }
    const QStringList pages{QStringLiteral("machines"), QStringLiteral("images"), QStringLiteral("diagnostics"),
                            QStringLiteral("settings")};
    const qsizetype page = pages.indexOf(parser.value(QStringLiteral("page")));
    if (page >= 0)
        root->setProperty("currentPage", page);
    if (parser.isSet(QStringLiteral("dialog")))
        root->setProperty("testDialog", parser.value(QStringLiteral("dialog")));
    if (parser.isSet(QStringLiteral("screenshot"))) {
        const QString path = parser.value(QStringLiteral("screenshot"));
        QTimer::singleShot(1200, &app, [window, path, &app] {
            if (window)
                window->grabWindow().save(path);
            app.quit();
        });
    }
    return app.exec();
}
