import Fluent

struct CreateDownloads: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("downloads")
            .field("id", .int, .identifier(auto: true))
            .field("url", .string, .required)
            .field("filename", .string)
            .field("custom_filename", .string)
            .field("target_path", .string)
            .field("status", .string, .required, .sql(.default("pending")))
            .field("progress", .int, .required, .sql(.default(0)))
            .field("size", .int64)
            .field("speed", .int)
            .field("eta", .int)
            .field("error", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("downloads").delete()
    }
}
