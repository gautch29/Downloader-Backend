import Fluent
import Vapor

final class Session: Model, Content {
    static let schema = "sessions"

    @ID(custom: "id")
    var id: String?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "expires_at")
    var expiresAt: Date

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(id: String, userID: User.IDValue, expiresAt: Date) {
        self.id = id
        self.$user.id = userID
        self.expiresAt = expiresAt
    }
}
