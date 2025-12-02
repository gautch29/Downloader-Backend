import Fluent
import FluentSQLiteDriver
import Vapor

// config/configure.swift
public func configure(_ app: Application) async throws {
    // Serves files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Configure SQLite
    // We'll use the same data directory logic as the Node app
    let workingDir = app.directory.workingDirectory
    let envDataDir = Environment.get("DATA_DIR")
    app.logger.info("DATA_DIR env: \(String(describing: envDataDir))")
    
    // Go up two levels: backend -> Downloader -> Documents -> downloader-data
    let dataDir = envDataDir ?? URL(fileURLWithPath: workingDir)
        .deletingLastPathComponent() // Downloader
        .deletingLastPathComponent() // Documents
        .appendingPathComponent("downloader-data").path
        
    // Ensure data directory exists
    try? FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true)
        
    let dbPath = "\(dataDir)/downloader.db"
    
    app.logger.info("Using database at: \(dbPath)")
    
    app.databases.use(.sqlite(.file(dbPath)), as: .sqlite)

    // Register migrations
    app.migrations.add(CreateDownloads())
    app.migrations.add(CreateUsers())
    app.migrations.add(CreateSessions())
    app.migrations.add(CreateSettings())
    app.migrations.add(CreatePaths())
    app.migrations.add(AddApiKeyToSettings())
    
    // Initialize DownloadManager
    let downloadManager = DownloadManager(app: app)
    app.storage[DownloadManagerKey.self] = downloadManager
    
    // register routes
    try routes(app)
    
    // Start worker on boot
    app.lifecycle.use(DownloadWorkerLifecycle())
    
    // Register commands
    app.commands.use(CreateUserCommand(), as: "create-user")
    app.commands.use(SetApiKeyCommand(), as: "set-api-key")
}

struct DownloadManagerKey: StorageKey {
    typealias Value = DownloadManager
}

struct DownloadWorkerLifecycle: LifecycleHandler {
    func didBoot(_ application: Application) throws {
        if let manager = application.storage[DownloadManagerKey.self] {
            Task {
                await manager.startWorker()
            }
        }
    }
}
