#include <QCoreApplication>
#include <QDir>
#include <QDebug>
#include <QStringList>
#include <iostream>
#include <QCommandLineParser>
#include <QPluginLoader>
#include <QMetaObject>
#include <QMetaMethod>
#include <QMetaProperty>
#include <QMetaEnum>
#include <QObject>
#include <QtPlugin>
#include <QString>
#include <string>
#include <chrono>
#include <thread>

// Include the Logos C++ SDK (only for Waku initialization)
#include "logos_api.h"
#include "logos_api_client.h"

// Waku constants
const std::string TOY_CHAT_CONTENT_TOPIC = "/toy-chat/2/baixa-chiado/proto";
const std::string DEFAULT_PUBSUB_TOPIC = "/waku/2/rs/16/32";
const std::string STORE_NODE = "/dns4/store-01.do-ams3.status.staging.status.im/tcp/30303/p2p/16Uiu2HAm3xVDaz6SRJ6kErwC21zBJEZjavVXg7VSkoWzaV1aMA3F";
const std::string CONTENT_TOPIC_PREFIX = "/toy-chat/2/";
const std::string CONTENT_TOPIC_SUFFIX = "/proto";

// Minimal local declaration of the PluginInterface with the same IID
class PluginInterface
{
public:
    virtual ~PluginInterface() {}
    virtual QString name() const = 0;
    virtual QString version() const = 0;
};

#define PluginInterface_iid "com.example.PluginInterface"
Q_DECLARE_INTERFACE(PluginInterface, PluginInterface_iid)

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
    
    // Callback type for async operations
    typedef void (*AsyncCallback)(int result, const char* message, void* user_data);
    // TODO: just for testing purposes, to avoid using the cpp-sdk here for now
    void logos_core_call_plugin_method_async(const char* plugin_name, const char* method_name, const char* params_json, AsyncCallback callback, void* user_data);
}

// Global LogosAPI instance (only for Waku initialization)
LogosAPI* g_logosAPI = nullptr;

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

// Callback function for async plugin method calls
void getPackagesCallback(int result, const char* message, void* user_data) {
    std::cout << "\n=== getPackages() Response ===" << std::endl;
    if (result) {
        std::cout << "✓ Success: " << message << std::endl;
    } else {
        std::cout << "✗ Error: " << message << std::endl;
    }
    std::cout << "=================================" << std::endl;
}

// Callback function for testPluginCall
void testPluginCallCallback(int result, const char* message, void* user_data) {
    std::cout << "\n=== testPluginCall() Response ===" << std::endl;
    if (result) {
        std::cout << "✓ Success: " << message << std::endl;
    } else {
        std::cout << "✗ Error: " << message << std::endl;
    }
    std::cout << "=================================" << std::endl;
}

// Helper function to print QVariant results (for Waku only)
void printResult(const QString& methodName, const QVariant& result) {
    std::cout << "\n=== " << methodName.toStdString() << "() Response ===" << std::endl;
    if (result.isValid()) {
        std::cout << "✓ Success: " << result.toString().toStdString() << std::endl;
    } else {
        std::cout << "✗ Error: Invalid result" << std::endl;
    }
    std::cout << "=================================" << std::endl;
}

