import Fluent
import Vapor

final class Setting: Model, Content {
    static let schema = "settings"

    @ID(custom: "id")
    var id: Int?

    @OptionalField(key: "plex_url")
    var plexUrl: String?

    @OptionalField(key: "plex_token")
    var plexToken: String?

    @OptionalField(key: "onefichier_api_key")
    var onefichierApiKey: String?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(id: Int? = nil, plexUrl: String? = nil, plexToken: String? = nil, onefichierApiKey: String? = nil) {
        self.id = id
        self.plexUrl = plexUrl
        self.plexToken = plexToken
        self.onefichierApiKey = onefichierApiKey
    }
}
