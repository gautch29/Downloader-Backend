import Vapor
import Fluent

struct DownloadsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let downloads = routes.grouped("api", "downloads")
        downloads.get(use: index)
        downloads.post(use: create)
        downloads.delete(":id", use: delete)
    }

    func index(req: Request) async throws -> [Download] {
        try await Download.query(on: req.db).sort(\.$createdAt, .descending).all()
    }

    struct CreateDownloadRequest: Content {
        var url: String
        var customFilename: String?
        var targetPath: String?
    }

    func create(req: Request) async throws -> Download {
        let createReq = try req.content.decode(CreateDownloadRequest.self)
        
        let download = Download(
            url: createReq.url,
            customFilename: createReq.customFilename,
            targetPath: createReq.targetPath
        )
        
        try await download.save(on: req.db)
        return download
    }

    func delete(req: Request) async throws -> HTTPStatus {
        guard let download = try await Download.find(req.parameters.get("id"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await download.delete(on: req.db)
        return .ok
    }
}
