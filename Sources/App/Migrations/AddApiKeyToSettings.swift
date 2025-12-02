import Fluent

struct AddApiKeyToSettings: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("settings")
            .field("onefichier_api_key", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("settings")
            .deleteField("onefichier_api_key")
            .update()
    }
}
