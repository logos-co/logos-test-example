#include <QCoreApplication>
#include <QDir>
#include <QDebug>
#include <QStringList>
#include <iostream>
#include <QCommandLineParser>

// Import the C API from liblogos_core
extern "C" {
    void logos_core_init(int argc, char *argv[]);
    void logos_core_set_plugins_dir(const char* plugins_dir);
    void logos_core_start();
    int logos_core_exec();
    void logos_core_cleanup();
    char** logos_core_get_loaded_plugins();
    char** logos_core_get_known_plugins();
    int logos_core_load_plugin(const char* plugin_name);
    char* logos_core_process_plugin(const char* plugin_path);
}

// Helper function to convert C-style array to QStringList
QStringList convertPluginsToStringList(char** plugins) {
    QStringList result;
    if (plugins) {
        for (int i = 0; plugins[i] != nullptr; i++) {
            result.append(plugins[i]);
        }
    }
    return result;
}

int main(int argc, char *argv[])
{
    std::cout << "=== Logos Test Example ===" << std::endl;
    
    // Parse command line arguments BEFORE initializing logos core
    QCoreApplication app(argc, argv);
    app.setApplicationName("logos-test-example");
    app.setApplicationVersion("1.0.0");
    
    QCommandLineParser parser;
    parser.setApplicationDescription("Logos Test Example - Loads and tests Logos plugins");
    parser.addHelpOption();
    parser.addVersionOption();
    
    QCommandLineOption modulePathOption(QStringList() << "m" << "module-path",
                                       "Path to the modules directory",
                                       "path");
    parser.addOption(modulePathOption);
    
    parser.process(app);
    
    // Determine plugins directory
    QString pluginsDir;
    if (parser.isSet(modulePathOption)) {
        pluginsDir = QDir::cleanPath(parser.value(modulePathOption));
        std::cout << "Using custom module path: " << pluginsDir.toStdString() << std::endl;
    } else {
        pluginsDir = QDir::cleanPath(QCoreApplication::applicationDirPath() + "/../modules");
        std::cout << "Using default module path: " << pluginsDir.toStdString() << std::endl;
    }
    
    // Initialize logos core (but don't create another QCoreApplication)
    logos_core_init(0, nullptr);  // Pass 0, nullptr since we already have QCoreApplication
    std::cout << "Logos Core initialized" << std::endl;
    
    std::cout << "Setting plugins directory to: " << pluginsDir.toStdString() << std::endl;
    logos_core_set_plugins_dir(pluginsDir.toUtf8().constData());
    
    // Start the core (this discovers and processes plugins)
    logos_core_start();
    std::cout << "Logos Core started successfully!" << std::endl;
    
    // Get and display known plugins
    char** knownPlugins = logos_core_get_known_plugins();
    QStringList knownList = convertPluginsToStringList(knownPlugins);
    
    std::cout << "\n=== Known Plugins ===" << std::endl;
    if (knownList.isEmpty()) {
        std::cout << "No plugins found." << std::endl;
    } else {
        std::cout << "Found " << knownList.size() << " plugin(s):" << std::endl;
        foreach (const QString &plugin, knownList) {
            std::cout << "  - " << plugin.toStdString() << std::endl;
        }
    }
    
    // Determine plugin extension based on platform
    QString pluginExtension;
#if defined(Q_OS_MAC)
    pluginExtension = ".dylib";
#elif defined(Q_OS_WIN)
    pluginExtension = ".dll";
#else // Linux and others
    pluginExtension = ".so";
#endif
    
    // Try to load the package_manager plugin
    std::cout << "\n=== Loading Plugins ===" << std::endl;
    QString packageManagerPath = pluginsDir + "/package_manager_plugin" + pluginExtension;
    std::cout << "Processing package_manager plugin from: " << packageManagerPath.toStdString() << std::endl;
    logos_core_process_plugin(packageManagerPath.toUtf8().constData());
    
    bool loaded = logos_core_load_plugin("package_manager");
    if (loaded) {
        std::cout << "✓ package_manager plugin loaded successfully" << std::endl;
    } else {
        std::cout << "✗ Failed to load package_manager plugin" << std::endl;
    }
    
    // Try to load the capability_module plugin
    QString capabilityModulePath = pluginsDir + "/capability_module_plugin" + pluginExtension;
    std::cout << "Processing capability_module plugin from: " << capabilityModulePath.toStdString() << std::endl;
    logos_core_process_plugin(capabilityModulePath.toUtf8().constData());
    
    loaded = logos_core_load_plugin("capability_module");
    if (loaded) {
        std::cout << "✓ capability_module plugin loaded successfully" << std::endl;
    } else {
        std::cout << "✗ Failed to load capability_module plugin" << std::endl;
    }
    
    // Get and display loaded plugins
    char** loadedPlugins = logos_core_get_loaded_plugins();
    QStringList loadedList = convertPluginsToStringList(loadedPlugins);
    
    std::cout << "\n=== Loaded Plugins ===" << std::endl;
    if (loadedList.isEmpty()) {
        std::cout << "No plugins loaded." << std::endl;
    } else {
        std::cout << "Currently loaded " << loadedList.size() << " plugin(s):" << std::endl;
        foreach (const QString &plugin, loadedList) {
            std::cout << "  - " << plugin.toStdString() << std::endl;
        }
    }
    
    std::cout << "\n=== Running Event Loop ===" << std::endl;
    std::cout << "Press Ctrl+C to exit..." << std::endl;
    
    // Run the event loop
    int result = logos_core_exec();
    
    // Cleanup
    std::cout << "\nCleaning up..." << std::endl;
    logos_core_cleanup();
    
    return result;
}

