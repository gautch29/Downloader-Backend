import Fluent

struct CreateSessions: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("sessions")
            .field("id", .string, .identifier(auto: false))
            .field("user_id", .int, .required, .references("users", "id", onDelete: .cascade))
            .field("expires_at", .datetime, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("sessions").delete()
    }
}
