import Fluent

struct CreatePaths: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("paths")
            .field("id", .int, .identifier(auto: true))
            .field("name", .string, .required)
            .field("path", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("paths").delete()
    }
}
