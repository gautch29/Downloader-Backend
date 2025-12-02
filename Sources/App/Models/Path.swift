import Fluent
import Vapor

final class Path: Model, Content {
    static let schema = "paths"

    @ID(custom: "id")
    var id: Int?

    @Field(key: "name")
    var name: String

    @Field(key: "path")
    var path: String

    init() { }

    init(id: Int? = nil, name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }
}
