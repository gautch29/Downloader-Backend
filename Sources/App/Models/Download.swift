import Fluent
import Vapor

final class Download: Model, Content {
    static let schema = "downloads"

    @ID(custom: "id")
    var id: Int?

    @Field(key: "url")
    var url: String

    @OptionalField(key: "filename")
    var filename: String?

    @OptionalField(key: "custom_filename")
    var customFilename: String?

    @OptionalField(key: "target_path")
    var targetPath: String?

    @Enum(key: "status")
    var status: DownloadStatus

    @Field(key: "progress")
    var progress: Int

    @OptionalField(key: "size")
    var size: Int64?

    @OptionalField(key: "speed")
    var speed: Int?

    @OptionalField(key: "eta")
    var eta: Int?

    @OptionalField(key: "error")
    var error: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(id: Int? = nil, url: String, customFilename: String? = nil, targetPath: String? = nil, status: DownloadStatus = .pending) {
        self.id = id
        self.url = url
        self.customFilename = customFilename
        self.targetPath = targetPath
        self.status = status
        self.progress = 0
    }
}

enum DownloadStatus: String, Codable {
    case pending, downloading, completed, error
}
