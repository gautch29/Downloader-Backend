import Vapor
import Fluent
import Foundation
import AsyncHTTPClient
import NIO
import NIOHTTP1
import NIOSSL
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor DownloadManager {
    let app: Application
    let downloadDir: String

    init(app: Application) {
        self.app = app
        self.downloadDir = Environment.get("DOWNLOAD_DIR") ?? app.directory.workingDirectory + "../downloads"
        
        // Ensure download directory exists
        try? FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        
    }

    func startWorker() async {
        app.logger.info("Starting Download Worker...")
        while true {
            do {
                try await processQueue()
            } catch {
                app.logger.error("Worker error: \(error)")
            }
            // Sleep for 5 seconds
            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
        }
    }

    func processQueue() async throws {
        // Find pending download
        guard let download = try await Download.query(on: app.db)
            .filter(\.$status == .pending)
            .first() else {
            return
        }

        app.logger.info("Starting download: \(download.url)")

        // Update status to downloading
        download.status = .downloading
        download.updatedAt = Date()
        try await download.save(on: app.db)

        do {
            // 1. Get direct link
            var directLink = download.url
            
            // If it's a 1fichier link, use ScraperService to get the direct link
            if download.url.contains("1fichier.com") {
                app.logger.info("Resolving 1fichier link...")
                app.logger.info("Resolving 1fichier link...")
                let scraper = ZTScraper(client: app.client)
                directLink = try await scraper.getDownloadLink(url: download.url, on: app.db)
                app.logger.info("Resolved 1fichier link: \(directLink)")
            }

            // 2. Start download
            try await downloadFile(download: download, from: directLink)

            // 3. Mark completed
            download.status = .completed
            download.progress = 100
            download.updatedAt = Date()
            try await download.save(on: app.db)
            
            app.logger.info("Download completed: \(download.filename ?? "unknown")")
            
            // Trigger Plex Scan
            let plexService = PlexService(client: app.client, db: app.db)
            await plexService.scanLibrary()

        } catch {
            app.logger.error("Download failed: \(error)")
            download.status = .error
            download.error = "\(error)"
            download.updatedAt = Date()
            try await download.save(on: app.db)
        }
    }

    func downloadFile(download: Download, from urlString: String) async throws {
        // Determine destination path
        let destinationPath = download.targetPath ?? downloadDir
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(atPath: destinationPath, withIntermediateDirectories: true)

        // Resolve IPv4 to bypass 1fichier IPv6 blocking
        guard let (ipv4UrlString, originalHost) = NetworkUtils.getIPv4URL(from: urlString),
              let url = URL(string: ipv4UrlString) else {
            throw Abort(.badRequest, reason: "Invalid URL or DNS resolution failed")
        }
        
        app.logger.info("Downloading from \(originalHost) via \(url.host ?? "unknown") (IPv4)")

        // Configure TLS to disable hostname verification (needed because we use IP in URL)
        var tlsConfig = TLSConfiguration.makeClientConfiguration()
        tlsConfig.certificateVerification = .none
        
        // Use AsyncHTTPClient for streaming
        let httpClient = HTTPClient(
            eventLoopGroupProvider: .singleton,
            configuration: HTTPClient.Configuration(tlsConfiguration: tlsConfig)
        )
        
        do {
            var request = try HTTPClient.Request(url: url)
            request.headers.add(name: "Host", value: originalHost)
            request.headers.add(name: "User-Agent", value: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
            
            let delegate = FileDownloadDelegate(
                path: destinationPath,
                download: download,
                db: app.db,
                logger: app.logger
            )
            
            let response = try await httpClient.execute(
                request: request,
                delegate: delegate
            ).get()
            
            if response.status != .ok {
                 throw Abort(.badRequest, reason: "Server returned error: \(response.status)")
            }
            
            // Update filename from delegate if it was determined
            if let filename = delegate.filename {
                download.filename = filename
                try await download.save(on: app.db)
            }
            
            try await httpClient.shutdown()
        } catch {
            try? await httpClient.shutdown()
            throw error
        }
    }
}

class FileDownloadDelegate: HTTPClientResponseDelegate {
    typealias Response = HTTPClient.Response
    
    let path: String
    let download: Download
    let db: Database
    let logger: Logger
    
    var fileHandle: FileHandle?
    var totalBytes: Int64 = 0
    var downloadedBytes: Int64 = 0
    var lastUpdate: Date = Date()
    var filename: String?
    
    init(path: String, download: Download, db: Database, logger: Logger) {
        self.path = path
        self.download = download
        self.db = db
        self.logger = logger
    }
    
    func didSendRequestHead(task: HTTPClient.Task<Response>, _ head: HTTPRequestHead) {
        // No-op
    }
    
    func didReceiveHead(task: HTTPClient.Task<Response>, _ head: HTTPResponseHead) -> EventLoopFuture<Void> {
        let total = head.headers.first(name: "Content-Length").flatMap { Int64($0) } ?? 0
        self.totalBytes = total
        
        // Determine filename
        // Try content-disposition
        var name = "file-\(download.id ?? 0)"
        if let contentDisposition = head.headers.first(name: "Content-Disposition") {
             // Simple parsing for filename=
             if let range = contentDisposition.range(of: "filename=") {
                 let sub = contentDisposition[range.upperBound...]
                 name = String(sub).replacingOccurrences(of: "\"", with: "")
             }
        }
        
        if let custom = download.customFilename, !custom.isEmpty {
            name = custom
        }
        
        self.filename = name
        
        // Update filename in DB immediately so UI shows it
        let downloadId = download.id
        _ = Download.query(on: db)
            .filter(\.$id == downloadId!)
            .set(\.$filename, to: name)
            .update()
        
        let filePath = URL(fileURLWithPath: path).appendingPathComponent(name).path
        _ = FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
        self.fileHandle = FileHandle(forWritingAtPath: filePath)
        
        return task.eventLoop.makeSucceededFuture(())
    }
    
    func didReceiveBodyPart(task: HTTPClient.Task<Response>, _ buffer: ByteBuffer) -> EventLoopFuture<Void> {
        guard let handle = self.fileHandle else {
            return task.eventLoop.makeSucceededFuture(())
        }
        
        let data = Data(buffer.readableBytesView)
        handle.write(data)
        self.downloadedBytes += Int64(data.count)
        
        let now = Date()
        if now.timeIntervalSince(lastUpdate) > 1.0 {
            let progress = totalBytes > 0 ? Int((Double(downloadedBytes) / Double(totalBytes)) * 100) : 0
            
            // We need to be careful updating DB from here as we are not in an async context
            // but returning a future.
            // For simplicity in this delegate, we might skip DB updates or fire-and-forget
            // But to do it properly we should use the event loop.
            
            let updateTask = download.status == .downloading ? 
                Download.query(on: db)
                    .filter(\.$id == download.id!)
                    .set(\.$progress, to: progress)
                    .set(\.$size, to: totalBytes)
                    .update() : db.eventLoop.makeSucceededFuture(())
            
            lastUpdate = now
            return updateTask
        }
        
        return task.eventLoop.makeSucceededFuture(())
    }
    
    func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Response {
        try? self.fileHandle?.close()
        return HTTPClient.Response(host: "localhost", status: .ok, version: .init(major: 1, minor: 1), headers: [:], body: nil)
    }
    
    func didError(task: HTTPClient.Task<Response>, _ error: Error) {
        try? self.fileHandle?.close()
        logger.error("Download error: \(error)")
    }
}