// Function to inspect plugin methods using QPluginLoader
void inspectPluginMethods(const QString& pluginPath) {
    std::cout << "\n=== Inspecting Plugin: " << pluginPath.toStdString() << " ===" << std::endl;
    
    QPluginLoader loader(pluginPath);
    QObject *plugin = loader.instance();

    if (!plugin) {
        std::cout << "✗ Failed to load plugin: " << loader.errorString().toStdString() << std::endl;
        return;
    }

    std::cout << "✓ Plugin loaded successfully." << std::endl;

    // Try to cast to PluginInterface
    if (PluginInterface *iface = qobject_cast<PluginInterface *>(plugin)) {
        std::cout << "Plugin name: " << iface->name().toStdString() << std::endl;
        std::cout << "Plugin version: " << iface->version().toStdString() << std::endl;
    } else {
        const QMetaObject *meta = plugin->metaObject();
        if (meta) {
            std::cout << "Qt class name: " << meta->className() << std::endl;
        }
    }

    // List all available methods in the plugin
    const QMetaObject *meta = plugin->metaObject();
    if (meta) {
        std::cout << "\n=== Available Methods ===" << std::endl;
        
        // List all methods (including inherited ones)
        for (int i = 0; i < meta->methodCount(); ++i) {
            QMetaMethod method = meta->method(i);
            QString methodType;
            
            switch (method.methodType()) {
                case QMetaMethod::Method:
                    methodType = "Method";
                    break;
                case QMetaMethod::Signal:
                    methodType = "Signal";
                    break;
                case QMetaMethod::Slot:
                    methodType = "Slot";
                    break;
                case QMetaMethod::Constructor:
                    methodType = "Constructor";
                    break;
                default:
                    methodType = "Unknown";
                    break;
            }
            
            QString accessLevel;
            if (method.access() == QMetaMethod::Public) {
                accessLevel = "Public";
            } else if (method.access() == QMetaMethod::Protected) {
                accessLevel = "Protected";
            } else if (method.access() == QMetaMethod::Private) {
                accessLevel = "Private";
            } else {
                accessLevel = "Unknown";
            }
            
            std::cout << "  " << accessLevel.toStdString() << " " << methodType.toStdString() 
                      << " " << method.name().constData() << "(" 
                      << method.parameterNames().join(", ").toStdString() << ")" << std::endl;
        }
        
        std::cout << "\n=== Properties ===" << std::endl;
        for (int i = 0; i < meta->propertyCount(); ++i) {
            QMetaProperty prop = meta->property(i);
            std::cout << "  Property: " << prop.name() 
                      << " (" << prop.typeName() << ")" << std::endl;
        }
        
        std::cout << "\n=== Enums ===" << std::endl;
        for (int i = 0; i < meta->enumeratorCount(); ++i) {
            QMetaEnum enumerator = meta->enumerator(i);
            std::cout << "  Enum: " << enumerator.name() << std::endl;
            for (int j = 0; j < enumerator.keyCount(); ++j) {
                std::cout << "    " << enumerator.key(j) << " = " << enumerator.value(j) << std::endl;
            }
        }
    }
    
    std::cout << "===============================================" << std::endl;
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
    
    // Inspect the plugin methods
    inspectPluginMethods(packageManagerPath);
    
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
    
    // Inspect the plugin methods
    inspectPluginMethods(capabilityModulePath);
    
    loaded = logos_core_load_plugin("capability_module");
    if (loaded) {
        std::cout << "✓ capability_module plugin loaded successfully" << std::endl;
    } else {
        std::cout << "✗ Failed to load capability_module plugin" << std::endl;
    }
    
    // try to load waku_module plugin
    QString wakuModulePath = pluginsDir + "/waku_module_plugin" + pluginExtension;
    std::cout << "Processing waku_module plugin from: " << wakuModulePath.toStdString() << std::endl;
    logos_core_process_plugin(wakuModulePath.toUtf8().constData());
    
    loaded = logos_core_load_plugin("waku_module");
    if (loaded) {
        std::cout << "✓ waku_module plugin loaded successfully" << std::endl;
    } else {
        std::cout << "✗ Failed to load waku_module plugin" << std::endl;
    }
    
    // Inspect the plugin methods
    inspectPluginMethods(wakuModulePath);
    
    // Initialize Waku after loading the waku module
    std::cout << "\n=== Initializing Waku ===" << std::endl;
    std::cout << "Waiting 10 seconds before initializing Waku..." << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(10));
    std::cout << "10 seconds elapsed, proceeding with Waku initialization..." << std::endl;
    
    // Initialize Logos C++ SDK for Waku initialization only
    g_logosAPI = new LogosAPI("test_example");
    std::cout << "Logos C++ SDK initialized for Waku" << std::endl;
    
    std::string relayTopic = DEFAULT_PUBSUB_TOPIC;
    std::string configStr = R"({
        "host": "0.0.0.0",
        "tcpPort": 60010,
        "key": null,
        "clusterId": 16,
        "relay": true,
        "relayTopics": [")" + relayTopic + R"("],
        "shards": [1,32,64,128,256],
        "maxMessageSize": "1024KiB",
        "dnsDiscovery": true,
        "dnsDiscoveryUrl": "enrtree://AMOJVZX4V6EXP7NTJPMAYJYST2QP6AJXYW76IU6VGJS7UVSNDYZG4@boot.prod.status.nodes.status.im",
        "discv5Discovery": false,
        "numShardsInNetwork": 257,
        "discv5EnrAutoUpdate": false,
        "logLevel": "INFO",
        "keepAlive": true
    })";
    
    std::cout << "Waku configuration: " << configStr << std::endl;
    
    // Try to call initWaku on the waku module if it's available
    std::cout << "Attempting to initialize Waku module..." << std::endl;
    
    // Get client for waku_module
    LogosAPIClient* wakuClient = g_logosAPI->getClient("waku_module");
    if (wakuClient->isConnected()) {
        // Call initWaku method on the waku module
        QVariant wakuResult = wakuClient->invokeRemoteMethod("waku_module", "initWaku", configStr.c_str());
        printResult("initWaku", wakuResult);
    } else {
        std::cout << "✗ Failed to connect to waku_module" << std::endl;
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
    
    // Call getPackages() on the package_manager plugin if it's loaded
    if (loadedList.contains("package_manager")) {
        std::cout << "\n=== Calling getPackages() on package_manager ===" << std::endl;
        std::cout << "Sending async request to package_manager.getPackages()..." << std::endl;
        
        // =========================================================================
        // TODO: just for testing purposes, to avoid using the cpp-sdk here for now
        // =========================================================================
        // Call getPackages() method asynchronously (no parameters needed)
        logos_core_call_plugin_method_async(
            "package_manager",           // plugin name
            "getPackages",              // method name
            "[]",                       // empty JSON array for no parameters
            getPackagesCallback,        // callback function
            nullptr                     // user data (not needed)
        );
        
        std::cout << "Async request sent. Waiting for response..." << std::endl;
        
        // Test the new testPluginCall method
        std::cout << "\n=== Calling testPluginCall() on package_manager ===" << std::endl;
        std::cout << "Sending async request to package_manager.testPluginCall('world')..." << std::endl;
        
        // Call testPluginCall method asynchronously with a test string
        logos_core_call_plugin_method_async(
            "package_manager",           // plugin name
            "testPluginCall",           // method name
            "[{\"name\":\"foo\",\"value\":\"world\",\"type\":\"string\"}]",  // JSON array with parameter object
            testPluginCallCallback,     // callback function
            nullptr                     // user data (not needed)
        );
        
        std::cout << "Async testPluginCall request sent. Waiting for response..." << std::endl;
    } else {
        std::cout << "\n⚠️  package_manager plugin not loaded, skipping getPackages() call" << std::endl;
    }
    
    std::cout << "\n=== Running Event Loop ===" << std::endl;
    std::cout << "Press Ctrl+C to exit..." << std::endl;
    
    // Run the event loop
    int result = logos_core_exec();
    
    // Cleanup
    std::cout << "\nCleaning up..." << std::endl;
    logos_core_cleanup();
    
    // Clean up C++ SDK if it was initialized
    if (g_logosAPI) {
        delete g_logosAPI;
        g_logosAPI = nullptr;
    }
    
    return result;
}

