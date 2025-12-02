import Vapor
import Fluent

struct SettingsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let settings = routes.grouped("api", "settings")
        settings.get(use: get)
        settings.put(use: update)
    }

    func get(req: Request) async throws -> Setting {
        if let setting = try await Setting.query(on: req.db).first() {
            return setting
        } else {
            // Return default empty setting
            return Setting()
        }
    }

    struct UpdateSettingsRequest: Content {
        var plexUrl: String?
        var plexToken: String?
    }

    func update(req: Request) async throws -> Setting {
        let updateReq = try req.content.decode(UpdateSettingsRequest.self)
        
        let setting: Setting
        if let existing = try await Setting.query(on: req.db).first() {
            setting = existing
        } else {
            setting = Setting()
        }
        
        if let url = updateReq.plexUrl { setting.plexUrl = url }
        if let token = updateReq.plexToken { setting.plexToken = token }
        
        try await setting.save(on: req.db)
        return setting
    }
}
