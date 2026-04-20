#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;

    // Expose the assets directory to QML as a file:// URL string
    engine.rootContext()->setContextProperty(
        QStringLiteral("assetsPath"),
        QUrl::fromLocalFile(QStringLiteral(ASSETS_PATH)).toString()
    );

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("ntchess", "Main");

    return QCoreApplication::exec();
}

