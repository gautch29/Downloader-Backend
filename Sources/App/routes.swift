import Vapor

func routes(_ app: Application) throws {
    try app.register(collection: AuthController())
    try app.register(collection: DownloadsController())
    try app.register(collection: SettingsController())
    try app.register(collection: PathsController())
    try app.register(collection: FileBrowserController())
    try app.register(collection: MoviesController())
}
