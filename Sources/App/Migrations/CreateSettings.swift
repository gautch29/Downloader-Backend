import Fluent

struct CreateSettings: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("settings")
            .field("id", .int, .identifier(auto: true))
            .field("plex_url", .string)
            .field("plex_token", .string)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("settings").delete()
    }
}
