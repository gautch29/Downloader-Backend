import Vapor

struct FileBrowserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let paths = routes.grouped("api", "paths")
        paths.get("browse", use: browse)
        paths.post("create-folder", use: createFolder)
    }

    struct BrowseRequest: Content {
        var path: String?
    }
    
    struct FileItem: Content {
        var name: String
        var path: String
        var isDirectory: Bool
    }

    func browse(req: Request) async throws -> [FileItem] {
        let path = try req.query.get(String.self, at: "path")
        
        // Security check: Ensure path is within allowed directories (e.g., /mnt, /Users)
        // For now, allowing all for local usage, but in production should be restricted.
        
        var items: [FileItem] = []
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for name in contents {
                guard !name.hasPrefix(".") else { continue } // Skip hidden files
                let fullPath = (path as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) {
                    items.append(FileItem(name: name, path: fullPath, isDirectory: isDir.boolValue))
                }
            }
        } catch {
            throw Abort(.badRequest, reason: "Failed to list directory: \(error.localizedDescription)")
        }
        
        return items.sorted { $0.isDirectory && !$1.isDirectory }
    }

    struct CreateFolderRequest: Content {
        var path: String
        var name: String
    }

    func createFolder(req: Request) async throws -> HTTPStatus {
        let createReq = try req.content.decode(CreateFolderRequest.self)
        let fullPath = (createReq.path as NSString).appendingPathComponent(createReq.name)
        
        do {
            try FileManager.default.createDirectory(atPath: fullPath, withIntermediateDirectories: true)
            return .ok
        } catch {
            throw Abort(.internalServerError, reason: "Failed to create folder: \(error.localizedDescription)")
        }
    }
}
