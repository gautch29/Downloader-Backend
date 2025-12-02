import Vapor
import Fluent

struct PathsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let paths = routes.grouped("api", "paths")
        paths.get(use: index)
        paths.post(use: create)
        paths.delete(use: delete)
    }

    func index(req: Request) async throws -> [Path] {
        try await Path.query(on: req.db).all()
    }

    struct CreatePathRequest: Content {
        var name: String
        var path: String
    }

    func create(req: Request) async throws -> Path {
        let createReq = try req.content.decode(CreatePathRequest.self)
        let path = Path(name: createReq.name, path: createReq.path)
        try await path.save(on: req.db)
        return path
    }

    func delete(req: Request) async throws -> HTTPStatus {
        guard let name = req.query[String.self, at: "name"] else {
            throw Abort(.badRequest, reason: "Missing name parameter")
        }
        
        try await Path.query(on: req.db)
            .filter(\.$name == name)
            .delete()
            
        return .ok
    }
}
