import Vapor
import Fluent

struct SettingsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let settings = routes.grouped("api", "settings")
        settings.get(use: get)
        settings.put(use: update)
    }

    struct SettingsResponse: Content {
        var settings: Setting
        var paths: [Path]
    }

    func get(req: Request) async throws -> SettingsResponse {
        let setting: Setting
        if let existing = try await Setting.query(on: req.db).first() {
            setting = existing
        } else {
            setting = Setting()
        }
        
        let paths = try await Path.query(on: req.db).all()
        
        return SettingsResponse(settings: setting, paths: paths)
    }

    struct PathInput: Content {
        var name: String
        var path: String
    }

    struct UpdateSettingsRequest: Content {
        var plexUrl: String?
        var plexToken: String?
        var paths: [PathInput]?
    }

    func update(req: Request) async throws -> SettingsResponse {
        let updateReq = try req.content.decode(UpdateSettingsRequest.self)
        
        // 1. Update Settings
        let setting: Setting
        if let existing = try await Setting.query(on: req.db).first() {
            setting = existing
        } else {
            setting = Setting()
        }
        
        if let url = updateReq.plexUrl { setting.plexUrl = url }
        if let token = updateReq.plexToken { setting.plexToken = token }
        
        try await setting.save(on: req.db)
        
        // 2. Update Paths if provided
        if let newPaths = updateReq.paths {
            // Delete existing paths
            try await Path.query(on: req.db).delete()
            
            // Create new paths
            for pathInput in newPaths {
                let path = Path(name: pathInput.name, path: pathInput.path)
                try await path.save(on: req.db)
            }
        }
        
        // 3. Return updated data
        let paths = try await Path.query(on: req.db).all()
        return SettingsResponse(settings: setting, paths: paths)
    }
}
